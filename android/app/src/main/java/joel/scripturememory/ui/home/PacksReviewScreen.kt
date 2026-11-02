package joel.scripturememory.ui.home

import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.defaultMinSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.selection.toggleable
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import joel.scripturememory.model.AppDefaults
import joel.scripturememory.model.BibleVersion
import joel.scripturememory.model.LearningStore
import joel.scripturememory.model.NewCardCap
import joel.scripturememory.model.Pack
import joel.scripturememory.model.PackPreferencesStore
import joel.scripturememory.model.SRSPhase
import joel.scripturememory.model.SRSQueueBuilder
import joel.scripturememory.model.SRSStore
import joel.scripturememory.model.Verse
import joel.scripturememory.ui.components.LocalNavigator
import joel.scripturememory.ui.components.PackRowLabel
import joel.scripturememory.ui.components.ReadableList
import joel.scripturememory.ui.components.RowDivider
import joel.scripturememory.ui.components.Text
import joel.scripturememory.ui.components.ToggleTrack
import joel.scripturememory.ui.components.groupedRow
import joel.scripturememory.ui.theme.AppLayout
import joel.scripturememory.ui.theme.AppTheme
import joel.scripturememory.ui.theme.AppType

private val toggleWidth = 48.dp

@Composable
private fun columnWidth(): Dp = 36.dp * LocalDensity.current.fontScale.coerceAtLeast(1f)

@Composable
fun PacksReviewScreen() {
    val navigator = LocalNavigator.current
    val store = SRSStore.shared
    val packs = PackPreferencesStore.shared.visible(BibleVersion.saved().packs)
    val today = SRSQueueBuilder.buildAllPacksSession(
        packs = store.activePacks(packs),
        store = store,
        newCap = NewCardCap.current(),
        dailyReviewCap = AppDefaults.standard.getInt(NewCardCap.dailyReviewCapKey) ?: NewCardCap.dailyReviewCapDefault,
    )

    ReadableList("Packs in Review", onBack = navigator::pop, verticalSpacing = 0.dp) {
        item(key = "tip") {
            Text(
                "All packs are reviewed by default. Turn one off to skip its verses in Daily Review.",
                Modifier.padding(start = AppLayout.panelPadding, end = AppLayout.panelPadding, bottom = 10.dp),
                style = AppType.footnote,
                color = AppTheme.colors.secondaryLabel,
            )
        }
        item(key = "headings") { ColumnHeadings(Modifier.groupedRow(0, packs.size + 1)) }
        itemsIndexed(packs, key = { _, pack -> pack.id }) { index, pack ->
            Column(Modifier.groupedRow(index + 1, packs.size + 1)) {
                PackReviewRow(pack, today)
                if (index < packs.lastIndex) RowDivider()
            }
        }
    }
}

@Composable
private fun ColumnHeadings(modifier: Modifier = Modifier) {
    val style = AppType.caption.copy(fontWeight = FontWeight.Medium)
    val width = columnWidth()
    Row(
        modifier
            .fillMaxWidth()
            .clearAndSetSemantics {}
            .padding(start = AppLayout.panelPadding, end = AppLayout.panelPadding, top = 12.dp),
        horizontalArrangement = Arrangement.End,
    ) {
        listOf("New", "Learn", "Due").forEach { title ->
            Text(
                title,
                Modifier.width(width),
                style = style,
                color = AppTheme.colors.secondaryLabel,
                textAlign = TextAlign.Center,
                maxLines = 1,
            )
        }
        Spacer(Modifier.width(8.dp + toggleWidth))
    }
}

@Composable
private fun PackReviewRow(pack: Pack, today: List<Verse>) {
    val store = SRSStore.shared
    val active = store.isActive(pack.name)
    Row(
        Modifier
            .fillMaxWidth()
            .defaultMinSize(minHeight = 60.dp)
            .toggleable(
                value = active,
                role = Role.Switch,
                interactionSource = remember { MutableInteractionSource() },
                indication = null,
                onValueChange = { store.setActive(pack.name, it) },
            )
            .padding(horizontal = AppLayout.panelPadding, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        PackRowLabel(pack, Modifier.weight(1f), titleLineLimit = 2)
        Waiting(pack, today, active)
        ToggleTrack(active, tint = AppTheme.colors.accent)
    }
}

@Composable
private fun Waiting(pack: Pack, today: List<Verse>, active: Boolean) {
    val store = SRSStore.shared
    val keys = pack.verses.map { it.srsKey }.toSet()
    val mine = today.filter { it.srsKey in keys }
    val learnt = LearningStore.shared.learntKeys
    val new = mine.count { store.state(it) == null && it.srsKey !in learnt }
    val learn = mine.count { store.state(it)?.phase == SRSPhase.learning }
    val review = mine.size - new - learn
    val style = AppType.callout.copy(fontWeight = FontWeight.SemiBold, fontFeatureSettings = "tnum")
    Row(
        Modifier
            .alpha(if (active) 1f else 0.4f)
            .clearAndSetSemantics { contentDescription = "$new new, $learn learning, $review due" },
    ) {
        WaitingColumn(new, ReviewColor.new, style)
        WaitingColumn(learn, ReviewColor.learn, style)
        WaitingColumn(review, ReviewColor.due, style)
    }
}

@Composable
private fun WaitingColumn(value: Int, color: Color, style: TextStyle) {
    Box(Modifier.width(columnWidth()), contentAlignment = Alignment.Center) {
        Text(
            "$value",
            style = style,
            color = if (value > 0) color else AppTheme.colors.tertiaryLabel,
            maxLines = 1,
        )
    }
}
