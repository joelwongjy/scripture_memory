package joel.scripturememory.model

data class AnkiImportSummary(
    val packsCreated: Int = 0,
    val versesAdded: Int = 0,
    val progressCarried: Int = 0,
    val matchedBundled: Int = 0,
)

object AnkiImporter {

    data class DeckChoice(val include: Boolean, val name: String)

    fun bundledKeys(): Map<String, String> {
        val keys = LinkedHashMap<String, String>()
        for (pack in packsNIV84) {
            for (verse in pack.verses) {
                val uid = verse.cardUid ?: continue
                keys.putIfAbsent(AnkiVerseImport.referenceKey(verse.book, verse.reference), uid)
            }
        }
        return keys
    }

    fun plan(source: AnkiImport): AnkiImportPlan =
        AnkiVerseImport.plan(source, bundledKeys(), packsNIV84.map { it.name }.toSet(), UserPack.defaultName)

    fun apply(
        plan: AnkiImportPlan,
        decks: List<DeckChoice>,
        includeMatches: Boolean,
        now: Date = Date.now(),
    ): AnkiImportSummary {
        var summary = AnkiImportSummary()
        val states = mutableListOf<SRSCardState>()
        val learnt = mutableSetOf<String>()

        fun carry(candidate: AnkiVerseCandidate, key: String) {
            val schedule = candidate.schedule ?: return
            val state = AnkiVerseImport.state(schedule, key, now) ?: return
            states += state
            learnt += key
            summary = summary.copy(progressCarried = summary.progressCarried + 1)
        }

        plan.decks.forEachIndexed { i, deck ->
            if (i >= decks.size || !decks[i].include) return@forEachIndexed
            val verses = deck.verses.map { candidate ->
                val verse = UserVerse(
                    id = UserVerse.newID(),
                    title = candidate.title,
                    text = candidate.text,
                    book = candidate.reference.book.name,
                    reference = candidate.reference.reference,
                    version = candidate.version,
                )
                carry(candidate, verse.id)
                verse
            }
            if (verses.isEmpty()) return@forEachIndexed
            val color = UserPack.colors[UserPackStore.shared.userPacks.size % UserPack.colors.size]
            UserPackStore.shared.createPack(decks[i].name, color, verses)
            summary = summary.copy(
                packsCreated = summary.packsCreated + 1,
                versesAdded = summary.versesAdded + verses.size,
            )
        }

        if (includeMatches) {
            for (match in plan.matches) {
                carry(match.candidate, match.cardUid)
                summary = summary.copy(matchedBundled = summary.matchedBundled + 1)
            }
        }

        SRSStore.shared.importStates(states)
        LearningStore.shared.markLearnt(learnt)
        return summary
    }
}
