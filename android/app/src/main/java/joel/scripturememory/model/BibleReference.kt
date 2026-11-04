package joel.scripturememory.model

data class BibleBook(
    val name: String,
    val usfm: String,
    val chapters: Int,
    val aliases: List<String>,
)

object BibleBooks {

    val all: List<BibleBook> = listOf(
        BibleBook("Genesis", "GEN", 50, listOf("Gen", "Ge", "Gn")),
        BibleBook("Exodus", "EXO", 40, listOf("Exod", "Exo", "Ex")),
        BibleBook("Leviticus", "LEV", 27, listOf("Lev", "Lv")),
        BibleBook("Numbers", "NUM", 36, listOf("Num", "Nm", "Nb")),
        BibleBook("Deuteronomy", "DEU", 34, listOf("Deut", "Deu", "Dt")),
        BibleBook("Joshua", "JOS", 24, listOf("Josh", "Jos", "Jsh")),
        BibleBook("Judges", "JDG", 21, listOf("Judg", "Jdg", "Jg")),
        BibleBook("Ruth", "RUT", 4, listOf("Rth", "Ru")),
        BibleBook("1 Samuel", "1SA", 31, listOf("1 Sam", "1 Sa", "1 Sm")),
        BibleBook("2 Samuel", "2SA", 24, listOf("2 Sam", "2 Sa", "2 Sm")),
        BibleBook("1 Kings", "1KI", 22, listOf("1 Kgs", "1 Ki", "1 Kin")),
        BibleBook("2 Kings", "2KI", 25, listOf("2 Kgs", "2 Ki", "2 Kin")),
        BibleBook("1 Chronicles", "1CH", 29, listOf("1 Chr", "1 Chron", "1 Ch")),
        BibleBook("2 Chronicles", "2CH", 36, listOf("2 Chr", "2 Chron", "2 Ch")),
        BibleBook("Ezra", "EZR", 10, listOf("Ezr")),
        BibleBook("Nehemiah", "NEH", 13, listOf("Neh", "Ne")),
        BibleBook("Esther", "EST", 10, listOf("Est", "Esth")),
        BibleBook("Job", "JOB", 42, listOf("Jb")),
        BibleBook("Psalm", "PSA", 150, listOf("Psalms", "Pslm", "Psa", "Ps", "Pss")),
        BibleBook("Proverbs", "PRO", 31, listOf("Prov", "Prv", "Pro", "Pr")),
        BibleBook("Ecclesiastes", "ECC", 12, listOf("Eccles", "Eccl", "Ecc", "Qoh")),
        BibleBook("Song of Songs", "SNG", 8, listOf("Song of Solomon", "Song", "SOS", "Canticles")),
        BibleBook("Isaiah", "ISA", 66, listOf("Isa", "Is")),
        BibleBook("Jeremiah", "JER", 52, listOf("Jer", "Je")),
        BibleBook("Lamentations", "LAM", 5, listOf("Lam", "La")),
        BibleBook("Ezekiel", "EZK", 48, listOf("Ezek", "Eze", "Ezk")),
        BibleBook("Daniel", "DAN", 12, listOf("Dan", "Dn")),
        BibleBook("Hosea", "HOS", 14, listOf("Hos", "Ho")),
        BibleBook("Joel", "JOL", 3, listOf("Joe", "Jl")),
        BibleBook("Amos", "AMO", 9, listOf("Am")),
        BibleBook("Obadiah", "OBA", 1, listOf("Obad", "Oba", "Ob")),
        BibleBook("Jonah", "JON", 4, listOf("Jon", "Jnh")),
        BibleBook("Micah", "MIC", 7, listOf("Mic", "Mc")),
        BibleBook("Nahum", "NAM", 3, listOf("Nah", "Na")),
        BibleBook("Habakkuk", "HAB", 3, listOf("Hab", "Hb")),
        BibleBook("Zephaniah", "ZEP", 3, listOf("Zeph", "Zep", "Zp")),
        BibleBook("Haggai", "HAG", 2, listOf("Hag", "Hg")),
        BibleBook("Zechariah", "ZEC", 14, listOf("Zech", "Zec", "Zc")),
        BibleBook("Malachi", "MAL", 4, listOf("Mal", "Ml")),
        BibleBook("Matthew", "MAT", 28, listOf("Matt", "Mat", "Mt")),
        BibleBook("Mark", "MRK", 16, listOf("Mrk", "Mar", "Mk")),
        BibleBook("Luke", "LUK", 24, listOf("Luk", "Lk")),
        BibleBook("John", "JHN", 21, listOf("Jhn", "Jn")),
        BibleBook("Acts", "ACT", 28, listOf("Act", "Ac")),
        BibleBook("Romans", "ROM", 16, listOf("Rom", "Ro", "Rm")),
        BibleBook("1 Corinthians", "1CO", 16, listOf("1 Cor", "1 Co")),
        BibleBook("2 Corinthians", "2CO", 13, listOf("2 Cor", "2 Co")),
        BibleBook("Galatians", "GAL", 6, listOf("Gal", "Ga")),
        BibleBook("Ephesians", "EPH", 6, listOf("Eph", "Ephes")),
        BibleBook("Philippians", "PHP", 4, listOf("Phil", "Php", "Pp")),
        BibleBook("Colossians", "COL", 4, listOf("Col")),
        BibleBook("1 Thessalonians", "1TH", 5, listOf("1 Thess", "1 Thes", "1 Th")),
        BibleBook("2 Thessalonians", "2TH", 3, listOf("2 Thess", "2 Thes", "2 Th")),
        BibleBook("1 Timothy", "1TI", 6, listOf("1 Tim", "1 Ti")),
        BibleBook("2 Timothy", "2TI", 4, listOf("2 Tim", "2 Ti")),
        BibleBook("Titus", "TIT", 3, listOf("Tit")),
        BibleBook("Philemon", "PHM", 1, listOf("Philem", "Phlm", "Phm")),
        BibleBook("Hebrews", "HEB", 13, listOf("Heb")),
        BibleBook("James", "JAS", 5, listOf("Jas", "Jm")),
        BibleBook("1 Peter", "1PE", 5, listOf("1 Pet", "1 Pe", "1 Pt")),
        BibleBook("2 Peter", "2PE", 3, listOf("2 Pet", "2 Pe", "2 Pt")),
        BibleBook("1 John", "1JN", 5, listOf("1 Jhn", "1 Jn")),
        BibleBook("2 John", "2JN", 1, listOf("2 Jhn", "2 Jn")),
        BibleBook("3 John", "3JN", 1, listOf("3 Jhn", "3 Jn")),
        BibleBook("Jude", "JUD", 1, listOf("Jud", "Jd")),
        BibleBook("Revelation", "REV", 22, listOf("Rev", "Re", "Revelations", "Apocalypse")),
    )

    internal val romanNumerals = mapOf('1' to "I", '2' to "II", '3' to "III")
    internal val ordinalWords = mapOf('1' to "First", '2' to "Second", '3' to "Third")

    fun key(text: String): String = buildString {
        text.lowercase().codePoints().forEach { if (Character.isLetterOrDigit(it)) appendCodePoint(it) }
    }

    private val byKey: Map<String, BibleBook> by lazy {
        val map = HashMap<String, BibleBook>()
        for (book in all) {
            for (surface in listOf(book.name) + book.aliases) {
                map.putIfAbsent(key(surface), book)
                val digit = surface.firstOrNull() ?: continue
                val roman = romanNumerals[digit] ?: continue
                val rest = surface.drop(1).trimmingWhitespaces()
                map.putIfAbsent(key(roman + rest), book)
                ordinalWords[digit]?.let { map.putIfAbsent(key(it + rest), book) }
            }
        }
        map
    }

    fun book(named: String): BibleBook? {
        val k = key(named)
        if (k.isEmpty()) return null
        return byKey[k]
    }

    fun bookForUsfm(usfm: String): BibleBook? = all.firstOrNull { it.usfm == usfm.uppercase() }

    fun matching(prefix: String, limit: Int = 4): List<BibleBook> {
        val k = key(prefix)
        if (k.isEmpty()) return emptyList()
        val result = mutableListOf<BibleBook>()
        for (book in all) {
            if (book in result) continue
            val surfaces = listOf(book.name) + book.aliases
            if (surfaces.any { key(it).startsWith(k) }) result += book
            if (result.size == limit) break
        }
        return result
    }
}

data class BibleReference(
    val book: BibleBook,
    val chapter: Int,
    val verses: String,
) {
    data class Found(val reference: BibleReference, val start: Int, val end: Int)

    val reference: String get() = if (verses.isEmpty()) "$chapter" else "$chapter:$verses"

    val display: String get() = "${book.name} $reference"

    val usfm: String
        get() {
            val prefix = "${book.usfm}.$chapter"
            if (verses.isEmpty()) return prefix
            return verses.swiftSplit(',').joinToString("+") { part ->
                val bounds = part.swiftSplit('-')
                if (bounds.size != 2) return@joinToString "$prefix.$part"
                if (':' in bounds[1]) {
                    val end = bounds[1].swiftSplit(':')
                    return@joinToString "$prefix.${bounds[0]}-${book.usfm}.${end[0]}.${end[1]}"
                }
                "$prefix.${bounds[0]}-$prefix.${bounds[1]}"
            }
        }

    companion object {

        fun parse(text: String): BibleReference? {
            val trimmed = normalized(text).trimmingWhitespacesAndNewlines()
            val match = firstMatch(trimmed, anchored = true) ?: return null
            return if (match.end == trimmed.length) match.reference else null
        }

        fun find(text: String): Found? = firstMatch(normalized(text), anchored = false)

        private fun normalized(text: String): String =
            text.replace('–', '-').replace('—', '-').replace(' ', ' ')

        private val pattern: Regex by lazy {
            val surfaces = BibleBooks.all
                .flatMap { listOf(it.name) + it.aliases }
                .flatMap { surface ->
                    val digit = surface.first()
                    if (!digit.isDigit()) return@flatMap listOf(surface)
                    val rest = surface.drop(1).trimmingWhitespaces()
                    val roman = BibleBooks.romanNumerals[digit].orEmpty()
                    val word = BibleBooks.ordinalWords[digit].orEmpty()
                    listOf(surface, "$roman $rest", "$word $rest")
                }
                .sortedByDescending { it.length }
                .joinToString("|") { escaped(it).replace(" ", "\\s*") }
            val verse = "\\d{1,3}[a-c]?"
            val range = "$verse(?:\\s*-\\s*(?:\\d{1,3}\\s*:\\s*)?$verse)?"
            val list = "$range(?:\\s*,\\s*$range)*"
            val full = "\\b($surfaces)\\.?\\s*(\\d{1,3})(?:(?:\\s*[:.]\\s*|\\s+)($list))?(?![\\d:])"
            Regex(full, RegexOption.IGNORE_CASE)
        }

        private fun escaped(text: String): String = buildString {
            for (c in text) {
                if (c in "\\^$.|?*+()[]{}") append('\\')
                append(c)
            }
        }

        private val partialVerse = Regex("[a-cA-C]")

        private fun firstMatch(text: String, anchored: Boolean): Found? {
            val matches = if (anchored) listOfNotNull(pattern.matchAt(text, 0)) else pattern.findAll(text).toList()
            for (match in matches) {
                val book = BibleBooks.book(match.groupValues[1]) ?: continue
                val chapter = match.groupValues[2].toIntOrNull() ?: continue
                if (chapter < 1) continue
                var verses = ""
                match.groups[3]?.let { group ->
                    verses = group.value.filterNot { it.isWhitespace() }.replace(partialVerse, "")
                }
                val start = match.range.first
                val end = match.range.last + 1
                if (book.chapters == 1 && verses.isEmpty() && chapter > 1) {
                    return Found(BibleReference(book, 1, "$chapter"), start, end)
                }
                if (chapter > book.chapters) continue
                return Found(BibleReference(book, chapter, verses), start, end)
            }
            return null
        }
    }
}

internal fun String.swiftSplit(separator: Char): List<String> = split(separator).filter { it.isNotEmpty() }
