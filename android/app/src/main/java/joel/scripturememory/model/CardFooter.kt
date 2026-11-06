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
        "DEP 2: Quiet Time" to mapOf(
            "1" to "Why do we have Quiet Time?",
            "2" to "What is Quiet Time?",
            "3" to "Examples of Quiet Time",
        ),
        "DEP 3: The Word" to mapOf(
            "1" to "Authority of the Word",
            "2" to "Value of the Word",
            "3" to "Attitude of the Word",
            "4" to "How to take in the Word (Word Hand Illustration)",
        ),
        "DEP 4: Prayer" to mapOf(
            "1" to "Command of prayer",
            "2" to "Promises and blessings of prayer",
            "3" to "Conditions for answered prayer",
            "4" to "Examples of prayer",
            "5" to "Prayer Hand Illustration",
        ),
        "DEP 5: Fellowship" to mapOf(
            "1" to "Foundation of Christian Fellowship",
            "2" to "Importance of Fellowship",
            "3" to "Essentials of Fellowship",
            "4" to "Attitude of Fellowship",
            "5" to "Problem solving in Fellowship",
        ),
        "DEP 6: Witnessing" to mapOf(
            "1" to "Who is responsible for witnessing?",
            "2" to "Why should we witness?",
            "3" to "How do we witness?",
            "4" to "Examples of witness",
            "5" to "Bridge Illustration",
        ),
        "DEP 7: The Lordship of Christ" to mapOf(
            "1" to "We must believe in the Lordship of Christ",
            "2" to "Blessings when surrendering to the Lordship",
            "3" to "What to surrender in the Lordship",
            "4" to "Paragons of surrendering to the Lordship",
        ),
        "TMS 180 · Getting to Know God" to mapOf("1" to "Jesus Christ", "2" to "Holy Spirit", "3" to "God"),
        "TMS 180 · Growing in Love" to mapOf("1" to "Love in Speech", "2" to "Love in Response", "3" to "Love in Action"),
        "TMS 180 · Growing in Faith" to mapOf("1" to "Promises", "2" to "Word", "3" to "Faith"),
        "TMS 180 · Walking in Victory" to mapOf("1" to "Victory", "2" to "Purity", "3" to "Prayer"),
        "TMS 180 · Sharing Christ with Others" to mapOf(
            "1" to "Evangelism",
            "2" to "Excuses",
            "3" to "Believer's Position in Christ",
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

    fun sectionHeading(pack: String, section: String): String? {
        if (section.isEmpty()) return null
        val title = sectionTitles[pack]?.get(section) ?: return null
        return "$section. $title"
    }

    private fun seriesTitle(pack: String, section: String): String? =
        if (section.isEmpty()) wholePackTitles[pack] else sectionTitles[pack]?.get(section)
}
