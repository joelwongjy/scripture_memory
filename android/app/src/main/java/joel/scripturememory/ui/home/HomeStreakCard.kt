package joel.scripturememory.ui.home

import androidx.compose.animation.animateContentSize
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.platform.LocalConfiguration
import joel.scripturememory.R
import joel.scripturememory.model.StreakStore
import joel.scripturememory.ui.components.Icon
import joel.scripturememory.ui.components.NumericText
import joel.scripturememory.ui.components.RowChevron
import joel.scripturememory.ui.components.Text
import joel.scripturememory.ui.components.groupedPanel
import joel.scripturememory.ui.components.pressable
import joel.scripturememory.ui.components.symbolBounce
import joel.scripturememory.ui.theme.AppLayout
import joel.scripturememory.ui.theme.AppMotion
import joel.scripturememory.ui.theme.AppTheme
import joel.scripturememory.ui.theme.AppType

private const val narrowScreenWidth = 380

@Composable
fun HomeStreakCard(modifier: Modifier = Modifier, onClick: () -> Unit) {
    val colors = AppTheme.colors
    val streak = StreakStore.shared
    val count = streak.current
    val lit = streak.isTodayDone
    val label = if (lit || count == 0) "$count day streak" else "$count day streak, open the app today to keep it"
    val titleStyle = AppType.callout.copy(fontWeight = FontWeight.SemiBold)
    val isNarrow = LocalConfiguration.current.screenWidthDp < narrowScreenWidth
    Row(
        modifier
            .fillMaxWidth()
            .semantics(mergeDescendants = true) { contentDescription = label }
            .pressable(label = "Shows your streak", onClick = onClick)
            .animateContentSize(AppMotion.content())
            .groupedPanel()
            .padding(horizontal = AppLayout.panelPadding, vertical = AppLayout.panelRowPadding),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Icon(
            R.drawable.ic_fire_fill,
            Modifier.symbolBounce(count),
            size = 24.dp,
            tint = if (lit) colors.orange else colors.tertiaryLabel,
        )
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(1.dp)) {
            Row {
                NumericText(count, style = titleStyle, color = colors.label)
                Text(" day streak", style = titleStyle, color = colors.label)
            }
            if (!lit && count > 0) {
                Text(
                    "Open the app today to keep it",
                    style = AppType.caption.copy(fontWeight = FontWeight.Medium),
                    color = colors.orange,
                )
            }
        }
        Row(
            Modifier.clearAndSetSemantics {},
            horizontalArrangement = Arrangement.spacedBy(if (isNarrow) 3.dp else 5.dp),
        ) {
            streak.thisWeek().forEach { day ->
                Column(
                    Modifier.alpha(if (day.isFuture) 0.35f else 1f),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(3.dp),
                ) {
                    Box(
                        Modifier
                            .size(if (isNarrow) 15.dp else 17.dp)
                            .clip(CircleShape)
                            .background(if (day.done) colors.orange else dayTrack)
                            .then(
                                if (!day.done && day.isToday) Modifier.border(1.5.dp, colors.orange, CircleShape)
                                else Modifier,
                            ),
                        contentAlignment = Alignment.Center,
                    ) {
                        if (day.done) Icon(R.drawable.ic_fire_fill, size = 11.dp, tint = colors.onAccent)
                    }
                    Text(
                        day.initial,
                        style = AppType.caption2.copy(
                            fontSize = 10.sp,
                            fontWeight = if (day.isToday) FontWeight.Bold else FontWeight.Medium,
                        ),
                        color = if (day.isToday) colors.orange else colors.secondaryLabel,
                        maxLines = 1,
                    )
                }
            }
        }
        RowChevron()
    }
}
