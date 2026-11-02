package joel.scripturememory.ui.home

import androidx.compose.runtime.Composable
import androidx.compose.runtime.ReadOnlyComposable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.layout
import androidx.compose.ui.unit.Constraints
import androidx.compose.ui.unit.Dp
import joel.scripturememory.ui.theme.AppTheme

internal fun Modifier.verticalOverhang(amount: Dp): Modifier = layout { measurable, constraints ->
    val inset = amount.roundToPx()
    val placeable = measurable.measure(constraints.copy(minHeight = 0, maxHeight = Constraints.Infinity))
    val height = (placeable.height - inset * 2).coerceAtLeast(0)
    layout(placeable.width, height) { placeable.place(0, -inset) }
}

internal val dayTrack: Color
    @Composable @ReadOnlyComposable get() = AppTheme.colors.label.copy(alpha = 0.11f)
