package joel.scripturememory.model

object SpellingVariants {

    private val stems: List<Pair<String, String>> = listOf(
        "saviour" to "savior",
        "honour" to "honor",
        "favour" to "favor",
        "labour" to "labor",
        "neighbour" to "neighbor",
        "colour" to "color",
        "splendour" to "splendor",
        "vigour" to "vigor",
        "valour" to "valor",
        "armour" to "armor",
        "harbour" to "harbor",
        "odour" to "odor",
        "rumour" to "rumor",
        "clamour" to "clamor",
        "endeavour" to "endeavor",
        "behaviour" to "behavior",
        "humour" to "humor",
        "marvellous" to "marvelous",
        "counsellor" to "counselor",
        "traveller" to "traveler",
        "worshipper" to "worshiper",
        "defence" to "defense",
        "offence" to "offense",
        "pretence" to "pretense",
        "realise" to "realize",
        "baptise" to "baptize",
        "recognise" to "recognize",
        "apologise" to "apologize",
        "centre" to "center",
        "fulfil" to "fulfill",
        "skilful" to "skillful",
        "wilful" to "willful",
        "judgement" to "judgment",
        "grey" to "gray",
        "plough" to "plow",
        "enrolment" to "enrollment",
        "practise" to "practice",
    )

    private val suffixes = listOf("", "s", "es", "ed", "d", "ing", "er", "ers", "able", "ably")

    private val map: Map<String, String> = buildMap {
        for ((british, american) in stems) {
            for (suffix in suffixes) {
                put(british + suffix, american + suffix)
            }
            if (british.length == american.length - 1) {
                val last = british.last()
                for (suffix in listOf("ed", "ing", "er", "ers")) {
                    put(british + last + suffix, american + suffix)
                }
            }
        }
    }

    fun canonical(word: String): String = map[word] ?: word
}
