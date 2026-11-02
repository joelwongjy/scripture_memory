package joel.scripturememory.ui.study

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.unit.dp
import joel.scripturememory.model.AppDefaults
import joel.scripturememory.ui.components.PaperShape
import joel.scripturememory.ui.components.softShadow
import joel.scripturememory.ui.theme.AppLayout
import joel.scripturememory.ui.theme.AppTheme
import joel.scripturememory.ui.theme.LightColors
import joel.scripturememory.ui.theme.LocalAppColors
import joel.scripturememory.ui.theme.LocalContentColor
import joel.scripturememory.ui.theme.PouchInk

private const val cardAppearanceKey = "cardAppearance.v1"
private const val matchSystem = "matchSystem"

@Composable
fun PaperAppearance(content: @Composable () -> Unit) {
    if (AppDefaults.standard.getString(cardAppearanceKey) == matchSystem) {
        content()
    } else {
        CompositionLocalProvider(
            LocalAppColors provides LightColors,
            LocalContentColor provides LightColors.label,
            content = content,
        )
    }
}

@Composable
fun Modifier.flashcardStyle(): Modifier {
    val isDark = AppTheme.isDark
    return this
        .softShadow(PaperShape, 8.dp)
        .clip(PaperShape)
        .background(PouchInk.paper(isDark))
        .border(AppLayout.hairline, PouchInk.edgeLine(isDark), PaperShape)
        .padding(AppLayout.cardPadding)
}
