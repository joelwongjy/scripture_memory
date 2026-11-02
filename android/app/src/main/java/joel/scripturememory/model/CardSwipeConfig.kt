package joel.scripturememory.model

import androidx.compose.ui.geometry.Offset
import kotlin.math.abs
import kotlin.math.min

object CardSwipeConfig {
    const val threshold = 80f
    const val velocityThreshold = 400f
    const val flyWidth = 600f
    const val prevCardOffset = 420f

    private const val forwardDragCap = 150f
    private const val backwardDragCap = 200f

    fun forwardDragProgress(dragWidth: Float): Float {
        if (dragWidth >= 0) return 0f
        return min(abs(dragWidth) / forwardDragCap, 1f)
    }

    fun backwardDragProgress(dragWidth: Float): Float {
        if (dragWidth <= 0) return 0f
        return min(dragWidth / backwardDragCap, 1f)
    }

    fun clampedDragTranslation(translation: Offset, canGoNext: Boolean, canGoPrev: Boolean): Offset {
        val tx = translation.x
        if ((tx < 0 && canGoNext) || (tx > 0 && canGoPrev)) return translation
        return Offset(tx * 0.15f, translation.y * 0.15f)
    }
}
