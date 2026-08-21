import Foundation

/// Assembles a daily review queue from current SRS state.
///
/// Order within a session: **learning → review → new**. New cards are gated by
/// a GLOBAL cap (`NewCardCap`) shared across all packs — so turning on 9 packs
/// doesn't multiply the workload, it stays at the cap. The cap is measured per
/// day or per week depending on what the user picked.
///
/// `dailyReviewCap` is per-pack (rarely binds in practice — only matters if a
/// single pack has hundreds of due reviews on the same day).
///
/// **Where new cards start** is decided by `NewCardPolicy`: the drip begins at
/// the learning cursor, not at the first verse of the first pack. Verses before
/// the cursor — the ones the user said they already knew — either join review
/// a few at a time or are left alone, per the policy.
@MainActor
enum SRSQueueBuilder {

    /// How unscheduled verses split between "new" and "already known".
    ///
    /// A verse with no SRS state is **new** unless the user has marked it learnt
    /// (everything before the learning cursor is). Learnt-but-unscheduled verses
    /// are **known**: with `reviewsKnown` they're served inside the review slice,
    /// within the per-pack review cap, and their first grade seeds a review-phase
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

    /// Per-pack snapshot used by the dashboard. `newCandidates` is the pool of
    /// unscheduled cards in the pack — separate from "what'll be served today",
    /// which is bounded by the global new-card cap.
    struct DailyCounts {
        let learning:       Int
        let review:         Int
        let known:          Int   // Learnt-but-unscheduled cards waiting to join review
        let newCandidates:  Int   // Unscheduled, un-learnt cards still available in this pack
        let newToday:       Int   // Already introduced from this pack today
        let totalScheduled: Int   // Cards in this pack that have an SRS state

        /// Review cards this pack contributes to a session: due ones first, then
        /// known backlog filling whatever the per-pack cap leaves.
        func reviewServed(cap: Int) -> Int {
            min(review, cap) + min(known, max(0, cap - review))
        }
    }

    // MARK: - Single-pack session (drill button)

    /// Builds the verse list for a single pack's session. New cards still respect
    /// the GLOBAL daily cap, so drilling one pack doesn't blow past today's quota.
    static func buildSession(
        packName: String,
        allVerses: [Verse],
        store: SRSStore,
        newCap: NewCardCap,
        dailyReviewCap: Int,
        policy: NewCardPolicy? = nil,
        now: Date = Date()
    ) -> [Verse] {
        let policy = policy ?? .current
        let slice = reviewSlice(allVerses: allVerses, packName: packName, store: store,
                                dailyReviewCap: dailyReviewCap, policy: policy, now: now)

        let remaining  = globalNewRemaining(store: store, newCap: newCap, now: now)
        let candidates = policy.fresh(in: allVerses, store: store)
        let newCards   = Array(candidates.prefix(remaining))

        return slice + newCards
    }

    /// One pack's learning + review cards for a session: everything in learning,
    /// then due reviews up to the cap, then known backlog into what's left of it.
    private static func reviewSlice(
        allVerses: [Verse], packName: String, store: SRSStore,
        dailyReviewCap: Int, policy: NewCardPolicy, now: Date
    ) -> [Verse] {
        let due      = store.dueCards(in: packName, allVerses: allVerses, now: now)
        let learning = due.filter { store.state(for: $0)?.phase == .learning }
        let review   = Array(due.filter { store.state(for: $0)?.phase == .review }.prefix(dailyReviewCap))
        let known    = Array(policy.known(in: allVerses, store: store).prefix(max(0, dailyReviewCap - review.count)))
        return learning + review + known
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

        // 1) Learning + review (+ known backlog) per pack, review capped per-pack.
        for pack in packs {
            session.append(contentsOf: reviewSlice(
                allVerses: pack.verses, packName: pack.name, store: store,
                dailyReviewCap: dailyReviewCap, policy: policy, now: now))
        }

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

    /// Per-pack snapshot. `newCandidates` is the pool — separately apply the
    /// global remaining-new cap when projecting "what's actually queueable today".
    static func counts(
        packName: String,
        allVerses: [Verse],
        store: SRSStore,
        policy: NewCardPolicy? = nil,
        now: Date = Date()
    ) -> DailyCounts {
        let policy = policy ?? .current
        let due = store.dueCards(in: packName, allVerses: allVerses, now: now)
        return DailyCounts(
            learning:       due.filter { store.state(for: $0)?.phase == .learning }.count,
            review:         due.filter { store.state(for: $0)?.phase == .review }.count,
            known:          policy.known(in: allVerses, store: store).count,
            newCandidates:  policy.fresh(in: allVerses, store: store).count,
            newToday:       store.newIntroducedToday(in: packName, now: now),
            totalScheduled: allVerses.filter { store.state(for: $0) != nil }.count
        )
    }

    /// Global new cards still introducible in the cap's current period (cap minus
    /// however many have already been introduced in it).
    static func globalNewRemaining(store: SRSStore, newCap: NewCardCap, now: Date = Date()) -> Int {
        max(0, newCap.amount - store.newIntroduced(in: newCap.unit, now: now))
    }

    /// What's due at `now` across the given (already-active) packs — the single
    /// number Home, the widget, and the daily reminder all key off, so they never
    /// disagree. `review` folds learning + review (both are due cards); `new` is
    /// the new-card drip bounded by the global cap. Passing a future `now`
    /// projects that day (the daily-new counter is empty for future days, so the
    /// full cap is available).
    struct DueSummary {
        let review: Int
        let new: Int
        var total: Int { review + new }
    }

    static func dueSummary(activePacks: [Pack], store: SRSStore,
                           newCap: NewCardCap, dailyReviewCap: Int,
                           policy: NewCardPolicy? = nil, now: Date = Date()) -> DueSummary {
        let policy = policy ?? .current
        var review = 0
        var candidates = 0
        for pack in activePacks {
            let c = counts(packName: pack.name, allVerses: pack.verses, store: store, policy: policy, now: now)
            // Due reviews are always counted in full (matches the session, where
            // the cap effectively never binds on them); the known backlog only
            // counts for the slots it'll actually get today.
            review     += c.learning + c.review + min(c.known, max(0, dailyReviewCap - c.review))
            candidates += c.newCandidates
        }
        let new = min(globalNewRemaining(store: store, newCap: newCap, now: now), candidates)
        return DueSummary(review: review, new: new)
    }

    /// Per-pack projected NEW cards for today. Drips the GLOBAL new-card cap
    /// across `orderedActivePacks` IN ORDER — mirroring `buildAllPacksSession` —
    /// so the per-pack numbers SUM to the global projection instead of each pack
    /// independently claiming the full remaining cap. Keyed by pack name; packs
    /// reached after the cap is exhausted map to 0.
    static func projectedNewByPack(
        orderedActivePacks: [Pack],
        store: SRSStore,
        newCap: NewCardCap,
        policy: NewCardPolicy? = nil,
        now: Date = Date()
    ) -> [String: Int] {
        let policy = policy ?? .current
        let budget     = globalNewRemaining(store: store, newCap: newCap, now: now)
        let candidates = orderedActivePacks.map {
            policy.fresh(in: $0.verses, store: store).count
        }
        let taken = SRSMath.dripBudget(budget, across: candidates)
        return Dictionary(uniqueKeysWithValues: zip(orderedActivePacks.map(\.name), taken))
    }
}
