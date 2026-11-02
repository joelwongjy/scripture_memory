package joel.scripturememory.ui.theme

import androidx.compose.foundation.LocalIndication
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.text.selection.LocalTextSelectionColors
import androidx.compose.foundation.text.selection.TextSelectionColors
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.ReadOnlyComposable
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.graphics.Color

val LocalAppColors = staticCompositionLocalOf { LightColors }
val LocalContentColor = staticCompositionLocalOf { Color.Unspecified }

object AppTheme {
    val colors: AppColors
        @Composable @ReadOnlyComposable get() = LocalAppColors.current
    val isDark: Boolean
        @Composable @ReadOnlyComposable get() = LocalAppColors.current.isDark
}

@Composable
fun AppTheme(content: @Composable () -> Unit) {
    val colors = if (isSystemInDarkTheme()) DarkColors else LightColors
    AppMotion.refresh(LocalContext.current)
    CompositionLocalProvider(
        LocalAppColors provides colors,
        LocalContentColor provides colors.label,
        LocalTextSelectionColors provides TextSelectionColors(colors.accent, colors.accent.copy(alpha = 0.25f)),
        content = content,
    )
}
