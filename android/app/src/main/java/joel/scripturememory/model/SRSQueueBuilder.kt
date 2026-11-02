package joel.scripturememory.model

import kotlin.math.max
import kotlin.math.min

object SRSQueueBuilder {

    const val learnAhead = 20.0 * 60

    data class NewCardPolicy(
        val learntKeys: Set<String>,
        val reviewsKnown: Boolean,
    ) {
        fun fresh(allVerses: List<Verse>, store: SRSStore): List<Verse> =
            allVerses.filter { store.state(it) == null && it.srsKey !in learntKeys }

        fun known(allVerses: List<Verse>, store: SRSStore): List<Verse> {
            if (!reviewsKnown) return emptyList()
            return allVerses.filter { store.state(it) == null && it.srsKey in learntKeys }
        }

        companion object {
            const val reviewsKnownKey = "srs.reviewsKnownVerses.v1"
            const val reviewsKnownDefault = true

            val current: NewCardPolicy
                get() = NewCardPolicy(
                    learntKeys = LearningStore.shared.learntKeys,
                    reviewsKnown = AppDefaults.standard.getBool(reviewsKnownKey)
                        ?: reviewsKnownDefault,
                )
        }
    }

    fun reviewCards(
        packs: List<Pack>,
        store: SRSStore,
        dailyReviewCap: Int,
        policy: NewCardPolicy,
        now: Date,
    ): List<Verse> {
        val learning = ArrayList<Verse>()
        val review = ArrayList<Verse>()
        val knownByPack = ArrayList<List<Verse>>()
        for (pack in packs) {
            val due = store.dueCards(pack.verses, now)
            learning += due.filter { store.state(it)?.phase == SRSPhase.learning }
            review += due.filter { store.state(it)?.phase == SRSPhase.review }
            knownByPack.add(policy.known(pack.verses, store).asReversed())
        }
        review.sortBy { store.state(it)?.due ?: now }
        val known = takingTurns(knownByPack.asReversed())

        val left = max(0, dailyReviewCap - store.reviewedToday(now))
        val keptForBacklog = if (known.isEmpty()) 0 else min(1, left)
        val cappedReview = review.take(left - keptForBacklog)
        val cappedKnown = known.take(left - cappedReview.size)
        return learning + cappedReview + cappedKnown
    }

    private fun takingTurns(lists: List<List<Verse>>): List<Verse> {
        val out = ArrayList<Verse>()
        var round = 0
        while (true) {
            val picks = lists.mapNotNull { it.getOrNull(round) }
            if (picks.isEmpty()) return out
            out += picks
            round += 1
        }
    }

    fun buildAllPacksSession(
        packs: List<Pack>,
        store: SRSStore,
        newCap: NewCardCap,
        dailyReviewCap: Int,
        policy: NewCardPolicy? = null,
        now: Date = Date.now(),
    ): List<Verse> {
        val resolved = policy ?: NewCardPolicy.current
        val session = ArrayList<Verse>()

        session += reviewCards(packs, store, dailyReviewCap, resolved, now)

        var remaining = globalNewRemaining(store, newCap, now)
        for (pack in packs) {
            if (remaining <= 0) break
            val take = resolved.fresh(pack.verses, store).take(remaining)
            session += take
            remaining -= take.size
        }

        return session
    }

    fun globalNewRemaining(store: SRSStore, newCap: NewCardCap, now: Date = Date.now()): Int =
        max(0, newCap.amount - store.newIntroduced(newCap.unit, now))

    data class DueSummary(val review: Int, val new: Int) {
        val total: Int get() = review + new
    }

    fun dueSummary(
        activePacks: List<Pack>,
        store: SRSStore,
        newCap: NewCardCap,
        dailyReviewCap: Int,
        policy: NewCardPolicy? = null,
        now: Date = Date.now(),
    ): DueSummary {
        val resolved = policy ?: NewCardPolicy.current
        val review = reviewCards(activePacks, store, dailyReviewCap, resolved, now).size
        val candidates = activePacks.sumOf { resolved.fresh(it.verses, store).size }
        val new = min(globalNewRemaining(store, newCap, now), candidates)
        return DueSummary(review, new)
    }
}
