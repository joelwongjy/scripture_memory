package joel.scripturememory.ui.components

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.foundation.gestures.waitForUpOrCancellation
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.disabled
import androidx.compose.ui.semantics.onClick
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import joel.scripturememory.R
import joel.scripturememory.system.HapticEngine
import joel.scripturememory.ui.theme.AppMotion
import joel.scripturememory.ui.theme.AppTheme
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

@Composable
fun Stepper(
    value: Int,
    range: IntRange,
    label: String,
    onValueChange: (Int) -> Unit,
    modifier: Modifier = Modifier,
) {
    val colors = AppTheme.colors
    val current by rememberUpdatedState(value)
    val change by rememberUpdatedState(onValueChange)
    fun step(delta: Int) {
        val next = (current + delta).coerceIn(range.first, range.last)
        if (next != current) change(next)
    }
    Row(
        modifier
            .height(34.dp)
            .clip(RoundedCornerShape(percent = 50))
            .background(colors.fill),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        StepperButton(R.drawable.ic_minus, "Decrease $label", value > range.first) { step(-1) }
        Box(
            Modifier
                .width(1.dp)
                .height(16.dp)
                .background(colors.separator),
        )
        StepperButton(R.drawable.ic_plus, "Increase $label", value < range.last) { step(1) }
    }
}

@Composable
private fun StepperButton(icon: Int, label: String, enabled: Boolean, onStep: () -> Unit) {
    val colors = AppTheme.colors
    val step by rememberUpdatedState(onStep)
    var pressed by remember { mutableStateOf(false) }
    val alpha by animateFloatAsState(if (pressed) 0.45f else 1f, AppMotion.control(), label = "stepperPress")
    Box(
        Modifier
            .width(47.dp)
            .fillMaxHeight()
            .semantics {
                role = Role.Button
                contentDescription = label
                if (!enabled) disabled()
                onClick(label) {
                    step()
                    true
                }
            }
            .pointerInput(enabled) {
                if (!enabled) return@pointerInput
                coroutineScope {
                    awaitEachGesture {
                        awaitFirstDown()
                        pressed = true
                        HapticEngine.light()
                        step()
                        val repeating = launch {
                            delay(420)
                            var ticks = 0
                            while (true) {
                                step()
                                ticks += 1
                                delay(
                                    when {
                                        ticks < 8 -> 110L
                                        ticks < 30 -> 55L
                                        else -> 25L
                                    },
                                )
                            }
                        }
                        waitForUpOrCancellation()
                        repeating.cancel()
                        pressed = false
                    }
                }
            },
        contentAlignment = Alignment.Center,
    ) {
        Icon(
            icon,
            Modifier.alpha(if (enabled) alpha else 0.3f),
            size = 15.dp,
            tint = colors.label,
        )
    }
}
