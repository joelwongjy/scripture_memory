package joel.scripturememory.ui.theme

import android.content.Context
import android.provider.Settings
import androidx.compose.animation.core.AnimationSpec
import androidx.compose.animation.core.CubicBezierEasing
import androidx.compose.animation.core.Easing
import androidx.compose.animation.core.FiniteAnimationSpec
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.runtime.Composable
import androidx.compose.runtime.ReadOnlyComposable
import androidx.compose.runtime.compositionLocalOf
import kotlin.math.PI

object AppMotion {
    var reduceMotion: Boolean = false
        private set

    val easeInOut: Easing = CubicBezierEasing(0.42f, 0f, 0.58f, 1f)
    val smoothEasing: Easing = CubicBezierEasing(0.33f, 0f, 0.17f, 1f)
    val snappyEasing: Easing = CubicBezierEasing(0.25f, 0.1f, 0.1f, 1f)

    fun refresh(context: Context) {
        reduceMotion = Settings.Global.getFloat(
            context.contentResolver,
            Settings.Global.ANIMATOR_DURATION_SCALE,
            1f,
        ) == 0f
    }

    fun <T> control(): FiniteAnimationSpec<T> =
        if (reduceMotion) tween(200, easing = easeInOut) else spring(dampingRatio = 1f, stiffness = 440f)

    fun <T> content(): FiniteAnimationSpec<T> =
        if (reduceMotion) tween(250, easing = easeInOut) else spring(dampingRatio = 1f, stiffness = 158f)

    fun <T> movement(): FiniteAnimationSpec<T> =
        if (reduceMotion) tween(250, easing = easeInOut) else spring(dampingRatio = 0.85f, stiffness = 158f)

    fun <T> repeated(): FiniteAnimationSpec<T> =
        if (reduceMotion) tween(150) else springFor(0.24f, 1f)

    fun <T> recoil(): FiniteAnimationSpec<T> =
        if (reduceMotion) tween(150) else springFor(0.32f, 0.62f)

    private fun <T> springFor(response: Float, damping: Float): FiniteAnimationSpec<T> {
        val omega = (2 * PI / response).toFloat()
        return spring(damping, omega * omega)
    }

    fun <T> smooth(durationMillis: Int, delayMillis: Int = 0): FiniteAnimationSpec<T> =
        tween(durationMillis, delayMillis, smoothEasing)

    fun <T> snappy(durationMillis: Int, delayMillis: Int = 0): FiniteAnimationSpec<T> =
        tween(durationMillis, delayMillis, snappyEasing)

    const val settleMillis = 500L
    const val settleShortMillis = 300L
}
