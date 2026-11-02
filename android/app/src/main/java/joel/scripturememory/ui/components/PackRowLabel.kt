package joel.scripturememory.ui.components

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import joel.scripturememory.model.Pack
import joel.scripturememory.model.Wording
import joel.scripturememory.ui.packs.PackBadge
import joel.scripturememory.ui.theme.AppTheme
import joel.scripturememory.ui.theme.AppType

@Composable
fun PackRowLabel(
    pack: Pack,
    modifier: Modifier = Modifier,
    title: String? = null,
    showsBadge: Boolean = false,
    detail: String? = null,
    titleLineLimit: Int = 1,
    trailing: (@Composable RowScope.() -> Unit)? = null,
) {
    val colors = AppTheme.colors
    Row(
        modifier,
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(VerseRowMetrics.accessorySpacing),
    ) {
        if (showsBadge) PackBadge(pack)
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(
                title ?: pack.name,
                style = AppType.body.copy(fontWeight = FontWeight.Medium),
                color = colors.label,
                maxLines = titleLineLimit,
            )
            Text(
                detail ?: Wording.verses(pack.verses.size),
                style = VerseRowMetrics.titleStyle,
                color = colors.secondaryLabel,
                maxLines = 1,
            )
        }
        trailing?.invoke(this)
    }
}
