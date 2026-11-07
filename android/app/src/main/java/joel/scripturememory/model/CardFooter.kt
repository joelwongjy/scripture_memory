package joel.scripturememory.model

object CardFooter {

    private val wholePackTitles: Map<String, String> = mapOf(
        "5 Assurances" to "Beginning with Christ",
    )

    fun label(verse: Verse, fallbackPack: String = ""): String {
        val pack = verse.packName.ifEmpty { fallbackPack }
        if (verse.part.isNotEmpty()) {
            if (verse.subpack.isEmpty()) return verse.part
            val position = VerseNumbering.position(verse) ?: return verse.part
            val dot = verse.part.indexOf(". ")
            if (dot < 0) return verse.part
            return "${verse.subpack}-$position · ${verse.part.substring(dot + 2)}"
        }
        val title = wholePackTitles[pack] ?: return pack
        if (verse.subpack.isNotEmpty()) return pack
        val position = VerseNumbering.position(verse) ?: return pack
        return "$position · $title"
    }

    fun groupHeading(verse: Verse): String? = verse.part.ifEmpty { null }
}
