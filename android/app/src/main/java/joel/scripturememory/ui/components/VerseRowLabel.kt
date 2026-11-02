package joel.scripturememory.ui.components

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.dp
import joel.scripturememory.model.Verse
import joel.scripturememory.model.VerseNumbering
import joel.scripturememory.model.trimmingWhitespacesAndNewlines
import joel.scripturememory.ui.theme.AppTheme
import joel.scripturememory.ui.theme.AppType
import java.text.Normalizer

object VerseRowMetrics {
    val referenceStyle: TextStyle get() = AppType.body.copy(fontWeight = FontWeight.SemiBold)
    val titleStyle: TextStyle get() = AppType.subheadline
    val previewStyle: TextStyle get() = AppType.subheadline
    val accessorySpacing = 12.dp
}

@Composable
fun VerseRowLabel(
    verse: Verse,
    modifier: Modifier = Modifier,
    showsPreview: Boolean = false,
    highlight: String? = null,
    leading: (@Composable RowScope.() -> Unit)? = null,
    trailing: (@Composable RowScope.() -> Unit)? = null,
) {
    val colors = AppTheme.colors
    Row(
        modifier.semantics(mergeDescendants = true) {},
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(VerseRowMetrics.accessorySpacing),
    ) {
        leading?.invoke(this)
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                Text(
                    "${verse.book} ${verse.reference}",
                    Modifier.weight(1f, fill = false).alignByBaseline(),
                    style = VerseRowMetrics.referenceStyle,
                    color = colors.label,
                    maxLines = 1,
                )
                verse.pinnedVersion?.let { pinned ->
                    Text(
                        pinned,
                        Modifier.alignByBaseline(),
                        style = AppType.caption.copy(fontWeight = FontWeight.SemiBold),
                        color = colors.secondaryLabel,
                        maxLines = 1,
                    )
                }
            }
            Text(
                verseRowSubtitle(verse),
                style = VerseRowMetrics.titleStyle,
                color = colors.secondaryLabel,
                maxLines = 1,
            )
            if (showsPreview) {
                Text(
                    versePreview(verse.verse, highlight, colors.label),
                    Modifier.padding(top = 2.dp),
                    style = VerseRowMetrics.previewStyle,
                    color = colors.secondaryLabel,
                    maxLines = 2,
                )
            }
        }
        trailing?.invoke(this)
    }
}

private fun verseRowSubtitle(verse: Verse): String {
    val code = VerseNumbering.code(verse) ?: return verse.title
    return "$code · ${verse.title}"
}

private const val leadInLimit = 50
private const val leadInContext = 24

fun versePreview(text: String, highlight: String?, emphasis: Color): AnnotatedString {
    val query = highlight?.trimmingWhitespacesAndNewlines().orEmpty()
    val first = if (query.isEmpty()) null else foldedMatches(text, query).firstOrNull()
    if (first == null) return AnnotatedString(text)

    var shown = text
    if (first.first > leadInLimit) {
        var start = first.first - leadInContext
        while (start > 0 && !text[start - 1].isWhitespace()) start -= 1
        shown = "…" + text.substring(start)
    }

    val style = SpanStyle(color = emphasis, fontWeight = FontWeight.SemiBold)
    return buildAnnotatedString {
        var cursor = 0
        for (match in foldedMatches(shown, query)) {
            append(shown, cursor, match.first)
            withStyle(style) { append(shown, match.first, match.last + 1) }
            cursor = match.last + 1
        }
        append(shown, cursor, shown.length)
    }
}

private class Folded(val text: String, val origins: IntArray)

private fun fold(source: String): Folded {
    val text = StringBuilder(source.length)
    val origins = ArrayList<Int>(source.length)
    source.forEachIndexed { index, character ->
        val decomposed = Normalizer.normalize(character.toString(), Normalizer.Form.NFD)
        for (piece in decomposed) {
            if (Character.getType(piece) == Character.NON_SPACING_MARK.toInt()) continue
            for (lower in piece.lowercase()) {
                text.append(lower)
                origins.add(index)
            }
        }
    }
    return Folded(text.toString(), origins.toIntArray())
}

private fun foldedMatches(source: String, query: String): List<IntRange> {
    val needle = fold(query).text
    if (needle.isEmpty()) return emptyList()
    val folded = fold(source)
    val found = ArrayList<IntRange>()
    var from = 0
    while (true) {
        val at = folded.text.indexOf(needle, from)
        if (at < 0) return found
        val end = at + needle.length
        found.add(folded.origins[at]..folded.origins[end - 1])
        from = end
    }
}
