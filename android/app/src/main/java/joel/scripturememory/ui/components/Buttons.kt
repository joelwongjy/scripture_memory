package joel.scripturememory.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import joel.scripturememory.ui.theme.AppLayout
import joel.scripturememory.ui.theme.AppTheme
import joel.scripturememory.ui.theme.AppType
import joel.scripturememory.ui.theme.sizeInDp

private val Capsule = RoundedCornerShape(percent = 50)

@Composable
fun PrimaryButton(
    title: String,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    tint: Color = AppTheme.colors.accent,
    height: Dp = 50.dp,
    leadingIcon: Int? = null,
    onClick: () -> Unit,
) {
    val colors = AppTheme.colors
    Row(
        modifier
            .fillMaxWidth()
            .heightIn(min = height)
            .alpha(if (enabled) 1f else 0.4f)
            .pressable(enabled = enabled, onClick = onClick)
            .clip(Capsule)
            .background(tint)
            .padding(horizontal = 20.dp),
        horizontalArrangement = Arrangement.spacedBy(8.dp, Alignment.CenterHorizontally),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        if (leadingIcon != null) Icon(leadingIcon, size = 20.dp, tint = colors.onAccent)
        Text(title, style = AppType.headline, color = colors.onAccent, maxLines = 1)
    }
}

@Composable
fun SecondaryButton(
    title: String,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    tint: Color = AppTheme.colors.accent,
    height: Dp = 50.dp,
    leadingIcon: Int? = null,
    onClick: () -> Unit,
) {
    Row(
        modifier
            .fillMaxWidth()
            .heightIn(min = height)
            .alpha(if (enabled) 1f else 0.4f)
            .pressable(enabled = enabled, onClick = onClick)
            .clip(Capsule)
            .background(tint.copy(alpha = 0.12f))
            .padding(horizontal = 20.dp),
        horizontalArrangement = Arrangement.spacedBy(8.dp, Alignment.CenterHorizontally),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        if (leadingIcon != null) Icon(leadingIcon, size = 20.dp, tint = tint)
        Text(title, style = AppType.headline, color = tint, maxLines = 1)
    }
}

@Composable
fun BorderedButton(
    title: String,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    tint: Color = AppTheme.colors.accent,
    leadingIcon: Int? = null,
    onClick: () -> Unit,
) {
    Row(
        modifier
            .heightIn(min = AppLayout.minTapTarget)
            .alpha(if (enabled) 1f else 0.4f)
            .pressable(enabled = enabled, pressedScale = 0.97f, onClick = onClick)
            .clip(Capsule)
            .background(tint.copy(alpha = 0.12f))
            .padding(horizontal = 12.dp, vertical = 6.dp),
        horizontalArrangement = Arrangement.spacedBy(6.dp, Alignment.CenterHorizontally),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        if (leadingIcon != null) Icon(leadingIcon, size = AppType.body.sizeInDp().dp, tint = tint)
        Text(title, style = AppType.body, color = tint, maxLines = 1)
    }
}

@Composable
fun ChromeIconButton(
    icon: Int,
    label: String,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    tint: Color = AppTheme.colors.label,
    size: Dp = 44.dp,
    iconSize: Dp = 18.dp,
    onClick: () -> Unit,
) {
    val colors = AppTheme.colors
    Box(
        modifier
            .size(size)
            .alpha(if (enabled) 1f else 0.4f)
            .semantics { contentDescription = label }
            .pressable(enabled = enabled, pressedScale = 0.92f, onClick = onClick)
            .clip(CircleShape)
            .background(colors.panel)
            .hairlineBorder(CircleShape),
        contentAlignment = Alignment.Center,
    ) {
        Icon(icon, size = iconSize, tint = tint)
    }
}

@Composable
fun ChromeTextButton(
    title: String,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    tint: Color = AppTheme.colors.label,
    onClick: () -> Unit,
) {
    val colors = AppTheme.colors
    Box(
        modifier
            .height(44.dp)
            .alpha(if (enabled) 1f else 0.4f)
            .pressable(enabled = enabled, pressedScale = 0.95f, onClick = onClick)
            .clip(Capsule)
            .background(colors.panel)
            .hairlineBorder(Capsule)
            .padding(horizontal = 18.dp),
        contentAlignment = Alignment.Center,
    ) {
        Text(title, style = AppType.headline, color = tint, maxLines = 1)
    }
}

@Composable
fun TextButton(
    title: String,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    tint: Color = AppTheme.colors.accent,
    style: androidx.compose.ui.text.TextStyle = AppType.callout,
    onClick: () -> Unit,
) {
    Box(
        modifier
            .alpha(if (enabled) 1f else 0.4f)
            .dimOnPress(enabled = enabled, onClick = onClick)
            .padding(vertical = 8.dp, horizontal = 4.dp),
        contentAlignment = Alignment.Center,
    ) {
        Text(title, style = style, color = tint, maxLines = 1)
    }
}

@Composable
fun BottomActionBar(modifier: Modifier = Modifier, content: @Composable () -> Unit) {
    androidx.compose.foundation.layout.Column(
        modifier.fillMaxWidth().background(AppTheme.colors.chrome),
    ) {
        Divider()
        Box(
            Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp)
                .padding(top = 12.dp, bottom = 8.dp),
        ) { content() }
    }
}
