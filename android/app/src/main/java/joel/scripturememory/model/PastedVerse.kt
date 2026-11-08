package joel.scripturememory.model

data class PastedVerse(
    val reference: BibleReference?,
    val version: String?,
    val text: String,
) {
    companion object {

        val knownVersions: Map<String, String> = mapOf(
            "new international version" to "NIV",
            "english standard version" to "ESV",
            "new king james version" to "NKJV",
            "king james version" to "KJV",
            "new living translation" to "NLT",
            "new american standard bible" to "NASB",
            "christian standard bible" to "CSB",
            "berean standard bible" to "BSB",
            "new revised standard version" to "NRSV",
            "the message" to "MSG",
            "amplified bible" to "AMP",
            "new english translation" to "NET",
            "world english bible" to "WEB",
        )

        private class Tagged(val reference: BibleReference, val version: String?)

        private class Inline(val reference: BibleReference, val version: String?, val remainder: String)

        private val invisible = setOf(
            '\u200B', '\u200E', '\u200F', '\u202A', '\u202B', '\u202C', '\u202D', '\u202E',
            '\u2060', '\u2066', '\u2067', '\u2068', '\u2069', '\uFEFF',
        )

        fun share(raw: String): PastedVerse? {
            val pasted = parse(raw)
            if (pasted.reference == null || pasted.text.isEmpty()) return null
            if (pasted.text == raw.trimmingWhitespacesAndNewlines()) return null
            return pasted
        }

        fun parse(raw: String): PastedVerse {
            val lines = raw.filterNot { it in invisible }
                .replace("\r\n", "\n")
                .replace("\r", "\n")
                .split("\n")
                .map { it.trimmingWhitespaces() }
                .filter { it.isNotEmpty() && !isLink(it) }

            var reference: BibleReference? = null
            var version: String? = null
            var body = mutableListOf<String>()

            for (line in lines) {
                if (reference == null) {
                    val found = referenceLine(line)
                    if (found != null) {
                        reference = found.reference
                        version = found.version
                        continue
                    }
                }
                body += line
            }

            if (reference == null) {
                val found = inlineReference(body.joinToString(" "))
                if (found != null) {
                    reference = found.reference
                    version = found.version
                    body = mutableListOf(found.remainder)
                }
            }

            val text = cleaned(body.joinToString(" "), reference)
            return PastedVerse(reference, version, text)
        }

        private fun isLink(line: String): Boolean {
            val lower = line.lowercase()
            return lower.startsWith("http://") || lower.startsWith("https://") || lower.startsWith("www.")
        }

        private fun isPunctuation(c: Char): Boolean = when (Character.getType(c).toByte()) {
            Character.CONNECTOR_PUNCTUATION,
            Character.DASH_PUNCTUATION,
            Character.START_PUNCTUATION,
            Character.END_PUNCTUATION,
            Character.INITIAL_QUOTE_PUNCTUATION,
            Character.FINAL_QUOTE_PUNCTUATION,
            Character.OTHER_PUNCTUATION -> true
            else -> false
        }

        private fun isSpace(c: Char): Boolean = c.toString().trimmingWhitespaces().isEmpty()

        private fun String.trimming(extra: String, punctuation: Boolean = false): String =
            trim { isSpace(it) || it in extra || (punctuation && isPunctuation(it)) }

        private fun referenceLine(line: String): Tagged? {
            val found = BibleReference.find(line) ?: return null
            val before = line.substring(0, found.start).trimming("", punctuation = true)
            if (before.isNotEmpty()) return null
            val after = line.substring(found.end)
            val version = versionTag(after) ?: return null
            return Tagged(found.reference, version.ifEmpty { null })
        }

        private fun inlineReference(text: String): Inline? {
            val found = BibleReference.find(text) ?: return null
            val before = text.substring(0, found.start).trimmingWhitespaces()
            val after = text.substring(found.end)
            val tag = versionTag(after)
            val isTrailing = tag != null
            val isLeading = before.isEmpty()
            if (!isTrailing && !isLeading) return null
            if (isTrailing && before.isNotEmpty()) {
                return Inline(found.reference, tag?.ifEmpty { null }, before)
            }
            val (leading, rest) = leadingVersion(after)
            return Inline(found.reference, leading, rest)
        }

        fun versionCode(text: String): String? = versionTag(text)?.ifEmpty { null }

        private fun versionTag(text: String): String? {
            val trimmed = text.trimming("-–—,·|")
            if (trimmed.isEmpty()) return ""
            val bare = trimmed.trimming("()[]")
            if (isAbbreviation(bare)) return bare.uppercase()
            val lower = bare.lowercase()
            for ((name, code) in knownVersions) {
                if (!lower.startsWith(name)) continue
                val tail = lower.drop(name.length).trimmingWhitespaces()
                if (tail.isEmpty() || tail.trim { it in "()[]" }.uppercase() == code ||
                    tail.all { it.isDigit() || it == '(' || it == ')' || it == ' ' }
                ) {
                    return code
                }
            }
            val open = bare.lastIndexOf('(')
            if (open >= 0 && bare.endsWith(")")) {
                val inner = bare.substring(open + 1, bare.length - 1)
                if (isAbbreviation(inner)) return inner.uppercase()
            }
            return null
        }

        private fun leadingVersion(text: String): Pair<String?, String> {
            val trimmed = text.trimmingWhitespaces()
            val first = trimmed.takeWhile { !it.isWhitespace() }
            val bare = first.trim { it in "()[],:" }
            if (isAbbreviation(bare) && bare == bare.uppercase()) {
                return bare to trimmed.drop(first.length).trimmingWhitespaces()
            }
            return null to trimmed.trim { it in ":-–— " }
        }

        private fun isAbbreviation(text: String): Boolean {
            if (text.length !in 2..6) return false
            if (text.first().isLetter() != true) return false
            if (!text.all { it.isLetterOrDigit() }) return false
            val letters = text.filter { it.isLetter() }
            return letters == letters.uppercase()
        }

        private val footnoteLetters = Regex("\\[(?:[a-zA-Z]{1,2}|\\d{1,3})\\]")
        private val crossReferences = Regex("\\([A-Z]{1,2}\\)")
        private val runsOfSpace = Regex("\\s+")

        fun cleaned(text: String, reference: BibleReference?): String {
            var t = text
                .replace('\u2018', '\'')
                .replace('\u2019', '\'')
                .replace('\u201C', '"')
                .replace('\u201D', '"')
                .replace('\u00A0', ' ')
            t = t.replace(footnoteLetters, "")
            t = t.replace(crossReferences, "")
            val numbers = verseNumbers(reference)
            if (numbers.isNotEmpty()) {
                val alternation = numbers.joinToString("|")
                val verseMarks = Regex("(^|(?<=[\\s.,;:!?\"'\\)]))($alternation)(?=\\s?[A-Za-z\"'(])\\s?")
                t = t.replace(verseMarks, "")
            }
            t = t.replace(runsOfSpace, " ").trimmingWhitespaces()
            if (t.length >= 2 && t.first() == '"' && t.last() == '"' && '"' !in t.substring(1, t.length - 1)) {
                t = t.substring(1, t.length - 1)
            } else if (t.count { it == '"' } == 1 && (t.first() == '"' || t.last() == '"')) {
                t = t.replace("\"", "").trimmingWhitespaces()
            }
            return t
        }

        private fun verseNumbers(reference: BibleReference?): List<Int> {
            if (reference == null || reference.verses.isEmpty()) return emptyList()
            val numbers = mutableListOf<Int>()
            for (part in reference.verses.swiftSplit(',')) {
                val bounds = part.swiftSplit('-').map { it.swiftSplit(':').lastOrNull().orEmpty() }
                val start = bounds.firstOrNull()?.toIntOrNull() ?: continue
                val end = if (bounds.size > 1) bounds[1].toIntOrNull() ?: start else start
                if (':' in part || end < start) {
                    numbers += listOf(start, end)
                } else {
                    numbers += (start..minOf(end, start + 60))
                }
            }
            return numbers.sortedDescending()
        }
    }
}
