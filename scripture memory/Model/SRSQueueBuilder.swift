import Foundation

/// Assembles a daily review queue from current SRS state.
///
/// Order within a session: **learning → review → new**. New cards are gated by
/// a GLOBAL cap (`NewCardCap`) shared across all packs — so turning on 9 packs
/// doesn't multiply the workload, it stays at the cap. The cap is measured per
/// day or per week depending on what the user picked.
///
/// `dailyReviewCap` is GLOBAL too, and counts reviews already answered today.
/// Due cards come most overdue first, then (per `NewCardPolicy`) the known
/// backlog. Learning-phase cards are never capped.
///
/// **Where new cards start** is decided by `NewCardPolicy`: the drip begins at
/// the learning cursor, not at the first verse of the first pack. Verses before
/// the cursor — the ones the user said they already knew — either join review
/// a few at a time or are left alone, per the policy.
@MainActor
enum SRSQueueBuilder {

    /// How far ahead a learning card counts as due now: Anki's default.
    static let learnAhead: TimeInterval = 20 * 60

    /// How unscheduled verses split between "new" and "already known".
    ///
    /// A verse with no SRS state is **new** unless the user has marked it learnt
    /// (everything before the learning cursor is). Learnt-but-unscheduled verses
    /// are **known**: with `reviewsKnown` they're served inside the review slice,
    /// within the daily review cap, and their first grade seeds a review-phase
    /// card (`SRSCardState.knownCard`) — they never take a new-card slot.
    @MainActor
    struct NewCardPolicy {
        var learntKeys:   Set<String>
        var reviewsKnown: Bool

        /// The live policy: the learning store's learnt set + the Settings toggle.
        static var current: NewCardPolicy {
            NewCardPolicy(learntKeys: LearningStore.shared.learntKeys,
                          reviewsKnown: UserDefaults.standard.object(forKey: reviewsKnownKey) as? Bool
                                        ?? reviewsKnownDefault)
        }

        /// `@AppStorage` key for the Settings toggle.
        static let reviewsKnownKey     = "srs.reviewsKnownVerses.v1"
        static let reviewsKnownDefault = true

        /// Unscheduled verses in `allVerses` the user hasn't learnt — the new-card pool.
        func fresh(in allVerses: [Verse], store: SRSStore) -> [Verse] {
            allVerses.filter { store.state(for: $0) == nil && !learntKeys.contains($0.srsKey) }
        }

        /// Unscheduled verses the user has learnt — the known backlog, or nothing
        /// when they've chosen not to review earlier verses.
        func known(in allVerses: [Verse], store: SRSStore) -> [Verse] {
            guard reviewsKnown else { return [] }
            return allVerses.filter { store.state(for: $0) == nil && learntKeys.contains($0.srsKey) }
        }
    }

    /// The review cards a session serves: every learning card, then due reviews
    /// until what's left of today's limit is spent, then known backlog, one slot
    /// of it kept while any is left. The backlog takes turns across packs from
    /// the latest back, most recently learnt first within each. Home counts
    /// from this same function.
    static func reviewCards(
        packs: [Pack], store: SRSStore, dailyReviewCap: Int,
        policy: NewCardPolicy, now: Date
    ) -> [Verse] {
        var learning: [Verse] = []
        var review:   [Verse] = []
        var knownByPack: [[Verse]] = []
        for pack in packs {
            let due = store.dueCards(in: pack.verses, now: now)
            learning += due.filter { store.state(for: $0)?.phase == .learning }
            review   += due.filter { store.state(for: $0)?.phase == .review }
            knownByPack.append(policy.known(in: pack.verses, store: store).reversed())
        }
        review.sort { (store.state(for: $0)?.due ?? now) < (store.state(for: $1)?.due ?? now) }
        let known = takingTurns(knownByPack.reversed())

        let left = max(0, dailyReviewCap - store.reviewedToday(now: now))
        let keptForBacklog = known.isEmpty ? 0 : min(1, left)
        let cappedReview = review.prefix(left - keptForBacklog)
        let cappedKnown  = known.prefix(left - cappedReview.count)
        return learning + cappedReview + cappedKnown
    }

    /// The first of each list, then the second of each, and so on.
    private static func takingTurns(_ lists: [[Verse]]) -> [Verse] {
        var out: [Verse] = []
        var round = 0
        while true {
            let picks = lists.compactMap { round < $0.count ? $0[round] : nil }
            if picks.isEmpty { return out }
            out += picks
            round += 1
        }
    }

    // MARK: - All-packs merged session

    /// Builds an "all active packs" merged session. New cards are dripped from
    /// packs in the supplied order until the global cap is exhausted.
    static func buildAllPacksSession(
        packs: [Pack],
        store: SRSStore,
        newCap: NewCardCap,
        dailyReviewCap: Int,
        policy: NewCardPolicy? = nil,
        now: Date = Date()
    ) -> [Verse] {
        let policy = policy ?? .current
        var session: [Verse] = []

        // 1) Learning + review (+ known backlog), review capped globally.
        session.append(contentsOf: reviewCards(
            packs: packs, store: store, dailyReviewCap: dailyReviewCap, policy: policy, now: now))

        // 2) New cards across packs, gated by the GLOBAL cap.
        var remaining = globalNewRemaining(store: store, newCap: newCap, now: now)
        for pack in packs {
            guard remaining > 0 else { break }
            let candidates = policy.fresh(in: pack.verses, store: store)
            let take = Array(candidates.prefix(remaining))
            session.append(contentsOf: take)
            remaining -= take.count
        }

        return session
    }

    // MARK: - Dashboard Counts

    /// Global new cards still introducible in the cap's current period (cap minus
    /// however many have already been introduced in it).
    static func globalNewRemaining(store: SRSStore, newCap: NewCardCap, now: Date = Date()) -> Int {
        max(0, newCap.amount - store.newIntroduced(in: newCap.unit, now: now))
    }

    /// Cards due in one session: `review` (learning + review) and `new`.
    struct DueSummary {
        let review: Int
        let new: Int
        var total: Int { review + new }
    }

    /// What's due at `now` across the given (already-active) packs — the single
    /// number Home, the widget, and the daily reminder all key off, so they never
    /// disagree. `review` folds learning + review (both are due cards); `new` is
    /// the new-card drip bounded by the global cap. Passing a future `now`
    /// projects that day (the daily-new counter is empty for future days, so the
    /// full cap is available).
    static func dueSummary(activePacks: [Pack], store: SRSStore,
                           newCap: NewCardCap, dailyReviewCap: Int,
                           policy: NewCardPolicy? = nil, now: Date = Date()) -> DueSummary {
        let policy = policy ?? .current
        let review = reviewCards(packs: activePacks, store: store, dailyReviewCap: dailyReviewCap,
                                 policy: policy, now: now).count
        let candidates = activePacks.reduce(0) { $0 + policy.fresh(in: $1.verses, store: store).count }
        let new = min(globalNewRemaining(store: store, newCap: newCap, now: now), candidates)
        return DueSummary(review: review, new: new)
    }
}
