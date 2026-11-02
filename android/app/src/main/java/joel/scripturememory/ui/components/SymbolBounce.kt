package joel.scripturememory.ui.components

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.spring
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.graphicsLayer
import joel.scripturememory.ui.theme.AppMotion

private class BounceRun(var isFirst: Boolean)

@Composable
fun Modifier.symbolBounce(trigger: Any? = Unit, onAppear: Boolean = false): Modifier {
    val scale = remember { Animatable(1f) }
    val run = remember { BounceRun(isFirst = true) }
    LaunchedEffect(trigger) {
        val skip = run.isFirst && !onAppear
        run.isFirst = false
        if (skip || AppMotion.reduceMotion) return@LaunchedEffect
        scale.animateTo(0.86f, AppMotion.snappy(90))
        scale.animateTo(1f, spring(dampingRatio = 0.42f, stiffness = Spring.StiffnessMediumLow), initialVelocity = 4f)
    }
    return graphicsLayer {
        scaleX = scale.value
        scaleY = scale.value
    }
}
