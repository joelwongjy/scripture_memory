package joel.scripturememory.model

data class VerseSearchResult(
    val verse: Verse,
    val pack: Pack,
    val verseIndex: Int,
    val matchedOnReference: Boolean = false,
) {
    val id: String get() = "${pack.name}-${verse.id}"
}

data class VerseSearchGroup(
    val pack: Pack,
    val results: List<VerseSearchResult>,
) {
    val id: String get() = pack.id

    companion object {
        fun grouping(results: List<VerseSearchResult>): List<VerseSearchGroup> {
            val groups = ArrayList<VerseSearchGroup>()
            for (result in results) {
                val i = groups.indexOfFirst { it.pack.id == result.pack.id }
                if (i >= 0) {
                    groups[i] = groups[i].copy(results = groups[i].results + result)
                } else {
                    groups.add(VerseSearchGroup(result.pack, listOf(result)))
                }
            }
            return groups
        }
    }
}

object VerseSearch {

    const val resultLimit = 25

    private class Entry(
        val reference: String,
        val title: String,
        val body: String,
        val packIndex: Int,
        val verseIndex: Int,
    )

    private var cached: Pair<Long, List<Entry>>? = null

    fun results(query: String, packs: List<Pack>): List<VerseSearchResult> {
        val q = query.trimmingWhitespacesAndNewlines().lowercasedByScalar()
        if (q.isEmpty()) return emptyList()

        val entries = index(packs)
        val primary = ArrayList<VerseSearchResult>()
        val secondary = ArrayList<VerseSearchResult>()

        for (entry in entries) {
            val onReference = entry.reference.contains(q) || entry.title.contains(q)
            if (onReference) {
                primary.add(result(entry, packs).copy(matchedOnReference = true))
                if (primary.size == resultLimit) return primary
            } else if (secondary.size < resultLimit && entry.body.contains(q)) {
                secondary.add(result(entry, packs))
            }
        }
        return (primary + secondary).take(resultLimit)
    }

    fun prewarm(packs: List<Pack>) {
        index(packs)
    }

    fun logOpened(
        result: VerseSearchResult,
        results: List<VerseSearchResult>,
        log: (AnalyticsEvent) -> Unit,
    ) {
        val shown = VerseSearchGroup.grouping(results).flatMap { it.results }
        val found = shown.indexOfFirst { it.id == result.id }
        val rank = (if (found >= 0) found else 0) + 1
        log(AnalyticsEvent.SearchResultOpened(rank, result.matchedOnReference))
        log(AnalyticsEvent.PackOpened(result.pack.name, PackSource.search))
    }

    private fun result(entry: Entry, packs: List<Pack>): VerseSearchResult {
        val pack = packs[entry.packIndex]
        return VerseSearchResult(pack.verses[entry.verseIndex], pack, entry.verseIndex)
    }

    private fun index(packs: List<Pack>): List<Entry> {
        val token = Catalogue.fingerprint(packs)
        cached?.let { if (it.first == token) return it.second }

        val entries = ArrayList<Entry>(packs.sumOf { it.verses.size })
        packs.forEachIndexed { packIndex, pack ->
            pack.verses.forEachIndexed { verseIndex, verse ->
                entries.add(
                    Entry(
                        reference = "${verse.book} ${verse.reference}".lowercasedByScalar(),
                        title = verse.title.lowercasedByScalar(),
                        body = verse.verse.lowercasedByScalar(),
                        packIndex = packIndex,
                        verseIndex = verseIndex,
                    ),
                )
            }
        }
        cached = token to entries
        return entries
    }
}
