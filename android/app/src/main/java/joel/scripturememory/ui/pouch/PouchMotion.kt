package joel.scripturememory.ui.pouch

import androidx.compose.animation.core.SpringSpec
import androidx.compose.animation.core.spring
import kotlin.math.PI

internal const val motionThreshold = 0.0005f

internal object PouchMotion {
    fun smooth(seconds: Float): SpringSpec<Float> = spring(1f, stiffness(seconds), motionThreshold)

    fun snappy(seconds: Float): SpringSpec<Float> = spring(0.85f, stiffness(seconds), motionThreshold)

    private fun stiffness(seconds: Float): Float {
        val omega = (2 * PI / seconds).toFloat()
        return omega * omega
    }
}
