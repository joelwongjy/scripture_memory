package joel.scripturememory.ui.components

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import joel.scripturememory.R
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
    Column(Modifier.fillMaxSize().padding(0.dp)) {
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
            itemsIndexed(pack.verses, key = { _, verse -> verse.srsKey }) { index, verse ->
                Column(Modifier.readableColumn().groupedRow(index, pack.verses.size)) {
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
                    if (index < pack.verses.lastIndex) RowDivider()
                }
            }
        }
    }
}
