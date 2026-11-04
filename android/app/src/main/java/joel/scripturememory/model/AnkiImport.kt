package joel.scripturememory.model

data class AnkiImport(
    val deckNames: List<String>,
    val notes: List<AnkiNote>,
) {
    constructor(notes: List<AnkiNote>) : this(
        notes.map { it.deck }.filter { it.isNotEmpty() }.distinct(),
        notes,
    )

    companion object
}

data class AnkiNote(
    val deck: String,
    val noteType: String,
    val fieldNames: List<String>,
    val fields: List<String>,
    val tags: List<String>,
    val cards: List<AnkiCardSchedule>,
)

data class AnkiCardSchedule(
    val kind: Kind,
    val isSuspended: Boolean,
    val intervalDays: Double,
    val ease: Double,
    val due: Date?,
    val reps: Int,
    val lapses: Int,
    val lastReviewed: Date?,
) {
    enum class Kind(val rawValue: String) {
        New("new"),
        Learning("learning"),
        Review("review"),
        Relearning("relearning"),
    }

    companion object {
        private const val epochTimestampFloor = 1_000_000_000L

        operator fun invoke(row: AnkiCardRow, timing: AnkiCollectionTiming): AnkiCardSchedule {
            val kind = when (row.type) {
                1 -> Kind.Learning
                2 -> Kind.Review
                3 -> Kind.Relearning
                else -> Kind.New
            }
            val dueNumber = if (row.originalDeckID != 0L && row.originalDue != 0L) row.originalDue else row.due
            val due = when {
                kind == Kind.New -> null
                row.queue == 2 || row.queue == 3 || row.type == 2 || dueNumber <= epochTimestampFloor ->
                    timing.dayStart(dueNumber)
                else -> Date.fromTimeIntervalSince1970(dueNumber.toDouble())
            }
            val intervalDays = when {
                row.interval > 0 -> row.interval.toDouble()
                row.interval < 0 -> -row.interval.toDouble() / 86_400
                else -> 0.0
            }
            return AnkiCardSchedule(
                kind = kind,
                isSuspended = row.queue == -1,
                intervalDays = intervalDays,
                ease = row.factor.toDouble() / 1_000,
                due = due,
                reps = row.reps,
                lapses = row.lapses,
                lastReviewed = row.lastReviewMilliseconds?.let { Date.fromTimeIntervalSince1970(it.toDouble() / 1_000) },
            )
        }
    }
}

sealed class AnkiImportException(message: String) : Exception(message) {
    data object Unreadable : AnkiImportException("unreadable") {
        private fun readResolve(): Any = Unreadable
    }

    data class Unsupported(val reason: String) : AnkiImportException(reason)

    data object Empty : AnkiImportException("empty") {
        private fun readResolve(): Any = Empty
    }
}

data class AnkiCardRow(
    val type: Int,
    val queue: Int,
    val due: Long,
    val interval: Long,
    val factor: Long,
    val reps: Int,
    val lapses: Int,
    val originalDue: Long,
    val originalDeckID: Long,
    val lastReviewMilliseconds: Long?,
)

data class AnkiCollectionTiming(
    val creation: Long,
    val creationMinutesWest: Int?,
    val currentMinutesWest: Int,
    val rolloverHour: Int?,
) {
    fun dayStart(day: Long): Date = Date.fromTimeIntervalSince1970(dayStartSeconds(day).toDouble())

    private fun dayStartSeconds(day: Long): Long {
        val rolloverHour = rolloverHour ?: return creation + day * 86_400
        val rolloverSeconds = rolloverHour.toLong() * 3_600 + currentMinutesWest.toLong() * 60
        val creationMinutesWest = creationMinutesWest
            ?: return localEpochDay(creation, currentMinutesWest) * 86_400 + rolloverSeconds + day * 86_400
        return (localEpochDay(creation, creationMinutesWest) + day) * 86_400 + rolloverSeconds
    }

    companion object {
        operator fun invoke(
            creation: Long,
            schedulerVersion: Int?,
            rollover: Int?,
            creationOffset: Int?,
            deviceMinutesWest: Int,
        ): AnkiCollectionTiming {
            val isV1 = (schedulerVersion ?: 1) < 2
            return AnkiCollectionTiming(
                creation = creation,
                creationMinutesWest = if (isV1) null else creationOffset,
                currentMinutesWest = deviceMinutesWest,
                rolloverHour = if (isV1) null else (rollover ?: 4).coerceIn(0, 23),
            )
        }

        private fun localEpochDay(seconds: Long, minutesWest: Int): Long =
            Math.floorDiv(seconds - minutesWest.toLong() * 60, 86_400L)
    }
}

object AnkiFieldCleaner {
    private val lineBreakTags = setOf("br")
    private val blockTags = setOf(
        "div", "p", "li", "ul", "ol", "tr", "table", "blockquote", "pre", "hr",
        "h1", "h2", "h3", "h4", "h5", "h6", "section", "article", "header", "footer",
    )
    private val entities = mapOf(
        "nbsp" to " ", "amp" to "&", "lt" to "<", "gt" to ">", "quot" to "\"", "apos" to "'",
        "ndash" to "–", "mdash" to "—", "hellip" to "…",
        "lsquo" to "‘", "rsquo" to "’", "ldquo" to "“", "rdquo" to "”",
        "laquo" to "«", "raquo" to "»", "middot" to "·", "bull" to "•",
        "copy" to "©", "reg" to "®", "deg" to "°", "times" to "×", "shy" to "",
    )

    fun clean(field: String, isHTML: Boolean = true): String {
        var scalars = unwrapClozes(field.scalars())
        scalars = removeSounds(scalars)
        if (isHTML) {
            scalars = decodeEntities(stripTags(scalars))
        }
        return normalizeWhitespace(scalars)
    }

    fun containsHTML(text: String): Boolean {
        val scalars = text.scalars()
        return scalars.indices.any { scalars[it] == '<'.code && tagEnd(scalars, it) != null }
    }

    private fun String.scalars(): List<Int> = codePoints().toArray().toList()

    private fun List<Int>.asString(): String =
        StringBuilder().also { builder -> forEach { builder.appendCodePoint(it) } }.toString()

    private fun matches(scalars: List<Int>, index: Int, literal: String, ignoringCase: Boolean = false): Boolean {
        var position = index
        for (expected in literal) {
            if (position >= scalars.size) return false
            val actual = scalars[position]
            val equal = if (ignoringCase) lowercased(actual) == lowercased(expected.code) else actual == expected.code
            if (!equal) return false
            position += 1
        }
        return true
    }

    private fun lowercased(scalar: Int): Int = if (scalar in 'A'.code..'Z'.code) scalar + 32 else scalar

    private fun isASCIILetter(scalar: Int): Boolean = scalar in 'a'.code..'z'.code || scalar in 'A'.code..'Z'.code

    private fun isASCIIDigit(scalar: Int): Boolean = scalar in '0'.code..'9'.code

    private fun find(literal: String, scalars: List<Int>, from: Int, ignoringCase: Boolean = false): Int? {
        for (index in from until scalars.size) {
            if (matches(scalars, index, literal, ignoringCase)) return index
        }
        return null
    }

    private fun clozeContentStart(scalars: List<Int>, index: Int): Int? {
        if (!matches(scalars, index, "{{c")) return null
        var position = index + 3
        val digitsStart = position
        while (position < scalars.size && isASCIIDigit(scalars[position])) position += 1
        if (position == digitsStart || !matches(scalars, position, "::")) return null
        return position + 2
    }

    private fun unwrapClozes(scalars: List<Int>): List<Int> {
        val output = ArrayList<Int>(scalars.size)
        var index = 0
        while (index < scalars.size) {
            val contentStart = clozeContentStart(scalars, index)
            val bounds = contentStart?.let { clozeBounds(scalars, it) }
            if (contentStart != null && bounds != null) {
                output += unwrapClozes(scalars.subList(contentStart, bounds.second))
                index = bounds.first + 2
                continue
            }
            output += scalars[index]
            index += 1
        }
        return output
    }

    private fun clozeBounds(scalars: List<Int>, start: Int): Pair<Int, Int>? {
        var depth = 1
        var answerEnd: Int? = null
        var index = start
        while (index < scalars.size) {
            when {
                matches(scalars, index, "{{") -> {
                    depth += 1
                    index += 2
                }
                matches(scalars, index, "}}") -> {
                    depth -= 1
                    if (depth == 0) return index to (answerEnd ?: index)
                    index += 2
                }
                depth == 1 && answerEnd == null && matches(scalars, index, "::") -> {
                    answerEnd = index
                    index += 2
                }
                else -> index += 1
            }
        }
        return null
    }

    private fun removeSounds(scalars: List<Int>): List<Int> {
        val output = ArrayList<Int>(scalars.size)
        var index = 0
        while (index < scalars.size) {
            val close = if (matches(scalars, index, "[sound:")) find("]", scalars, index + 7) else null
            if (close != null) {
                index = close + 1
                continue
            }
            output += scalars[index]
            index += 1
        }
        return output
    }

    private fun tagEnd(scalars: List<Int>, index: Int): Int? {
        if (index + 1 >= scalars.size) return null
        val next = scalars[index + 1]
        if (!(isASCIILetter(next) || next == '/'.code || next == '!'.code)) return null
        if (matches(scalars, index, "<!--")) {
            return find("-->", scalars, index + 4)?.let { it + 2 }
        }
        return find(">", scalars, index + 1)
    }

    private fun tagName(scalars: List<Int>, index: Int): String {
        var position = index + 1
        if (position < scalars.size && scalars[position] == '/'.code) position += 1
        val name = StringBuilder()
        while (position < scalars.size && (isASCIILetter(scalars[position]) || isASCIIDigit(scalars[position]))) {
            name.appendCodePoint(lowercased(scalars[position]))
            position += 1
        }
        return name.toString()
    }

    private fun stripTags(scalars: List<Int>): List<Int> {
        val output = ArrayList<Int>(scalars.size)
        var index = 0
        while (index < scalars.size) {
            val end = if (scalars[index] == '<'.code) tagEnd(scalars, index) else null
            if (end == null) {
                output += scalars[index]
                index += 1
                continue
            }
            val isClosing = scalars[index + 1] == '/'.code
            val name = tagName(scalars, index)
            if (!isClosing && (name == "style" || name == "script")) {
                val close = find("</$name", scalars, end + 1, ignoringCase = true)
                val closeEnd = close?.let { find(">", scalars, it) }
                if (closeEnd != null) {
                    index = closeEnd + 1
                    continue
                }
            }
            if (name in lineBreakTags) {
                output += '\n'.code
            } else if (name in blockTags && output.isNotEmpty() && output.last() != '\n'.code) {
                output += '\n'.code
            }
            index = end + 1
        }
        return output
    }

    private fun decodeEntities(scalars: List<Int>): List<Int> {
        val output = ArrayList<Int>(scalars.size)
        var index = 0
        while (index < scalars.size) {
            val decoded = if (scalars[index] == '&'.code) entity(scalars, index) else null
            if (decoded != null) {
                output += decoded.first
                index = decoded.second + 1
                continue
            }
            output += scalars[index]
            index += 1
        }
        return output
    }

    private fun entity(scalars: List<Int>, index: Int): Pair<List<Int>, Int>? {
        var end = index + 1
        while (end < scalars.size && end - index <= 10 && scalars[end] != ';'.code) {
            val scalar = scalars[end]
            if (!(isASCIILetter(scalar) || isASCIIDigit(scalar) || scalar == '#'.code)) return null
            end += 1
        }
        if (end >= scalars.size || scalars[end] != ';'.code || end <= index + 1) return null
        val name = scalars.subList(index + 1, end).asString()
        entities[name]?.let { return it.scalars() to end }
        if (!name.startsWith("#")) return null
        val digits = name.drop(1)
        val value = if (digits.startsWith("x") || digits.startsWith("X")) {
            digits.drop(1).takeIf { it.isNotEmpty() && it.all { c -> c.isDigit() || c.lowercaseChar() in 'a'..'f' } }
                ?.toLongOrNull(16)
        } else {
            digits.takeIf { it.isNotEmpty() && it.all { c -> c in '0'..'9' } }?.toLongOrNull()
        } ?: return null
        if (value <= 0 || value > 0x10FFFF || value in 0xD800..0xDFFF) return null
        return listOf(value.toInt()) to end
    }

    private fun isHorizontalSpace(scalar: Int): Boolean =
        scalar == ' '.code || scalar == '\t'.code || scalar == 0x00A0

    private fun normalizeWhitespace(scalars: List<Int>): String {
        val lines = mutableListOf<String>()
        var current = StringBuilder()
        var pendingSpace = false
        var index = 0
        fun finishLine() {
            lines += current.toString()
            current = StringBuilder()
            pendingSpace = false
        }
        while (index < scalars.size) {
            val scalar = scalars[index]
            if (scalar == '\r'.code || scalar == '\n'.code) {
                if (scalar == '\r'.code && index + 1 < scalars.size && scalars[index + 1] == '\n'.code) index += 1
                finishLine()
            } else if (isHorizontalSpace(scalar)) {
                pendingSpace = current.isNotEmpty()
            } else {
                if (pendingSpace) current.append(' ')
                pendingSpace = false
                current.appendCodePoint(scalar)
            }
            index += 1
        }
        finishLine()

        val kept = mutableListOf<String>()
        for (line in lines) {
            if (line.isEmpty() && (kept.lastOrNull()?.isEmpty() != false)) continue
            kept += line
        }
        while (kept.lastOrNull()?.isEmpty() == true) kept.removeAt(kept.lastIndex)
        return kept.joinToString("\n")
    }
}

object AnkiTextExport {
    private class Header {
        var delimiter: Int? = null
        var isHTML: Boolean? = null
        var deck = ""
        var noteType = ""
        var tags: List<String> = emptyList()
        var columns: String? = null
        var guidColumn = 0
        var deckColumn = 0
        var noteTypeColumn = 0
        var tagsColumn = 0
    }

    private val namedDelimiters = mapOf(
        "tab" to '\t'.code, "pipe" to '|'.code, "semicolon" to ';'.code,
        "colon" to ':'.code, "comma" to ','.code, "space" to ' '.code,
    )

    fun parse(text: String): AnkiImport {
        var scalars = text.codePoints().toArray().toList()
        if (scalars.firstOrNull() == 0xFEFF) scalars = scalars.drop(1)
        val header = Header()
        var index = 0
        var isFirstLine = true
        while (index < scalars.size) {
            val newline = scalars.subList(index, scalars.size).indexOf('\n'.code)
            val lineEnd = if (newline < 0) scalars.size else index + newline
            var line = scalars.subList(index, lineEnd).asString()
            if (line.endsWith("\r")) line = line.dropLast(1)
            if (isFirstLine && line.startsWith("tags:")) {
                header.tags = splitTags(line.drop(5))
            } else if (line.startsWith("#")) {
                applyHeaderLine(line.drop(1), header)
            } else {
                break
            }
            isFirstLine = false
            index = minOf(lineEnd + 1, scalars.size)
        }
        val body = scalars.subList(index, scalars.size)
        val delimiter = header.delimiter ?: sniffDelimiter(body)
        val records = parseRecords(body, delimiter)
        val isHTML = header.isHTML ?: records.any { record -> record.any(AnkiFieldCleaner::containsHTML) }
        val labels = header.columns?.let { parseRecords(it.codePoints().toArray().toList(), delimiter).firstOrNull() }
            ?: emptyList()
        val metaColumns = listOf(header.guidColumn, header.deckColumn, header.noteTypeColumn, header.tagsColumn)
            .filter { it > 0 }.toSet()

        val notes = mutableListOf<AnkiNote>()
        for (record in records) {
            val fieldNames = mutableListOf<String>()
            val fields = mutableListOf<String>()
            record.forEachIndexed { offset, value ->
                if (offset + 1 in metaColumns) return@forEachIndexed
                val label = labels.getOrNull(offset)?.trimSpaces() ?: ""
                fieldNames += label.ifEmpty { "Field ${fieldNames.size + 1}" }
                fields += AnkiFieldCleaner.clean(value, isHTML)
            }
            while (fields.isNotEmpty() && fields.last().isEmpty()) {
                fields.removeAt(fields.lastIndex)
                fieldNames.removeAt(fieldNames.lastIndex)
            }
            if (fields.isEmpty()) continue
            val tags = (header.tags + splitTags(column(header.tagsColumn, record))).distinct()
            notes += AnkiNote(
                deck = if (header.deckColumn > 0) column(header.deckColumn, record).trimSpaces() else header.deck,
                noteType = if (header.noteTypeColumn > 0) column(header.noteTypeColumn, record).trimSpaces() else header.noteType,
                fieldNames = fieldNames,
                fields = fields,
                tags = tags,
                cards = emptyList(),
            )
        }
        if (notes.isEmpty()) throw AnkiImportException.Empty
        return AnkiImport(notes)
    }

    private fun List<Int>.asString(): String =
        StringBuilder().also { builder -> forEach { builder.appendCodePoint(it) } }.toString()

    private fun column(number: Int, record: List<String>): String =
        if (number > 0 && number <= record.size) record[number - 1] else ""

    private fun splitTags(text: String): List<String> = text.splitOnWhitespace().distinct()

    private fun trimmedValue(value: String): String {
        val scalars = value.codePoints().toArray()
        if (scalars.size <= 1) return value
        var end = 1
        while (end < scalars.size && (scalars[end] in 'a'.code..'z'.code || scalars[end] in 'A'.code..'Z'.code || scalars[end] in '0'.code..'9'.code)) {
            end += 1
        }
        return scalars.take(end).asString()
    }

    private fun applyHeaderLine(line: String, header: Header) {
        val colon = line.indexOf(':')
        if (colon < 0) return
        val key = line.substring(0, colon).trimSpaces().lowercase()
        val value = line.substring(colon + 1)
        val trimmed = trimmedValue(value)
        val number = trimmed.trimSpaces().toIntOrNull()
        when (key) {
            "separator" -> {
                val named = namedDelimiters[trimmed.trimSpaces().lowercase()]
                val scalars = value.codePoints().toArray()
                if (named != null) {
                    header.delimiter = named
                } else if (scalars.size == 1) {
                    header.delimiter = scalars[0]
                }
            }
            "html" -> when (trimmed.lowercase()) {
                "true" -> header.isHTML = true
                "false" -> header.isHTML = false
            }
            "tags" -> header.tags = splitTags(value)
            "columns" -> header.columns = value
            "deck" -> header.deck = value.trimSpaces()
            "notetype" -> header.noteType = value.trimSpaces()
            "guid column" -> header.guidColumn = number ?: header.guidColumn
            "deck column" -> header.deckColumn = number ?: header.deckColumn
            "notetype column" -> header.noteTypeColumn = number ?: header.noteTypeColumn
            "tags column" -> header.tagsColumn = number ?: header.tagsColumn
        }
    }

    private fun sniffDelimiter(body: List<Int>): Int {
        val tab = '\t'.code
        val comma = ','.code
        val semicolon = ';'.code
        val lines = mutableListOf<Map<Int, Int>>()
        var counts = mutableMapOf<Int, Int>()
        var lineHasContent = false
        var inQuotes = false
        for (scalar in body) {
            if (lines.size == 20) break
            if (scalar == '"'.code) {
                inQuotes = !inQuotes
            } else if (!inQuotes && (scalar == '\n'.code || scalar == '\r'.code)) {
                if (lineHasContent) lines += counts
                counts = mutableMapOf()
                lineHasContent = false
                continue
            } else if (!inQuotes && (scalar == tab || scalar == comma || scalar == semicolon)) {
                counts[scalar] = (counts[scalar] ?: 0) + 1
            }
            lineHasContent = true
        }
        if (lineHasContent && lines.size < 20) lines += counts

        if (lines.any { (it[tab] ?: 0) > 0 }) return tab
        val candidates = listOf(comma, semicolon)
        fun isConsistent(delimiter: Int): Boolean {
            val first = lines.firstOrNull()?.get(delimiter) ?: return false
            return first > 0 && lines.all { it[delimiter] == first }
        }
        fun total(delimiter: Int): Int = lines.sumOf { it[delimiter] ?: 0 }
        val consistent = candidates.filter(::isConsistent)
        val pool = consistent.ifEmpty { candidates }
        val score: (Int) -> Int = if (consistent.isEmpty()) ::total else { delimiter -> lines.firstOrNull()?.get(delimiter) ?: 0 }
        var best = tab
        var bestScore = 0
        for (candidate in pool) {
            if (score(candidate) > bestScore) {
                best = candidate
                bestScore = score(candidate)
            }
        }
        return best
    }

    private fun parseRecords(scalars: List<Int>, delimiter: Int): List<List<String>> {
        val records = mutableListOf<List<String>>()
        var record = mutableListOf<String>()
        var field = StringBuilder()
        var inQuotes = false
        var wasQuoted = false
        var index = 0
        fun finishField() {
            record += field.toString()
            field = StringBuilder()
            wasQuoted = false
        }
        fun finishRecord() {
            finishField()
            if (!(record.size == 1 && record[0].isEmpty())) records += record
            record = mutableListOf()
        }
        while (index < scalars.size) {
            val scalar = scalars[index]
            if (inQuotes) {
                if (scalar == '"'.code) {
                    if (index + 1 < scalars.size && scalars[index + 1] == '"'.code) {
                        field.append('"')
                        index += 1
                    } else {
                        inQuotes = false
                    }
                } else {
                    field.appendCodePoint(scalar)
                }
            } else if (scalar == '"'.code && field.isEmpty() && !wasQuoted) {
                inQuotes = true
                wasQuoted = true
            } else if (scalar == delimiter) {
                finishField()
            } else if (scalar == '\n'.code || scalar == '\r'.code) {
                if (scalar == '\r'.code && index + 1 < scalars.size && scalars[index + 1] == '\n'.code) index += 1
                finishRecord()
            } else {
                field.appendCodePoint(scalar)
            }
            index += 1
        }
        if (field.isNotEmpty() || record.isNotEmpty() || wasQuoted) finishRecord()
        return records
    }
}

internal fun String.splitOnWhitespace(): List<String> {
    val words = mutableListOf<String>()
    val word = StringBuilder()
    for (char in this) {
        if (char.isWhitespace()) {
            if (word.isNotEmpty()) words += word.toString()
            word.clear()
        } else {
            word.append(char)
        }
    }
    if (word.isNotEmpty()) words += word.toString()
    return words
}

internal fun String.trimSpaces(): String =
    trim { it == '\t' || Character.getType(it) == Character.SPACE_SEPARATOR.toInt() }
