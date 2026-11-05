package joel.scripturememory.ui.components

import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.animateDpAsState
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.defaultMinSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.selection.toggleable
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import joel.scripturememory.R
import joel.scripturememory.ui.theme.AppLayout
import joel.scripturememory.ui.theme.AppMotion
import joel.scripturememory.ui.theme.AppTheme
import joel.scripturememory.ui.theme.AppType
import joel.scripturememory.ui.theme.sizeInDp

@Composable
fun GroupedSection(
    modifier: Modifier = Modifier,
    title: String? = null,
    footer: String? = null,
    content: @Composable () -> Unit,
) {
    val colors = AppTheme.colors
    Column(modifier.fillMaxWidth()) {
        if (title != null) {
            Text(
                title,
                Modifier.padding(start = AppLayout.panelPadding, end = AppLayout.panelPadding, bottom = 8.dp),
                style = AppType.footnote,
                color = colors.secondaryLabel,
            )
        }
        Column(Modifier.fillMaxWidth().groupedPanel()) { content() }
        if (footer != null) {
            Text(
                footer,
                Modifier.padding(start = AppLayout.panelPadding, end = AppLayout.panelPadding, top = 8.dp),
                style = AppType.footnote,
                color = colors.secondaryLabel,
            )
        }
    }
}

@Composable
fun RowDivider(inset: Dp = AppLayout.panelPadding) {
    Divider(Modifier.padding(start = inset))
}

@Composable
fun ListRow(
    title: String,
    modifier: Modifier = Modifier,
    subtitle: String? = null,
    value: String? = null,
    leading: (@Composable () -> Unit)? = null,
    titleColor: Color = AppTheme.colors.label,
    showsChevron: Boolean = false,
    enabled: Boolean = true,
    onClick: (() -> Unit)? = null,
    trailing: (@Composable RowScope.() -> Unit)? = null,
) {
    val colors = AppTheme.colors
    val clickModifier = if (onClick != null) {
        Modifier.pressable(enabled = enabled, pressedScale = 1f, pressedAlpha = 0.55f, onClick = onClick)
    } else {
        Modifier
    }
    Row(
        modifier
            .fillMaxWidth()
            .defaultMinSize(minHeight = 52.dp)
            .then(clickModifier)
            .padding(horizontal = AppLayout.panelPadding, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        if (leading != null) leading()
        Column(Modifier.weight(1f)) {
            Text(title, style = AppType.body, color = if (enabled) titleColor else colors.tertiaryLabel)
            if (subtitle != null) {
                Text(subtitle, Modifier.padding(top = 2.dp), style = AppType.footnote, color = colors.secondaryLabel)
            }
        }
        if (value != null) Text(value, style = AppType.body, color = colors.secondaryLabel, maxLines = 1)
        if (trailing != null) trailing()
        if (showsChevron) Icon(R.drawable.ic_caret_right, size = 13.dp, tint = colors.tertiaryLabel)
    }
}

@Composable
fun ToggleRow(
    title: String,
    checked: Boolean,
    onCheckedChange: (Boolean) -> Unit,
    modifier: Modifier = Modifier,
    subtitle: String? = null,
    leading: (@Composable () -> Unit)? = null,
    enabled: Boolean = true,
) {
    val colors = AppTheme.colors
    Row(
        modifier
            .fillMaxWidth()
            .defaultMinSize(minHeight = 52.dp)
            .toggleable(
                value = checked,
                enabled = enabled,
                role = Role.Switch,
                interactionSource = remember { androidx.compose.foundation.interaction.MutableInteractionSource() },
                indication = null,
                onValueChange = onCheckedChange,
            )
            .padding(horizontal = AppLayout.panelPadding, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        if (leading != null) leading()
        Column(Modifier.weight(1f)) {
            Text(title, style = AppType.body, color = if (enabled) colors.label else colors.tertiaryLabel)
            if (subtitle != null) {
                Text(subtitle, Modifier.padding(top = 2.dp), style = AppType.footnote, color = colors.secondaryLabel)
            }
        }
        ToggleTrack(checked)
    }
}

@Composable
fun ToggleTrack(checked: Boolean, tint: Color = AppTheme.colors.green) {
    val colors = AppTheme.colors
    val track by animateColorAsState(if (checked) tint else colors.fill, AppMotion.control(), label = "track")
    val thumb by animateDpAsState(if (checked) 21.dp else 3.dp, AppMotion.control(), label = "thumb")
    Box(
        Modifier
            .size(width = 48.dp, height = 30.dp)
            .clip(RoundedCornerShape(percent = 50))
            .background(track),
    ) {
        Box(
            Modifier
                .offset(x = thumb, y = 3.dp)
                .size(24.dp)
                .softShadow(CircleShape, 2.dp)
                .clip(CircleShape)
                .background(Color.White),
        )
    }
}

@Composable
fun SelectionMark(selected: Boolean, tint: Color = AppTheme.colors.accent) {
    if (selected) Icon(R.drawable.ic_check, size = 18.dp, tint = tint)
    else Box(Modifier.width(18.dp).height(18.dp))
}

@Composable
fun CircleIconBadge(icon: Int, tint: Color, size: Dp = 30.dp, iconSize: Dp = 18.dp) {
    Box(
        Modifier.size(size).clip(RoundedCornerShape(size * 0.3f)).background(tint.copy(alpha = 0.14f)),
        contentAlignment = Alignment.Center,
    ) {
        Icon(icon, size = iconSize, tint = tint)
    }
}

@Composable
fun AddItemRow(title: String, onClick: () -> Unit, modifier: Modifier = Modifier) {
    val colors = AppTheme.colors
    val circle = AppType.title2.sizeInDp().dp * 1.15f
    Row(
        modifier
            .fillMaxWidth()
            .defaultMinSize(minHeight = 52.dp)
            .semantics(mergeDescendants = true) { role = Role.Button }
            .pressable(pressedScale = 1f, pressedAlpha = 0.55f, onClick = onClick)
            .padding(horizontal = AppLayout.panelPadding, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Box(Modifier.size(circle).clip(CircleShape).background(colors.accent), contentAlignment = Alignment.Center) {
            Icon(R.drawable.ic_plus, size = circle * 0.55f, tint = Color.White)
        }
        Text(title, Modifier.weight(1f), style = AppType.body, color = colors.accent)
    }
}
