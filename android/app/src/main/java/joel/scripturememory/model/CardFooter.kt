package joel.scripturememory.model

object CardFooter {

    private val sectionTitles: Map<String, Map<String, String>> = mapOf(
        "TMS 60" to mapOf(
            "A" to "Live the New Life",
            "B" to "Proclaim Christ",
            "C" to "Rely on God's Resources",
            "D" to "Be Christ's Disciple",
            "E" to "Grow in Christlikeness",
        ),
    )

    private val wholePackTitles: Map<String, String> = mapOf(
        "5 Assurances" to "Beginning with Christ",
    )

    fun label(verse: Verse, fallbackPack: String = ""): String {
        val pack = verse.packName.ifEmpty { fallbackPack }
        PackParts.heading(verse)?.let { return it }
        val title = seriesTitle(pack, verse.subpack) ?: return pack
        val position = VerseNumbering.position(verse) ?: return pack
        val number = if (verse.subpack.isEmpty()) "$position" else "${verse.subpack}-$position"
        return "$number · $title"
    }

    fun groupHeading(verse: Verse): String? {
        PackParts.heading(verse)?.let { return it }
        if (verse.subpack.isEmpty()) return null
        val title = sectionTitles[verse.packName]?.get(verse.subpack) ?: return null
        return "${verse.subpack}. $title"
    }

    private fun seriesTitle(pack: String, section: String): String? =
        if (section.isEmpty()) wholePackTitles[pack] else sectionTitles[pack]?.get(section)
}

object PackParts {

    private val starts: Map<String, List<Pair<String, String>>> = mapOf(
        "DEP 2: Quiet Time" to listOf(
            "c8a38fe982d5b7f6" to "Why do we have Quiet Time?",
            "e1b2445ad26a4e7a" to "What is Quiet Time?",
            "6938e6832d16b354" to "Examples of Quiet Time",
        ),
        "DEP 3: The Word" to listOf(
            "41e9f49d662c3fb0" to "Authority of the Word",
            "77619ffd87cc4ba2" to "Value of the Word",
            "89872cec45a5b4a9" to "Attitude of the Word",
            "6ebeaffe80b2478b" to "How to take in the Word (Word Hand Illustration)",
        ),
        "DEP 4: Prayer" to listOf(
            "9d12f07eadc1c641" to "Command of prayer",
            "c8861483a5122975" to "Promises and blessings of prayer",
            "ef7995099e124a44" to "Conditions for answered prayer",
            "8f7c17711adcc2db" to "Examples of prayer",
            "325f2fbdd4b36141" to "Prayer Hand Illustration",
        ),
        "DEP 5: Fellowship" to listOf(
            "851be69006bec95c" to "Foundation of Christian Fellowship",
            "9a03ddf552b9aca7" to "Importance of Fellowship",
            "0c9b1f24e70a1d22" to "Essentials of Fellowship",
            "05ffe60782e4a962" to "Attitude of Fellowship",
            "70766a8c061484a1" to "Problem solving in Fellowship",
        ),
        "DEP 6: Witnessing" to listOf(
            "42d32896a4d2dbc4" to "Who is responsible for witnessing?",
            "8450d0c69ccff067" to "Why should we witness?",
            "5a562c26b910f45c" to "How do we witness?",
            "6caa572ca7098f83" to "Examples of witness",
            "74ad102a507ac9de" to "Bridge Illustration",
        ),
        "DEP 7: The Lordship of Christ" to listOf(
            "e3826d02963fa08f" to "We must believe in the Lordship of Christ",
            "5fea29f2b0512d37" to "Blessings when surrendering to the Lordship",
            "0871aa32bb0314d1" to "What to surrender in the Lordship",
            "4910b66021ad4396" to "Paragons of surrendering to the Lordship",
        ),
        "TMS 180 · Getting to Know God" to listOf(
            "ad0fd6a5607c6206" to "Jesus Christ",
            "6c11e294ab00721e" to "Holy Spirit",
            "63af1504260b6d44" to "God",
        ),
        "TMS 180 · Growing in Love" to listOf(
            "11e78ee8c60ce5c3" to "Love in Speech",
            "53a7b4e11dacac07" to "Love in Response",
            "dc3a406c36c50e6e" to "Love in Action",
        ),
        "TMS 180 · Growing in Faith" to listOf(
            "ef02d3aee1d50539" to "Promises",
            "1abaf7aa796fed7a" to "Word",
            "c371f333631da31e" to "Faith",
        ),
        "TMS 180 · Walking in Victory" to listOf(
            "ef6c99115ef786a8" to "Victory",
            "6c813d6dbaa848c7" to "Purity",
            "d8e4fa462c36c12c" to "Prayer",
        ),
        "TMS 180 · Sharing Christ with Others" to listOf(
            "2d8f6a42022b4fac" to "Evangelism",
            "1af4487bab249a9c" to "Excuses",
            "485db829f2e09ccc" to "Believer's Position in Christ",
        ),
    )

    private val parts: Map<String, Int> by lazy {
        val map = HashMap<String, Int>()
        for (packs in listOf(packsNIV84, packsNIV11)) {
            for (pack in packs) {
                val list = starts[pack.name] ?: continue
                var part = 0
                for (verse in pack.verses) {
                    if (part < list.size && verse.cardUid == list[part].first) part += 1
                    if (part > 0) map[verse.srsKey] = part
                }
            }
        }
        map
    }

    fun part(verse: Verse): Int? = parts[verse.srsKey]

    fun heading(verse: Verse): String? {
        val part = part(verse) ?: return null
        val list = starts[verse.packName] ?: return null
        if (part > list.size) return null
        return "$part. ${list[part - 1].second}"
    }
}
