package joel.scripturememory.model

object Catalogue {

    private var cached: Pair<Long, List<Verse>>? = null

    fun verses(packs: List<Pack>): List<Verse> {
        val token = fingerprint(packs)
        cached?.let { if (it.first == token) return it.second }
        val flattened = packs.flatMap { it.verses }
        cached = token to flattened
        return flattened
    }

    fun fingerprint(packs: List<Pack>): Long {
        var hash = 1_125_899_906_842_597L
        fun combine(value: Any?) {
            hash = 31 * hash + value.hashCode()
        }
        for (pack in packs) {
            combine(pack.name)
            combine(pack.verses.size)
            combine(pack.verses.firstOrNull()?.id)
            combine(pack.verses.firstOrNull()?.verse)
        }
        return hash
    }
}
