package joel.scripturememory.ui.home

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import joel.scripturememory.R
import joel.scripturememory.model.AnalyticsScreen
import joel.scripturememory.model.Pack
import joel.scripturememory.model.Verse
import joel.scripturememory.system.HapticEngine
import joel.scripturememory.ui.components.AppSheet
import joel.scripturememory.ui.components.GroupedSection
import joel.scripturememory.ui.components.Icon
import joel.scripturememory.ui.components.ListRow
import joel.scripturememory.ui.components.LocalBottomBarPadding
import joel.scripturememory.ui.components.Navigator
import joel.scripturememory.ui.components.PackVerseMarker
import joel.scripturememory.ui.components.PackVersePicker
import joel.scripturememory.ui.components.SheetHeader
import joel.scripturememory.ui.components.StackHost
import joel.scripturememory.ui.components.TextButton
import joel.scripturememory.ui.components.TrackScreen
import joel.scripturememory.ui.theme.AppLayout
import joel.scripturememory.ui.theme.AppTheme

@Composable
fun PinVersePicker(
    packs: List<Pack>,
    pinnedKey: String?,
    onPick: (Verse) -> Unit,
    onUnpin: () -> Unit,
    onDismiss: () -> Unit,
) {
    TrackScreen(AnalyticsScreen.pinPicker)
    val navigator = remember { Navigator() }
    val pinned = pinnedKey?.let { key -> packs.asSequence().flatMap { it.verses }.firstOrNull { it.srsKey == key } }
    AppSheet(onDismiss = onDismiss, fullHeight = true) { sheet ->
        CompositionLocalProvider(LocalBottomBarPadding provides 0.dp) {
            StackHost(navigator, Modifier.weight(1f)) {
                Column(Modifier.fillMaxSize()) {
                    SheetHeader(
                        "Pin a Verse",
                        leading = { TextButton("Cancel", onClick = sheet.dismiss) },
                    )
                    LazyColumn(
                        Modifier.weight(1f).fillMaxWidth(),
                        contentPadding = PaddingValues(
                            start = AppLayout.screenMargin,
                            end = AppLayout.screenMargin,
                            top = 8.dp,
                            bottom = 24.dp,
                        ),
                        verticalArrangement = Arrangement.spacedBy(AppLayout.spacing),
                    ) {
                        if (pinned != null) {
                            item(key = "unpin") {
                                GroupedSection {
                                    val accent = AppTheme.colors.accent
                                    ListRow(
                                        "Unpin ${pinned.book} ${pinned.reference}",
                                        titleColor = accent,
                                        leading = { Icon(R.drawable.ic_push_pin_slash, size = 20.dp, tint = accent) },
                                        onClick = {
                                            onUnpin()
                                            HapticEngine.light()
                                            sheet.dismiss()
                                        },
                                    )
                                }
                            }
                        }
                        item(key = "packs") {
                            PackVersePicker(
                                packs = packs,
                                selectedKey = pinnedKey,
                                marker = PackVerseMarker.Pin,
                                footer = "Pick a verse to feature on your Home screen and widget. " +
                                    "This doesn't change your learning progress.",
                            ) { verse ->
                                onPick(verse)
                                sheet.dismiss()
                            }
                        }
                    }
                }
            }
        }
    }
}
