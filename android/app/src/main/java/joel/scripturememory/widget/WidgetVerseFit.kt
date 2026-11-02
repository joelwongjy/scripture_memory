package joel.scripturememory.widget

import android.graphics.Canvas
import androidx.core.graphics.withTranslation
import kotlin.math.max
import kotlin.math.min

internal class FittedVerseBlock(
    private val type: WidgetType,
    private val px: WidgetPx,
    private val ink: WidgetInk,
    private val title: String,
    private val reference: String,
    private val verse: String,
    private val baseTitle: Float,
    private val baseRef: Float,
    private val baseVerse: Float,
    private val gap1: Float,
    private val gap2: Float,
    private val lineSpacing: Float,
    private val titleLines: Int,
    private val maxScale: Float = 1.2f,
    private val minPointSize: Float = 11f,
) {
    private val minScale: Float get() = min(maxScale, minPointSize / baseVerse)

    private fun titlePaint(k: Float) = type.paint(type.title, px.sp(baseTitle * k), ink.primary)
    private fun referencePaint(k: Float) = type.inter(500, px.sp(baseRef * k), ink.secondary)
    private fun versePaint(k: Float) = type.paint(type.verse, px.sp(baseVerse * k), ink.primary)

    private fun totalHeight(k: Float, width: Float): Float {
        val t = textLayout(title, titlePaint(k), width.toInt(), titleLines).height
        val r = lineHeight(referencePaint(k))
        val v = textLayout(verse, versePaint(k), width.toInt(), lineSpacing = px.dp(lineSpacing * k)).height
        return t + r + v + px.dp(gap1 * k) + px.dp(gap2 * k)
    }

    private fun scale(width: Float, height: Float): Float {
        if (width <= 1f || height <= 1f) return 1f
        if (totalHeight(maxScale, width) <= height) return maxScale
        var lo = minScale
        var hi = maxScale
        repeat(12) {
            val mid = (lo + hi) / 2
            if (totalHeight(mid, width) <= height) lo = mid else hi = mid
        }
        return lo
    }

    fun draw(canvas: Canvas, left: Float, top: Float, width: Float, height: Float) {
        val k = scale(width, height)
        var y = top
        val titleLayout = textLayout(title, titlePaint(k), width.toInt(), titleLines)
        canvas.withTranslation(left, y) { titleLayout.draw(this) }
        y += titleLayout.height + px.dp(gap1 * k)

        val refPaint = oneLine(reference, referencePaint(k), width, 0.8f)
        canvas.drawLine(reference, refPaint, left, y, width)
        y += lineHeight(referencePaint(k)) + px.dp(gap2 * k)

        val spacing = px.dp(lineSpacing * k)
        val paint = versePaint(k)
        val full = textLayout(verse, paint, width.toInt(), lineSpacing = spacing)
        val available = top + height - y
        val fitting = (0 until full.lineCount).count { full.getLineBottom(it) - spacing <= available }
        val verseLayout = if (fitting >= full.lineCount) {
            full
        } else {
            textLayout(verse, paint, width.toInt(), max(fitting, 1), spacing)
        }
        canvas.withTranslation(left, y) { verseLayout.draw(this) }
    }
}
