package joel.scripturememory.model

object VerseTranslation {

    const val niv = "NIV"
    const val niv84 = "NIV84"

    val choices: List<String> = listOf(niv, niv84, "ESV", "NKJV", "KJV", "NLT", "NASB", "CSB")

    fun displayName(code: String): String = when (code) {
        niv -> "NIV (2011)"
        niv84 -> "NIV (1984)"
        else -> code
    }

    private val youVersionIDs: Map<String, Pair<Int, String>> = mapOf(
        niv to (111 to "NIV"), niv84 to (111 to "NIV"), "ESV" to (59 to "ESV"), "NKJV" to (114 to "NKJV"),
        "KJV" to (1 to "KJV"), "NLT" to (116 to "NLT"), "NASB" to (2692 to "NASB2020"), "CSB" to (1713 to "CSB"),
    )

    fun bibleAppURL(reference: BibleReference, translation: String): String {
        val (id, code) = youVersionIDs[translation.uppercase()] ?: youVersionIDs.getValue(niv)
        var passage = "${reference.book.usfm}.${reference.chapter}"
        val first = reference.verses.swiftSplit(',').firstOrNull().orEmpty()
        val bounds = first.swiftSplit('-')
        val start = bounds.firstOrNull()
        if (!start.isNullOrEmpty()) {
            passage += ".$start"
            if (bounds.size == 2 && ':' !in bounds[1]) passage += "-${bounds[1]}"
        }
        return "https://www.bible.com/bible/$id/$passage.$code"
    }
}
