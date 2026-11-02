package joel.scripturememory.ui.study

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import joel.scripturememory.ui.components.Icon
import joel.scripturememory.ui.components.hairlineBorder
import joel.scripturememory.ui.components.pressable
import joel.scripturememory.ui.components.softShadow
import joel.scripturememory.ui.theme.AppTheme

val CapsuleShape = RoundedCornerShape(percent = 50)

@Composable
fun Modifier.systemGlass(shape: Shape): Modifier = this
    .softShadow(shape, 6.dp)
    .clip(shape)
    .background(AppTheme.colors.panel)
    .hairlineBorder(shape)

@Composable
fun ChromeGroup(modifier: Modifier = Modifier, content: @Composable RowScope.() -> Unit) {
    Row(
        modifier.systemGlass(CapsuleShape).padding(horizontal = 2.dp),
        verticalAlignment = Alignment.CenterVertically,
        content = content,
    )
}

@Composable
fun ChromeGroupButton(
    icon: Int,
    label: String,
    enabled: Boolean = true,
    tint: Color = AppTheme.colors.label,
    onClick: () -> Unit,
) {
    Box(
        Modifier
            .size(44.dp)
            .alpha(if (enabled) 1f else 0.35f)
            .semantics { contentDescription = label }
            .pressable(enabled = enabled, pressedScale = 0.9f, onClick = onClick),
        contentAlignment = Alignment.Center,
    ) {
        Icon(icon, size = 19.dp, tint = tint)
    }
}
