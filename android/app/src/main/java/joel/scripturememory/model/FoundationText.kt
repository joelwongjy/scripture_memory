package joel.scripturememory.model

import java.text.BreakIterator
import java.text.Normalizer
import java.util.Locale
import kotlin.math.abs

private fun isFoundationWhitespace(c: Char): Boolean = when (c.code) {
    0x09, 0x20, 0xA0, 0x1680, 0x202F, 0x205F, 0x3000 -> true
    in 0x2000..0x200B -> true
    else -> false
}

private fun isFoundationWhitespaceOrNewline(c: Char): Boolean = when (c.code) {
    in 0x0A..0x0D, 0x85, 0x2028, 0x2029 -> true
    else -> isFoundationWhitespace(c)
}

fun String.trimmingWhitespaces(): String = trim(::isFoundationWhitespace)

fun String.trimmingWhitespacesAndNewlines(): String = trim(::isFoundationWhitespaceOrNewline)

fun isPunctuationOrSymbol(codePoint: Int): Boolean = when (Character.getType(codePoint).toByte()) {
    Character.CONNECTOR_PUNCTUATION,
    Character.DASH_PUNCTUATION,
    Character.START_PUNCTUATION,
    Character.END_PUNCTUATION,
    Character.INITIAL_QUOTE_PUNCTUATION,
    Character.FINAL_QUOTE_PUNCTUATION,
    Character.OTHER_PUNCTUATION,
    Character.MATH_SYMBOL,
    Character.CURRENCY_SYMBOL,
    Character.MODIFIER_SYMBOL,
    Character.OTHER_SYMBOL -> true
    else -> false
}

fun String.removingPunctuationAndSymbols(): String = buildString(length) {
    var i = 0
    while (i < this@removingPunctuationAndSymbols.length) {
        val codePoint = this@removingPunctuationAndSymbols.codePointAt(i)
        if (!isPunctuationOrSymbol(codePoint)) appendCodePoint(codePoint)
        i += Character.charCount(codePoint)
    }
}

fun String.lowercasedByScalar(): String = buildString(length) {
    val source = this@lowercasedByScalar
    var i = 0
    while (i < source.length) {
        val next = i + Character.charCount(source.codePointAt(i))
        append(source.substring(i, next).lowercase(Locale.ROOT))
        i = next
    }
}

fun String.canonicallyEquals(other: String): Boolean =
    this == other || Normalizer.normalize(this, Normalizer.Form.NFC) ==
        Normalizer.normalize(other, Normalizer.Form.NFC)

fun String.graphemes(): List<String> {
    if (isEmpty()) return emptyList()
    val iterator = BreakIterator.getCharacterInstance(Locale.ROOT)
    iterator.setText(this)
    val out = ArrayList<String>(length)
    var start = iterator.first()
    var end = iterator.next()
    while (end != BreakIterator.DONE) {
        out.add(substring(start, end))
        start = end
        end = iterator.next()
    }
    return out
}

fun isLetterGrapheme(grapheme: String): Boolean =
    grapheme.isNotEmpty() && Character.isAlphabetic(grapheme.codePointAt(0))

fun isNumberGrapheme(grapheme: String): Boolean {
    if (grapheme.isEmpty()) return false
    return when (Character.getType(grapheme.codePointAt(0)).toByte()) {
        Character.DECIMAL_DIGIT_NUMBER, Character.LETTER_NUMBER, Character.OTHER_NUMBER -> true
        else -> false
    }
}

fun isLetterOrNumberGrapheme(grapheme: String): Boolean =
    isLetterGrapheme(grapheme) || isNumberGrapheme(grapheme)

fun isUnicodeWhiteSpace(codePoint: Int): Boolean = when (codePoint) {
    in 0x09..0x0D, 0x20, 0x85, 0xA0, 0x1680, 0x2028, 0x2029, 0x202F, 0x205F, 0x3000 -> true
    in 0x2000..0x200A -> true
    else -> false
}

fun isNewlineCharacter(c: Char): Boolean = when (c.code) {
    in 0x0A..0x0D, 0x85, 0x2028, 0x2029 -> true
    else -> false
}

fun Double.roundedAwayFromZero(): Double {
    if (isNaN() || isInfinite() || abs(this) >= 4_503_599_627_370_496.0) return this
    return if (this >= 0) Math.round(this).toDouble() else -Math.round(-this).toDouble()
}
