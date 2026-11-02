package joel.scripturememory.model

import java.util.UUID

enum class SessionKind { custom, srs, pack }

data class TestSession(
    val verses: List<Verse>,
    val kind: SessionKind = SessionKind.custom,
    val round: Int = 1,
    val id: UUID = UUID.randomUUID(),
) {
    companion object {
        fun practice(verses: List<Verse>, start: Int): TestSession? {
            if (start !in verses.indices) return null
            return TestSession(verses.drop(start), SessionKind.pack)
        }

        fun dailyReview(
            activePacks: List<Pack>,
            newCap: NewCardCap,
            dailyReviewCap: Int,
        ): TestSession? {
            val verses = SRSQueueBuilder.buildAllPacksSession(
                packs = activePacks,
                store = SRSStore.shared,
                newCap = newCap,
                dailyReviewCap = dailyReviewCap,
            )
            return if (verses.isEmpty()) null else TestSession(verses, SessionKind.srs)
        }
    }
}
