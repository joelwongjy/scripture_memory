package joel.scripturememory.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.unit.dp
import joel.scripturememory.ui.theme.AppLayout
import joel.scripturememory.ui.theme.AppTheme

@Composable
fun Modifier.groupedRow(index: Int, count: Int): Modifier {
    val top = if (index == 0) AppLayout.cornerRadius else 0.dp
    val bottom = if (index == count - 1) AppLayout.cornerRadius else 0.dp
    return clip(RoundedCornerShape(top, top, bottom, bottom)).background(AppTheme.colors.panel)
}
