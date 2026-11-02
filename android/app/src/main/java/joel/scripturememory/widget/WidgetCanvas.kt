package joel.scripturememory.widget

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.RectF
import android.graphics.Typeface
import android.os.Build
import android.text.Layout
import android.text.StaticLayout
import android.text.TextPaint
import android.text.TextUtils
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.toArgb
import androidx.core.content.ContextCompat
import androidx.core.content.res.ResourcesCompat
import androidx.core.graphics.withTranslation
import joel.scripturememory.R
import joel.scripturememory.ui.theme.DarkColors
import joel.scripturememory.ui.theme.LightColors
import kotlin.math.ceil
import kotlin.math.max
import kotlin.math.min

internal class WidgetInk(dark: Boolean) {
    private val colors = if (dark) DarkColors else LightColors

    val paper = if (dark) 0xFF212121.toInt() else 0xFFFAF6F0.toInt()
    val primary = colors.label.toArgb()
    val secondary = colors.secondaryLabel.toArgb()
    val tertiary = colors.tertiaryLabel.toArgb()
    val rule = colors.separator.toArgb()
    val faint = colors.label.copy(alpha = 0.07f).toArgb()
    val orange = colors.orange.toArgb()
    val accent = colors.accent.toArgb()
    val green = colors.green.toArgb()
    val onTint = Color.White.toArgb()
}

internal class WidgetType(context: Context) {
    val title: Typeface = ResourcesCompat.getFont(context, R.font.quattrocento_sans_bold)!!
    val verse: Typeface = ResourcesCompat.getFont(context, R.font.belleza)!!
    val serif: Typeface = ResourcesCompat.getFont(context, R.font.tinos)!!
    private val inter: Typeface = ResourcesCompat.getFont(context, R.font.inter)!!

    fun paint(face: Typeface, size: Float, color: Int): TextPaint =
        TextPaint(Paint.ANTI_ALIAS_FLAG or Paint.SUBPIXEL_TEXT_FLAG).apply {
            typeface = face
            textSize = size
            this.color = color
        }

    fun inter(weight: Int, size: Float, color: Int): TextPaint =
        paint(inter, size, color).apply { fontVariationSettings = "'wght' $weight, 'opsz' 14" }
}

internal class WidgetPx(val density: Float, val fontScale: Float) {
    fun dp(value: Float): Float = value * density
    fun sp(value: Float): Float = value * density * fontScale
    fun scaled(factor: Float) = WidgetPx(density * factor, fontScale)
}

internal fun textLayout(
    text: CharSequence,
    paint: TextPaint,
    width: Int,
    maxLines: Int = Int.MAX_VALUE,
    lineSpacing: Float = 0f,
): StaticLayout =
    StaticLayout.Builder.obtain(text, 0, text.length, paint, max(width, 1))
        .setIncludePad(false)
        .setLineSpacing(lineSpacing, 1f)
        .setMaxLines(maxLines)
        .setEllipsize(TextUtils.TruncateAt.END)
        .setBreakStrategy(Layout.BREAK_STRATEGY_HIGH_QUALITY)
        .build()

internal fun oneLine(text: String, paint: TextPaint, width: Float, minimumScale: Float): TextPaint {
    val measured = paint.measureText(text)
    if (measured <= width) return paint
    return TextPaint(paint).apply {
        textSize = paint.textSize * max(width / measured, minimumScale)
    }
}

internal fun lineHeight(paint: TextPaint): Float = paint.fontMetrics.run { descent - ascent }

internal fun Canvas.drawLine(text: String, paint: TextPaint, x: Float, top: Float, width: Float) {
    val fitted = TextUtils.ellipsize(text, paint, width, TextUtils.TruncateAt.END).toString()
    drawText(fitted, x, top - paint.fontMetrics.ascent, paint)
}

internal enum class VerseFamily {
    Small,
    Medium,
    Large;

    companion object {
        fun of(widthDp: Float, heightDp: Float): VerseFamily = when {
            widthDp < 220f -> Small
            heightDp < 230f -> Medium
            else -> Large
        }
    }
}

internal class WidgetCard(val bitmap: Bitmap, val cta: RectF? = null)

internal class WidgetRenderer(
    private val context: Context,
    private val widthDp: Float,
    private val heightDp: Float,
) {
    private val display = context.resources.displayMetrics
    private val configuration = context.resources.configuration
    private val px = WidgetPx(min(display.density, 3f), min(configuration.fontScale, 1.3f))
    private val type = WidgetType(context)

    private val width = ceil(widthDp * px.density).toInt().coerceAtLeast(1)
    private val height = ceil(heightDp * px.density).toInt().coerceAtLeast(1)

    private val radius = px.dp(16f)

    private fun card(ink: WidgetInk, draw: Canvas.() -> RectF?): WidgetCard {
        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            canvas.drawColor(ink.paper)
        } else {
            val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = ink.paper }
            canvas.drawRoundRect(0f, 0f, width.toFloat(), height.toFloat(), radius, radius, paint)
        }
        return WidgetCard(bitmap, canvas.draw())
    }

    fun verse(snapshot: WidgetBridge.Snapshot?, verse: WidgetVerse?, dark: Boolean): WidgetCard {
        val ink = WidgetInk(dark)
        return card(ink) {
            val pad = px.dp(16f)
            val area = RectF(pad, pad, width - pad, height - pad)
            if (verse == null) {
                emptyState(ink, area)
                return@card null
            }
            val isPinned = snapshot?.isPinned ?: false
            when (VerseFamily.of(widthDp, heightDp)) {
                VerseFamily.Small -> cardLayout(
                    verse, isPinned, ink, area,
                    VerseSizes(14f, 12f, 12f, 11f, 2f, 4f, 1.5f),
                )
                VerseFamily.Medium -> cardLayout(
                    verse, isPinned, ink, area,
                    VerseSizes(17f, 14f, 15f, 11f, 3f, 6f, 2.5f),
                )
                VerseFamily.Large -> return@card largeBody(verse, isPinned, snapshot, ink, area)
            }
            null
        }
    }

    private class VerseSizes(
        val title: Float,
        val reference: Float,
        val verse: Float,
        val pack: Float,
        val gap1: Float,
        val gap2: Float,
        val lineSpacing: Float,
    )

    private fun Canvas.emptyState(ink: WidgetInk, area: RectF) {
        val heading = type.inter(600, px.sp(11f), ink.secondary)
        drawLine("Scripture Memory", heading, area.left, area.top, area.width())
        val body = type.paint(type.serif, px.sp(13f), ink.secondary)
        val layout = textLayout("Open the app to set the verse you're learning.", body, area.width().toInt())
        withTranslation(area.left, area.top + lineHeight(heading) + px.dp(4f)) { layout.draw(this) }
    }

    private fun Canvas.cardLayout(
        verse: WidgetVerse,
        isPinned: Boolean,
        ink: WidgetInk,
        area: RectF,
        sizes: VerseSizes,
        minimumGap: Float = 6f,
    ) {
        val packPaint = type.inter(500, px.sp(sizes.pack), ink.tertiary)
        val packHeight = lineHeight(packPaint)
        val blockHeight = area.height() - packHeight - px.dp(minimumGap)
        FittedVerseBlock(
            type = type,
            px = px,
            ink = ink,
            title = verse.title,
            reference = verse.fullReference,
            verse = verse.verse,
            baseTitle = sizes.title,
            baseRef = sizes.reference,
            baseVerse = sizes.verse,
            gap1 = sizes.gap1,
            gap2 = sizes.gap2,
            lineSpacing = sizes.lineSpacing,
            titleLines = 2,
        ).draw(this, area.left, area.top, area.width(), blockHeight)
        packLabel(verse, isPinned, ink, packPaint, area.left, area.bottom - packHeight, area.width())
    }

    private fun Canvas.packLabel(
        verse: WidgetVerse,
        isPinned: Boolean,
        ink: WidgetInk,
        paint: TextPaint,
        x: Float,
        top: Float,
        width: Float,
    ) {
        var left = x
        if (isPinned) {
            val size = paint.textSize
            icon(R.drawable.ic_push_pin_fill, left, top + (lineHeight(paint) - size) / 2, size, ink.tertiary)
            left += size + px.dp(3f)
        }
        drawLine(verse.packName, paint, left, top, width - (left - x))
    }

    private fun Canvas.icon(res: Int, x: Float, y: Float, size: Float, color: Int) {
        val drawable = ContextCompat.getDrawable(context, res)?.mutate() ?: return
        drawable.setTint(color)
        drawable.setBounds(x.toInt(), y.toInt(), (x + size).toInt(), (y + size).toInt())
        drawable.draw(this)
    }

    private fun Canvas.rule(area: RectF, y: Float, ink: WidgetInk) {
        val paint = Paint().apply { color = ink.rule }
        drawRect(area.left, y, area.right, y + px.dp(0.5f), paint)
    }

    private fun Canvas.largeBody(
        verse: WidgetVerse,
        isPinned: Boolean,
        snapshot: WidgetBridge.Snapshot?,
        ink: WidgetInk,
        area: RectF,
    ): RectF {
        val streakPaint = type.inter(800, px.sp(18f), ink.primary)
        val week = snapshot?.week.orEmpty()
        val weekHeight = if (week.isEmpty()) 0f else lineHeight(type.inter(600, px.sp(9f), ink.secondary)) + px.dp(25f)
        val ctaPaint = type.inter(600, px.sp(14f), ink.onTint)
        val ctaHeight = lineHeight(ctaPaint) + px.dp(20f)
        val retentionHeight = lineHeight(streakPaint) + px.dp(11f) + weekHeight + px.dp(14f) + ctaHeight
        val rulePadding = px.dp(10f)
        val half = (area.height() - rulePadding * 2) / 2
        val bottomHeight = max(half, retentionHeight)
        val topHeight = area.height() - rulePadding * 2 - bottomHeight

        cardLayout(
            verse, isPinned, ink,
            RectF(area.left, area.top, area.right, area.top + topHeight),
            VerseSizes(20f, 16f, 17f, 11f, 4f, 8f, 4f),
            minimumGap = 10f,
        )
        val ruleY = area.top + topHeight + rulePadding
        rule(area, ruleY, ink)

        var y = ruleY + rulePadding + (bottomHeight - retentionHeight) / 2
        streakRow(snapshot, ink, area, y, streakPaint)
        y += lineHeight(streakPaint) + px.dp(11f)
        if (week.isNotEmpty()) {
            weekStrip(week, ink, area, y)
            y += weekHeight
        }
        y += px.dp(14f)
        return reviewCTA(snapshot?.dueToday ?: 0, ink, area, y, ctaHeight, ctaPaint)
    }

    private fun Canvas.streakRow(
        snapshot: WidgetBridge.Snapshot?,
        ink: WidgetInk,
        area: RectF,
        top: Float,
        value: TextPaint,
    ) {
        val baseline = top - value.fontMetrics.ascent
        val flame = px.dp(14f)
        icon(R.drawable.ic_fire_fill, area.left, baseline - flame, flame, ink.orange)
        var x = area.left + flame + px.dp(6f)
        val streak = "${snapshot?.streak ?: 0}"
        drawText(streak, x, baseline, value)
        x += value.measureText(streak) + px.dp(6f)
        drawText("day streak", x, baseline, type.inter(400, px.sp(13f), ink.secondary))
        val learned = "${snapshot?.learned ?: 0} learned"
        val learnedPaint = type.inter(500, px.sp(12f), ink.secondary)
        drawText(learned, area.right - learnedPaint.measureText(learned), baseline, learnedPaint)
    }

    private fun Canvas.weekStrip(week: List<WidgetBridge.WeekDay>, ink: WidgetInk, area: RectF, top: Float) {
        val column = area.width() / week.size
        val radius = px.dp(10.5f)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG)
        week.forEachIndexed { index, day ->
            val center = area.left + column * (index + 0.5f)
            val letter = type.inter(600, px.sp(9f), if (day.today) ink.orange else ink.secondary).apply {
                textAlign = Paint.Align.CENTER
            }
            drawText(day.letter, center, top - letter.fontMetrics.ascent, letter)
            val circleY = top + lineHeight(letter) + px.dp(4f) + radius
            paint.style = Paint.Style.FILL
            paint.color = if (day.done) ink.orange else ink.faint
            drawCircle(center, circleY, radius, paint)
            if (day.done) {
                val flame = px.dp(11f)
                icon(R.drawable.ic_fire_fill, center - flame / 2, circleY - flame / 2, flame, ink.onTint)
            } else if (day.today) {
                paint.style = Paint.Style.STROKE
                paint.strokeWidth = px.dp(1.5f)
                paint.color = ink.orange
                drawCircle(center, circleY, radius, paint)
            }
        }
    }

    private fun Canvas.reviewCTA(
        due: Int,
        ink: WidgetInk,
        area: RectF,
        top: Float,
        ctaHeight: Float,
        paint: TextPaint,
    ): RectF {
        val rect = RectF(area.left, top, area.right, top + ctaHeight)
        val background = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = if (due > 0) ink.accent else ink.green }
        drawRoundRect(rect, ctaHeight / 2, ctaHeight / 2, background)
        val iconSize = px.dp(14f)
        val x = rect.left + px.dp(14f)
        val iconRes = if (due > 0) R.drawable.ic_play_fill else R.drawable.ic_check_circle_fill
        icon(iconRes, x, rect.centerY() - iconSize / 2, iconSize, ink.onTint)
        val text = if (due > 0) "Review $due due today" else "All caught up today"
        val textX = x + iconSize + px.dp(7f)
        drawLine(text, paint, textX, rect.top + px.dp(10f), rect.right - textX - px.dp(14f))
        return RectF(
            rect.left / px.density,
            rect.top / px.density,
            rect.right / px.density,
            rect.bottom / px.density,
        )
    }

    fun progress(snapshot: WidgetBridge.Snapshot?, verse: WidgetVerse?, dark: Boolean): WidgetCard {
        val ink = WidgetInk(dark)
        return card(ink) {
            val pad = px.dp(16f)
            val area = RectF(pad, pad, width - pad, height - pad)
            val needed = progressHeight(px, verse != null)
            val metrics = if (needed > area.height()) px.scaled(area.height() / needed) else px
            progressBody(metrics, snapshot, verse, ink, area)
            null
        }
    }

    private fun progressHeight(px: WidgetPx, hasVerse: Boolean): Float {
        val heading = lineHeight(type.inter(600, px.sp(11f), 0))
        val title = if (hasVerse) lineHeight(type.paint(type.title, px.sp(20f), 0)) else 0f
        val reference = lineHeight(type.inter(500, px.sp(13f), 0))
        val stats = lineHeight(type.inter(700, px.sp(22f), 0)) + px.dp(2f) + lineHeight(type.inter(500, px.sp(11f), 0))
        return heading + px.dp(6f) + title + px.dp(3f) + reference + px.dp(18f) + stats
    }

    private fun Canvas.progressBody(
        px: WidgetPx,
        snapshot: WidgetBridge.Snapshot?,
        verse: WidgetVerse?,
        ink: WidgetInk,
        area: RectF,
    ) {
        var y = area.top
        val heading = type.inter(600, px.sp(11f), ink.secondary).apply { letterSpacing = 0.055f }
        drawLine("UP NEXT", heading, area.left, y, area.width())
        y += lineHeight(heading) + px.dp(6f)
        if (verse != null) {
            val title = oneLine(verse.title, type.paint(type.title, px.sp(20f), ink.primary), area.width(), 0.7f)
            drawLine(verse.title, title, area.left, y, area.width())
            y += lineHeight(title) + px.dp(3f)
            val reference = type.inter(500, px.sp(13f), ink.secondary)
            drawLine(verse.fullReference, reference, area.left, y, area.width())
            y += lineHeight(reference)
        } else {
            val message = type.paint(type.serif, px.sp(15f), ink.secondary)
            drawLine("Open the app to begin", message, area.left, y, area.width())
            y += lineHeight(message)
        }

        val value = type.inter(700, px.sp(22f), ink.primary)
        val label = type.inter(500, px.sp(11f), ink.secondary)
        val statsHeight = lineHeight(value) + px.dp(2f) + lineHeight(label)
        val statsTop = area.bottom - statsHeight
        if (verse != null) y = verseExcerpt(px, verse, ink, area, y, statsTop)
        rule(area, (y + statsTop) / 2, ink)
        statsColumns(px, snapshot, ink, area, statsTop, value, label)
    }

    private fun Canvas.verseExcerpt(
        px: WidgetPx,
        verse: WidgetVerse,
        ink: WidgetInk,
        area: RectF,
        top: Float,
        bottom: Float,
    ): Float {
        val gap = px.dp(8f)
        val room = bottom - top - gap - px.dp(24f)
        val spacing = px.dp(2.5f)
        val paint = type.paint(type.verse, px.sp(15f), ink.primary)
        val full = textLayout(verse.verse, paint, area.width().toInt(), lineSpacing = spacing)
        val lines = (0 until full.lineCount).count { full.getLineBottom(it) - spacing <= room }
        if (lines < 2) return top
        val fitted = if (lines >= full.lineCount) {
            full
        } else {
            textLayout(verse.verse, paint, area.width().toInt(), lines, spacing)
        }
        withTranslation(area.left, top + gap) { fitted.draw(this) }
        return top + gap + fitted.height
    }

    private fun Canvas.statsColumns(
        px: WidgetPx,
        snapshot: WidgetBridge.Snapshot?,
        ink: WidgetInk,
        area: RectF,
        top: Float,
        value: TextPaint,
        label: TextPaint,
    ) {
        val columns = listOf(
            Triple(R.drawable.ic_fire_fill, ink.orange, (snapshot?.streak ?: 0) to "day streak"),
            Triple(R.drawable.ic_stack_fill, ink.accent, (snapshot?.dueToday ?: 0) to "due today"),
            Triple(R.drawable.ic_seal_check_fill, ink.green, (snapshot?.learned ?: 0) to "learned"),
        )
        val column = area.width() / columns.size
        val iconSize = px.dp(13f)
        val gap = px.dp(4f)
        columns.forEachIndexed { index, (res, tint, stat) ->
            val center = area.left + column * (index + 0.5f)
            val number = "${stat.first}"
            val rowWidth = iconSize + gap + value.measureText(number)
            val left = center - rowWidth / 2
            val baseline = top - value.fontMetrics.ascent
            icon(res, left, baseline - iconSize * 1.05f, iconSize, tint)
            drawText(number, left + iconSize + gap, baseline, value)
            val labelPaint = TextPaint(label).apply { textAlign = Paint.Align.CENTER }
            drawText(
                stat.second,
                center,
                top + lineHeight(value) + px.dp(2f) - labelPaint.fontMetrics.ascent,
                labelPaint,
            )
            if (index > 0) {
                val separator = Paint().apply { color = ink.rule }
                val tall = px.dp(34f)
                val middle = top + (lineHeight(value) + px.dp(2f) + lineHeight(label)) / 2
                drawRect(
                    area.left + column * index,
                    middle - tall / 2,
                    area.left + column * index + px.dp(1f),
                    middle + tall / 2,
                    separator,
                )
            }
        }
    }
}
