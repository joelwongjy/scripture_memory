package joel.scripturememory.ui.study

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.AnimationVector1D
import androidx.compose.animation.core.spring
import joel.scripturememory.ui.theme.AppMotion
import kotlin.math.sqrt
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

private fun interpolatingSpring(stiffness: Float, damping: Float) =
    spring<Float>(dampingRatio = damping / (2f * sqrt(stiffness)), stiffness = stiffness)

fun CoroutineScope.triggerShake(offset: Animatable<Float, AnimationVector1D>) {
    if (AppMotion.reduceMotion) return
    launch { offset.animateTo(12f, interpolatingSpring(600f, 10f)) }
    launch {
        delay(70)
        launch { offset.animateTo(-8f, interpolatingSpring(600f, 12f)) }
        delay(70)
        offset.animateTo(0f, AppMotion.content())
    }
}
