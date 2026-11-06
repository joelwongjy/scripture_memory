package joel.scripturememory.ui.components

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import joel.scripturememory.R
import joel.scripturememory.model.CardFooter
import joel.scripturememory.model.Pack
import joel.scripturememory.model.Verse
import joel.scripturememory.system.HapticEngine
import joel.scripturememory.ui.theme.AppLayout
import joel.scripturememory.ui.theme.AppTheme
import joel.scripturememory.ui.theme.AppType

enum class PackVerseMarker { Checkmark, Pin }

@Composable
private fun PackVerseMarker.Mark() {
    when (this) {
        PackVerseMarker.Checkmark -> SelectionCheckmark()
        PackVerseMarker.Pin -> Icon(
            R.drawable.ic_push_pin_fill,
            size = 16.dp,
            tint = AppTheme.colors.accent,
            contentDescription = "Pinned",
        )
    }
}

@Composable
fun PackVersePicker(
    packs: List<Pack>,
    modifier: Modifier = Modifier,
    selectedKey: String? = null,
    marker: PackVerseMarker = PackVerseMarker.Checkmark,
    header: String? = null,
    footer: String? = null,
    onSelect: (Verse) -> Unit,
) {
    val colors = AppTheme.colors
    val navigator = LocalNavigator.current
    GroupedSection(modifier, title = header, footer = footer) {
        packs.forEachIndexed { index, pack ->
            if (index > 0) RowDivider()
            val chosen = pack.verses.firstOrNull { it.srsKey == selectedKey }
            Box(
                Modifier
                    .fillMaxWidth()
                    .pressable(pressedScale = 1f, pressedAlpha = 0.55f) {
                        navigator.push("pickVerse-${pack.id}") {
                            VersePickList(pack, selectedKey, marker, onSelect)
                        }
                    }
                    .padding(horizontal = AppLayout.panelPadding, vertical = 10.dp),
            ) {
                PackRowLabel(pack, showsBadge = true) {
                    if (chosen != null) {
                        Text(
                            "${chosen.book} ${chosen.reference}",
                            style = AppType.footnote.copy(fontWeight = FontWeight.SemiBold),
                            color = colors.accent,
                            maxLines = 1,
                        )
                        marker.Mark()
                    }
                    RowChevron()
                }
            }
        }
    }
}

@Composable
private fun VersePickList(
    pack: Pack,
    selectedKey: String?,
    marker: PackVerseMarker,
    onSelect: (Verse) -> Unit,
) {
    val navigator = LocalNavigator.current
    Column(Modifier.fillMaxSize()) {
        TopBar(pack.name, onBack = navigator::pop)
        LazyColumn(
            Modifier.weight(1f).fillMaxWidth(),
            contentPadding = PaddingValues(
                start = AppLayout.screenMargin,
                end = AppLayout.screenMargin,
                top = AppLayout.spacing,
                bottom = LocalBottomBarPadding.current + 24.dp,
            ),
        ) {
            val groups = pack.verses.fold(mutableListOf<MutableList<Verse>>()) { acc, verse ->
                val last = acc.lastOrNull()?.last()
                if (last != null && CardFooter.groupHeading(last) == CardFooter.groupHeading(verse)) acc.last().add(verse) else acc.add(mutableListOf(verse))
                acc
            }
            groups.forEachIndexed { groupIndex, group ->
                val heading = CardFooter.groupHeading(group.first())
                if (heading != null) {
                    item(key = "section-$groupIndex") {
                        Text(
                            heading,
                            Modifier
                                .readableColumn()
                                .padding(
                                    start = AppLayout.panelPadding,
                                    end = AppLayout.panelPadding,
                                    top = if (groupIndex == 0) 0.dp else 20.dp,
                                    bottom = 8.dp,
                                ),
                            style = AppType.footnote,
                            color = AppTheme.colors.secondaryLabel,
                        )
                    }
                } else if (groupIndex > 0) {
                    item(key = "gap-$groupIndex") { Spacer(Modifier.height(20.dp)) }
                }
                itemsIndexed(group, key = { _, verse -> verse.srsKey }) { index, verse ->
                    Column(Modifier.readableColumn().groupedRow(index, group.size)) {
                        VerseRowLabel(
                            verse,
                            Modifier
                                .fillMaxWidth()
                                .pressable(pressedScale = 1f, pressedAlpha = 0.55f) {
                                    HapticEngine.light()
                                    onSelect(verse)
                                    navigator.pop()
                                }
                                .padding(horizontal = AppLayout.panelPadding, vertical = 10.dp),
                            trailing = { if (verse.srsKey == selectedKey) marker.Mark() },
                        )
                        if (index < group.lastIndex) RowDivider()
                    }
                }
            }
        }
    }
}
