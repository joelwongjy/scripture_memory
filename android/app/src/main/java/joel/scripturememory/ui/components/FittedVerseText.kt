package joel.scripturememory.ui.components

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.TextMeasurer
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Constraints
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.dp
import joel.scripturememory.ui.theme.CardFont
import joel.scripturememory.ui.theme.CardFontStyle
import joel.scripturememory.ui.theme.LocalContentColor
import kotlin.math.ceil
import kotlin.math.floor

private const val naturalLineHeight = 1.2f

object VerseFit {
    private val sizes = HashMap<String, Float>()

    fun style(kind: CardFontStyle, size: Float, lineSpacing: Float, density: Density): TextStyle {
        val px = with(density) { size.dp.toSp() }
        val line = with(density) { (size * naturalLineHeight + lineSpacing).dp.toSp() }
        return CardFont.style(kind, px).copy(lineHeight = line)
    }

    fun height(
        measurer: TextMeasurer,
        text: String,
        width: Dp,
        size: Float,
        kind: CardFontStyle = CardFontStyle.Body,
        lineSpacing: Float,
        density: Density,
    ): Float {
        if (width <= 1.dp) return Float.MAX_VALUE
        val constraints = Constraints(maxWidth = with(density) { width.roundToPx() })
        val result = measurer.measure(text, style(kind, size, lineSpacing, density), constraints = constraints)
        return ceil(with(density) { result.size.height.toDp().value })
    }

    fun fontSize(
        measurer: TextMeasurer,
        text: String,
        width: Dp,
        height: Dp,
        kind: CardFontStyle = CardFontStyle.Body,
        lineSpacing: Float,
        minSize: Float,
        maxSize: Float,
        density: Density,
    ): Float {
        if (width <= 1.dp || height <= 1.dp || text.isEmpty()) return maxSize
        val key = "$kind|${width.value}|${height.value}|$lineSpacing|$minSize|$maxSize|${density.density}|$text"
        return sizes.getOrPut(key) {
            search(measurer, text, width, height.value, kind, lineSpacing, minSize, maxSize, density)
        }
    }

    private fun search(
        measurer: TextMeasurer,
        text: String,
        width: Dp,
        height: Float,
        kind: CardFontStyle,
        lineSpacing: Float,
        minSize: Float,
        maxSize: Float,
        density: Density,
    ): Float {
        if (height(measurer, text, width, maxSize, kind, lineSpacing, density) <= height) return maxSize
        var low = minSize
        var high = maxSize
        repeat(12) {
            val middle = (low + high) / 2
            if (height(measurer, text, width, middle, kind, lineSpacing, density) <= height) low = middle else high = middle
        }
        return floor(low * 2) / 2
    }
}

@Composable
fun FittedVerseText(
    text: String,
    lineSpacing: Float,
    minSize: Float,
    maxSize: Float,
    modifier: Modifier = Modifier,
    kind: CardFontStyle = CardFontStyle.Body,
    closingLine: String? = null,
    color: Color = LocalContentColor.current,
) {
    val measurer = rememberTextMeasurer(cacheSize = 0)
    val density = LocalDensity.current
    BoxWithConstraints(modifier) {
        val fit = remember(text, closingLine, maxWidth, maxHeight, lineSpacing, minSize, maxSize, kind, density) {
            val closing = closingLine?.let {
                VerseFit.height(measurer, it, maxWidth, maxSize, kind, lineSpacing, density)
            } ?: 0f
            val room = (maxHeight.value - closing).coerceAtLeast(1f).dp
            val full = VerseFit.height(measurer, text, maxWidth, maxSize, kind, lineSpacing, density)
            if (full <= room.value) {
                maxSize to lineSpacing
            } else {
                val tight = lineSpacing * 0.3f
                VerseFit.fontSize(measurer, text, maxWidth, room, kind, tight, minSize, maxSize, density) to tight
            }
        }
        val style = VerseFit.style(kind, fit.first, fit.second, density)
        Column(
            Modifier.fillMaxWidth(),
            verticalArrangement = Arrangement.spacedBy(with(density) { fit.second.dp }),
            horizontalAlignment = Alignment.End,
        ) {
            Text(text, Modifier.fillMaxWidth(), style = style, color = color)
            if (closingLine != null) Text(closingLine, style = style, color = color, textAlign = TextAlign.End)
        }
    }
}
