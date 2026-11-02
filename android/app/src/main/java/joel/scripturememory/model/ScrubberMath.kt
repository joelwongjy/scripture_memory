package joel.scripturememory.model

import kotlin.math.max
import kotlin.math.min

object ScrubberMath {

    fun fraction(index: Int, count: Int): Double {
        if (count <= 1) return 0.0
        val clamped = min(max(index, 0), count - 1)
        return clamped.toDouble() / (count - 1).toDouble()
    }

    fun index(fraction: Double, count: Int): Int {
        if (count <= 1) return 0
        val f = min(max(fraction, 0.0), 1.0)
        val raw = (f * (count - 1).toDouble()).roundedAwayFromZero().toInt()
        return min(max(raw, 0), count - 1)
    }

    fun trackTravel(containerHeight: Double, thumbSize: Double, inset: Double): Double =
        max(0.0, containerHeight - 2 * inset - thumbSize)

    fun thumbY(index: Int, count: Int, travel: Double, inset: Double): Double =
        inset + fraction(index, count) * travel

    fun thumbY(fraction: Double, travel: Double, inset: Double): Double =
        inset + min(max(fraction, 0.0), 1.0) * travel

    fun fractionForDrag(
        startThumbY: Double,
        translationY: Double,
        inset: Double,
        travel: Double,
    ): Double {
        if (!(travel > 0)) return 0.0
        return max(0.0, min(1.0, ((startThumbY + translationY) - inset) / travel))
    }

    fun indexForDrag(
        startThumbY: Double,
        translationY: Double,
        inset: Double,
        travel: Double,
        count: Int,
    ): Int {
        if (!(travel > 0)) return 0
        val targetTopInTrack = (startThumbY + translationY) - inset
        val fraction = max(0.0, min(travel, targetTopInTrack)) / travel
        return index(fraction, count)
    }
}
