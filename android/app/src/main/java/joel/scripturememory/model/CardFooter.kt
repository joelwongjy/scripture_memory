package joel.scripturememory.model

object CardFooter {

    private val wholePackTitles: Map<String, String> = mapOf(
        "5 Assurances" to "Beginning with Christ",
    )

    fun label(verse: Verse, fallbackPack: String = ""): String {
        val pack = verse.packName.ifEmpty { fallbackPack }
        booklet(pack)?.let { return if (verse.part.isEmpty()) it else "$it · ${verse.part}" }
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

    private val romanNumerals = listOf("I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X")

    private fun booklet(pack: String): String? {
        if (!pack.startsWith("DEP ")) return null
        val halves = pack.removePrefix("DEP ").split(":", limit = 2)
        if (halves.size != 2) return null
        val numeral = halves[0].toIntOrNull()?.let { romanNumerals.getOrNull(it - 1) } ?: return null
        return "$numeral. ${halves[1].trim()}"
    }

    fun groupHeading(verse: Verse): String? = verse.part.ifEmpty { null }
}
