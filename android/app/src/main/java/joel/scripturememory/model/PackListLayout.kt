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
        const val liftedCardWidth = 420f

        fun columns(width: Float): Int = when {
            width >= threeColumnWidth -> 3
            width >= twoColumnWidth -> 2
            else -> 1
        }

        fun liftedWidth(listWidth: Float, areaWidth: Float, areaHeight: Float, aspect: Float, margin: Float): Float {
            val fitting = min(areaWidth - 2 * margin, (areaHeight - 2 * margin) * aspect)
            return min(fitting, max(listWidth, liftedCardWidth))
        }
    }
}
