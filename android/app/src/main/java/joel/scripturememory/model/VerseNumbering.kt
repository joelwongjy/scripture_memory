package joel.scripturememory.model

object VerseNumbering {

    private val positions: Map<String, Int> by lazy {
        val map = HashMap<String, Int>()
        for (packs in listOf(packsNIV84, packsNIV11)) {
            for (pack in packs) {
                val countsBySection = HashMap<String, Int>()
                for (verse in pack.verses) {
                    val position = (countsBySection[verse.subpack] ?: 0) + 1
                    countsBySection[verse.subpack] = position
                    map[verse.srsKey] = position
                }
            }
        }
        map
    }

    private val packCodes: Map<String, String> by lazy {
        val map = HashMap<String, String>()
        var seriesNumber = 0
        for (pack in packsNIV84) {
            val colon = pack.name.indexOf(':')
            if (pack.name.startsWith("TMS 180")) {
                seriesNumber += 1
                map[pack.name] = "TMS 180 S$seriesNumber"
            } else if (pack.name.startsWith("DEP ") && colon >= 0) {
                map[pack.name] = pack.name.substring(0, colon)
            } else if (pack.name == "5 Assurances") {
                map[pack.name] = "5A"
            } else {
                map[pack.name] = pack.name
            }
        }
        map
    }

    fun position(verse: Verse): Int? = positions[verse.srsKey]

    private val topics: Map<String, Int> by lazy {
        val map = HashMap<String, Int>()
        for (packs in listOf(packsNIV84, packsNIV11)) {
            for (pack in packs) {
                if (!pack.name.startsWith("DEP ")) continue
                var topic = 0
                var previous: String? = null
                for (verse in pack.verses) {
                    if (verse.title != previous) {
                        topic += 1
                        previous = verse.title
                    }
                    map[verse.srsKey] = topic
                }
            }
        }
        map
    }

    fun topic(verse: Verse): Int? = topics[verse.srsKey]

    fun printedNumber(verse: Verse): String? {
        if (!verse.packName.startsWith("DEP ")) return null
        val code = code(verse) ?: return null
        return code.drop("DEP ".length)
    }

    fun packCode(packName: String): String = packCodes[packName] ?: packName

    fun code(verse: Verse): String? {
        if (verse.packName.isEmpty()) return null
        val position = positions[verse.srsKey] ?: return null
        val pack = packCode(verse.packName)
        return if (verse.subpack.isEmpty()) "$pack-$position" else "$pack ${verse.subpack}-$position"
    }
}
