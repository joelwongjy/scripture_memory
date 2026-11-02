package joel.scripturememory.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.layout.wrapContentWidth
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import joel.scripturememory.ui.theme.AppLayout
import joel.scripturememory.ui.theme.AppTheme

val PanelShape = RoundedCornerShape(AppLayout.cornerRadius)
val CardShape = RoundedCornerShape(AppLayout.cardRadius)
val PaperShape = RoundedCornerShape(2.dp)

@Composable
fun Modifier.groupedPanel(): Modifier = clip(PanelShape).background(AppTheme.colors.panel)

@Composable
fun Panel(modifier: Modifier = Modifier, content: @Composable () -> Unit) {
    Box(modifier.fillMaxWidth().groupedPanel()) { content() }
}

fun Modifier.readableColumn(maxWidth: Dp = AppLayout.readableWidth): Modifier =
    fillMaxWidth().wrapContentWidth(Alignment.CenterHorizontally).widthIn(max = maxWidth)

@Composable
fun Divider(modifier: Modifier = Modifier, color: Color = AppTheme.colors.separator) {
    Box(modifier.fillMaxWidth().height(AppLayout.hairline).background(color))
}

@Composable
fun Modifier.softShadow(shape: androidx.compose.ui.graphics.Shape, elevation: Dp = 10.dp): Modifier =
    shadow(
        elevation = elevation,
        shape = shape,
        clip = false,
        ambientColor = AppTheme.colors.shadow,
        spotColor = AppTheme.colors.shadow,
    )

@Composable
fun Modifier.hairlineBorder(shape: androidx.compose.ui.graphics.Shape): Modifier =
    border(AppLayout.hairline, AppTheme.colors.separator, shape)
