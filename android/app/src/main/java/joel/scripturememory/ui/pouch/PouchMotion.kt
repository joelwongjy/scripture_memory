package joel.scripturememory.ui.pouch

import androidx.compose.animation.core.SpringSpec
import androidx.compose.animation.core.spring
import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.exp
import kotlin.math.ln
import kotlin.math.sin
import kotlin.math.sqrt

private const val settlingEpsilon = 0.001f
private const val snappyDamping = 0.85f

internal class SpringCurve(val duration: Float, private val damping: Float) {
    private val omega = (2 * PI / duration).toFloat()

    val settling: Float = ln(1f / settlingEpsilon) / (damping * omega)

    fun at(t: Float): Float {
        if (t <= 0f) return 0f
        if (damping >= 1f) return 1f - (1f + omega * t) * exp(-omega * t)
        val damped = omega * sqrt(1f - damping * damping)
        val decay = exp(-damping * omega * t)
        return 1f - decay * (cos(damped * t) + damping * omega / damped * sin(damped * t))
    }
}

internal object PouchMotion {
    fun smooth(seconds: Float) = SpringCurve(seconds, 1f)

    fun snappy(seconds: Float) = SpringCurve(seconds, snappyDamping)

    fun smoothSpec(seconds: Float): SpringSpec<Float> {
        val omega = (2 * PI / seconds).toFloat()
        return spring(1f, omega * omega)
    }

    fun snappySpec(seconds: Float): SpringSpec<Float> {
        val omega = (2 * PI / seconds).toFloat()
        return spring(snappyDamping, omega * omega)
    }
}
