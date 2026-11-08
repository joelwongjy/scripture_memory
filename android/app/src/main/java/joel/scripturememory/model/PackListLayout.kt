package joel.scripturememory.model

import kotlin.math.max
import kotlin.math.min

class PackListLayout(width: Float, val spacing: Float) {
    val columns: Int = columns(width)
    val cardWidth: Float = (width - spacing * (columns - 1)) / columns

    val columnPitch: Float get() = cardWidth + spacing

    val pouchWidthLimit: Float?
        get() = if (columns > 1) cardWidth / pouchCardShare else null

    fun row(card: Int): Int = if (card >= 0) card / columns else -((columns - 1 - card) / columns)

    fun column(card: Int): Int = card - row(card) * columns

    fun rows(count: Int): Int = (count + columns - 1) / columns

    fun firstCard(row: Int): Int = row * columns

    fun offset(card: Int, distance: Int): Pair<Int, Int> {
        val target = card + distance
        return (column(target) - column(card)) to (row(target) - row(card))
    }

    fun centerOffset(card: Int): Float = (column(card) - (columns - 1) / 2f) * columnPitch

    companion object {
        const val twoColumnWidth = 540f
        const val threeColumnWidth = 960f
        const val pouchCardShare = 0.86f
        const val verseTextShare = 0.04f
        const val printedVerseShare = 0.038f
        const val flickProjectionSeconds = 0.998f / (1 - 0.998f) / 1_000

        fun columns(width: Float): Int = when {
            width >= threeColumnWidth -> 3
            width >= twoColumnWidth -> 2
            else -> 1
        }

        fun homeIsSideBySide(contentWidth: Float, height: Float): Boolean =
            columns(contentWidth) > 1 && contentWidth > height

        fun focalCardWidth(bodyTextSize: Float): Float = bodyTextSize / verseTextShare

        fun verseTextCeiling(cardWidth: Float, share: Float, readableSize: Float): Float =
            max(cardWidth * share, readableSize)

        fun titleSpan(barWidth: Float, leading: Float, trailing: Float, title: Float, gap: Float): Pair<Float, Float> {
            val width = min(title, max(barWidth - leading - trailing - 2 * gap, 0f))
            val x = min(max((barWidth - width) / 2, leading + gap), barWidth - trailing - gap - width)
            return x to width
        }

        fun positionLabel(card: Int, count: Int, columns: Int): String {
            val first = card / columns * columns
            val last = min(first + columns, count)
            return if (last > first + 1) "Cards ${first + 1}–$last of $count" else "Card ${first + 1} of $count"
        }

        fun liftedScale(dragged: Float, cardWidth: Float): Float =
            if (cardWidth <= 0f) 1f else 1f - 0.25f * min(dragged / cardWidth, 1f)

        fun putsCardBack(projected: Float, areaWidth: Float, areaHeight: Float): Boolean =
            projected > min(areaWidth, areaHeight) * 0.25f

        fun springVelocity(velocityX: Float, velocityY: Float, dx: Float, dy: Float): Float {
            val span = kotlin.math.hypot(dx, dy)
            if (span <= 1f) return 0f
            val toward = (velocityX * dx + velocityY * dy) / span
            return (toward / span).coerceIn(0f, 20f)
        }

        fun liftedWidth(
            listWidth: Float,
            focalWidth: Float,
            areaWidth: Float,
            areaHeight: Float,
            aspect: Float,
            margin: Float,
        ): Float {
            val fitting = min(areaWidth - 2 * margin, (areaHeight - 2 * margin) * aspect)
            return min(fitting, max(listWidth, focalWidth))
        }
    }
}
