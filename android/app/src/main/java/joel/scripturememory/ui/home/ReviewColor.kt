package joel.scripturememory.ui.home

import androidx.compose.runtime.Composable
import androidx.compose.runtime.ReadOnlyComposable
import androidx.compose.ui.graphics.Color
import joel.scripturememory.ui.theme.AppTheme

object ReviewColor {
    val new: Color
        @Composable @ReadOnlyComposable get() = AppTheme.colors.accent
    val learn: Color
        @Composable @ReadOnlyComposable get() = AppTheme.colors.red
    val due: Color
        @Composable @ReadOnlyComposable get() = AppTheme.colors.green
}
