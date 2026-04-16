import Foundation

/// Assembles a daily review queue from current SRS state.
///
/// Order within a session: **learning → review → new**. New cards are gated by
/// a GLOBAL daily cap (`dailyNewCap`) shared across all packs — so turning on
/// 9 packs doesn't multiply the workload, it stays at the cap.
///
/// `dailyReviewCap` is per-pack (rarely binds in practice — only matters if a
/// single pack has hundreds of due reviews on the same day).
@MainActor
enum SRSQueueBuilder {

    /// Per-pack snapshot used by the dashboard. `newCandidates` is the pool of
    /// unscheduled cards in the pack — separate from "what'll be served today",
    /// which is bounded by the global new-card cap.
    struct DailyCounts {
        let learning:       Int
        let review:         Int
        let newCandidates:  Int   // Unscheduled cards still available in this pack
        let newToday:       Int   // Already introduced from this pack today
        let totalScheduled: Int   // Cards in this pack that have an SRS state
    }

    // MARK: - Single-pack session (drill button)

    /// Builds the verse list for a single pack's session. New cards still respect
    /// the GLOBAL daily cap, so drilling one pack doesn't blow past today's quota.
    static func buildSession(
        packName: String,
        allVerses: [Verse],
        store: SRSStore,
        dailyNewCap: Int,
        dailyReviewCap: Int,
        now: Date = Date()
    ) -> [Verse] {
        let due      = store.dueCards(in: packName, allVerses: allVerses, now: now)
        let learning = due.filter { store.state(for: $0)?.phase == .learning }
        let review   = Array(due.filter { store.state(for: $0)?.phase == .review }.prefix(dailyReviewCap))

        let remaining  = globalNewRemaining(store: store, dailyNewCap: dailyNewCap, now: now)
        let candidates = store.newCandidateCards(in: packName, allVerses: allVerses)
        let newCards   = Array(candidates.prefix(remaining))

        return Array(learning) + review + newCards
    }

    // MARK: - All-packs merged session

    /// Builds an "all active packs" merged session. New cards are dripped from
    /// packs in the supplied order until the global cap is exhausted.
    static func buildAllPacksSession(
        packs: [Pack],
        store: SRSStore,
        dailyNewCap: Int,
        dailyReviewCap: Int,
        now: Date = Date()
    ) -> [Verse] {
        var session: [Verse] = []

        // 1) Learning + review per pack (review capped per-pack).
        for pack in packs {
            let due      = store.dueCards(in: pack.name, allVerses: pack.verses, now: now)
            let learning = due.filter { store.state(for: $0)?.phase == .learning }
            let review   = due.filter { store.state(for: $0)?.phase == .review }.prefix(dailyReviewCap)
            session.append(contentsOf: learning)
            session.append(contentsOf: review)
        }

        // 2) New cards across packs, gated by the GLOBAL cap.
        var remaining = globalNewRemaining(store: store, dailyNewCap: dailyNewCap, now: now)
        for pack in packs {
            guard remaining > 0 else { break }
            let candidates = store.newCandidateCards(in: pack.name, allVerses: pack.verses)
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
        now: Date = Date()
    ) -> DailyCounts {
        let due = store.dueCards(in: packName, allVerses: allVerses, now: now)
        return DailyCounts(
            learning:       due.filter { store.state(for: $0)?.phase == .learning }.count,
            review:         due.filter { store.state(for: $0)?.phase == .review }.count,
            newCandidates:  store.newCandidateCards(in: packName, allVerses: allVerses).count,
            newToday:       store.newIntroducedToday(in: packName, now: now),
            totalScheduled: allVerses.filter { store.state(for: $0) != nil }.count
        )
    }

    /// Global new cards still introducible today (cap minus total introduced today).
    static func globalNewRemaining(store: SRSStore, dailyNewCap: Int, now: Date = Date()) -> Int {
        max(0, dailyNewCap - store.newIntroducedToday(now: now))
    }
}
