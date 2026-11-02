package joel.scripturememory.model

object CardFooter {

    private val sectionTitles: Map<String, Map<String, String>> = mapOf(
        "TMS 60" to mapOf(
            "A" to "Live the New Life",
            "B" to "Proclaim Christ",
            "C" to "Rely on God's Resources",
            "D" to "Be Christ's Disciple",
            "E" to "Grow in Christ Likeness",
        ),
    )

    private val wholePackTitles: Map<String, String> = mapOf(
        "5 Assurances" to "Beginning with Christ",
    )

    fun label(verse: Verse, fallbackPack: String = ""): String {
        val pack = verse.packName.ifEmpty { fallbackPack }
        val title = seriesTitle(pack, verse.subpack) ?: return pack
        val position = VerseNumbering.position(verse) ?: return pack
        val number = if (verse.subpack.isEmpty()) "$position" else "${verse.subpack}-$position"
        return "$number · $title"
    }

    private fun seriesTitle(pack: String, section: String): String? =
        if (section.isEmpty()) wholePackTitles[pack] else sectionTitles[pack]?.get(section)
}
