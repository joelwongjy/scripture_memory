package joel.scripturememory.ui.components

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.semantics.Role
import joel.scripturememory.ui.theme.AppMotion

@Composable
fun Modifier.pressable(
    enabled: Boolean = true,
    role: Role = Role.Button,
    label: String? = null,
    pressedScale: Float = 0.97f,
    pressedAlpha: Float = 1f,
    onLongClick: (() -> Unit)? = null,
    onClick: () -> Unit,
): Modifier {
    val source = remember { MutableInteractionSource() }
    val pressed by source.collectIsPressedAsState()
    val scale by animateFloatAsState(if (pressed) pressedScale else 1f, AppMotion.control(), label = "pressScale")
    val alpha by animateFloatAsState(if (pressed) pressedAlpha else 1f, AppMotion.control(), label = "pressAlpha")
    return this
        .graphicsLayer {
            scaleX = scale
            scaleY = scale
            this.alpha = alpha
        }
        .combinedClickable(
            interactionSource = source,
            indication = null,
            enabled = enabled,
            role = role,
            onClickLabel = label,
            onLongClick = onLongClick,
            onClick = onClick,
        )
}

@Composable
fun Modifier.dimOnPress(enabled: Boolean = true, onClick: () -> Unit): Modifier =
    pressable(enabled = enabled, pressedScale = 1f, pressedAlpha = 0.5f, onClick = onClick)
