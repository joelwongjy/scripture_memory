package joel.scripturememory.ui.components

import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import joel.scripturememory.R
import joel.scripturememory.ui.theme.AppTheme

@Composable
fun SelectionCheckmark() {
    Icon(R.drawable.ic_check, size = 16.dp, tint = AppTheme.colors.accent, contentDescription = "Selected")
}

@Composable
fun SelectionCircle(
    isSelected: Boolean,
    mixed: Boolean = false,
    size: Dp = 22.dp,
    tint: Color = AppTheme.colors.accent,
) {
    val icon = when {
        isSelected -> R.drawable.ic_check_circle_fill
        mixed -> R.drawable.ic_minus_circle_fill
        else -> R.drawable.ic_circle
    }
    Icon(icon, size = size, tint = if (isSelected || mixed) tint else AppTheme.colors.secondaryLabel)
}

@Composable
fun RowChevron() {
    Icon(R.drawable.ic_caret_right, size = 13.dp, tint = AppTheme.colors.tertiaryLabel)
}
