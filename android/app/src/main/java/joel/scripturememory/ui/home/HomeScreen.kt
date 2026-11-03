package joel.scripturememory.ui.home

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.onClick
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import joel.scripturememory.R
import joel.scripturememory.model.AnalyticsEvent
import joel.scripturememory.model.AnalyticsScreen
import joel.scripturememory.model.BibleVersion
import joel.scripturememory.model.Catalogue
import joel.scripturememory.model.LearningStore
import joel.scripturememory.model.Pack
import joel.scripturememory.model.PackListLayout
import joel.scripturememory.model.PackPreferencesStore
import joel.scripturememory.model.PackSource
import joel.scripturememory.model.SRSStore
import joel.scripturememory.model.TestSession
import joel.scripturememory.model.Verse
import joel.scripturememory.system.Analytics
import joel.scripturememory.ui.components.Covers
import joel.scripturememory.ui.components.Icon
import joel.scripturememory.ui.components.LargeTitleColumn
import joel.scripturememory.ui.components.LocalCovers
import joel.scripturememory.ui.components.LocalNavigator
import joel.scripturememory.ui.components.Text
import joel.scripturememory.ui.components.TrackScreen
import joel.scripturememory.ui.components.dimOnPress
import joel.scripturememory.ui.pouch.PouchScreen
import joel.scripturememory.ui.study.DailyReviewScreen
import joel.scripturememory.ui.theme.AppLayout
import joel.scripturememory.ui.theme.AppTheme
import joel.scripturememory.ui.theme.AppType

private fun spot(packs: List<Pack>, verse: Verse, isPinned: Boolean): LearningSpot? {
    val pack = packs.firstOrNull { it.name == verse.packName } ?: return null
    val index = pack.verses.indexOfFirst { it.srsKey == verse.srsKey }
    if (index < 0) return null
    return LearningSpot(verse, pack, index, isPinned)
}

private fun presentReview(covers: Covers, session: TestSession) {
    covers.present("review-${session.id}") { dismiss -> DailyReviewScreen(session, onFinished = dismiss) }
}

private fun openLearning(covers: Covers, spot: LearningSpot) {
    Analytics.log(AnalyticsEvent.PackOpened(spot.pack.name, PackSource.homeCard))
    covers.present("pack-${spot.pack.id}-${spot.indexInPack}") { dismiss ->
        PouchScreen(spot.pack, spot.indexInPack, onClosed = dismiss)
    }
}

@Composable
fun HomeScreen() {
    TrackScreen(AnalyticsScreen.home)
    val navigator = LocalNavigator.current
    val covers = LocalCovers.current
    val store = SRSStore.shared
    val learning = LearningStore.shared
    val packs = PackPreferencesStore.shared.visible(BibleVersion.saved().packs)
    val activePacks = store.activePacks(packs)
    val ordered = Catalogue.verses(packs)
    var showsPinPicker by rememberSaveable { mutableStateOf(false) }

    val featured = learning.displayed(ordered)?.let { spot(packs, it.verse, it.isPinned) }
    val current = learning.current(ordered)?.let { spot(packs, it.verse, false) }

    val dailyReview: @Composable (Modifier) -> Unit = { modifier ->
        Column(modifier.padding(top = 8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Row(Modifier.fillMaxWidth().padding(horizontal = 20.dp)) {
                Text(
                    "Daily Review",
                    Modifier.weight(1f).alignByBaseline().semantics { heading() },
                    style = AppType.title3.copy(fontWeight = FontWeight.Bold),
                    color = AppTheme.colors.label,
                    maxLines = 2,
                )
                PacksReviewLink(
                    active = activePacks.size,
                    total = packs.size,
                    modifier = Modifier.alignByBaseline(),
                ) { navigator.push("packsReview") { PacksReviewScreen() } }
            }
            DailyReviewCard(activePacks) { presentReview(covers, it) }
        }
    }
    val learningSection: @Composable (Modifier) -> Unit = { modifier ->
        LearningSection(
            featured = featured,
            cursor = current,
            hasVerses = ordered.isNotEmpty(),
            onOpen = { spot -> openLearning(covers, spot) },
            onChangePin = { showsPinPicker = true },
            modifier = modifier,
        )
    }

    BoxWithConstraints(Modifier.fillMaxSize()) {
        val contentWidth = maxWidth.value - 2 * AppLayout.screenMargin.value
        val isSideBySide = PackListLayout.homeIsSideBySide(contentWidth, maxHeight.value)
        LargeTitleColumn(
            "Home",
            maxContentWidth = if (isSideBySide) Dp.Infinity else AppLayout.readableWidth,
        ) {
            HomeStreakCard { navigator.push("streak") { StreakScreen() } }
            if (isSideBySide) {
                Row(
                    Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(AppLayout.spacing),
                ) {
                    dailyReview(Modifier.weight(1f))
                    learningSection(Modifier.weight(1f))
                }
            } else {
                dailyReview(Modifier)
                learningSection(Modifier)
            }
        }
    }

    if (showsPinPicker) {
        PinVersePicker(
            packs = packs,
            pinnedKey = learning.pinnedKey,
            onPick = learning::pin,
            onUnpin = learning::unpin,
            onDismiss = { showsPinPicker = false },
        )
    }
}

@Composable
private fun LearningSection(
    featured: LearningSpot?,
    cursor: LearningSpot?,
    hasVerses: Boolean,
    onOpen: (LearningSpot) -> Unit,
    onChangePin: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val learning = LearningStore.shared
    Column(
        modifier.fillMaxWidth().padding(top = 8.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(AppLayout.spacing),
    ) {
        if (featured != null) {
            ContinueLearningCard(
                spot = featured,
                onOpen = { onOpen(featured) },
                onChangePin = onChangePin,
                onUnpin = learning::unpin,
            )
            if (featured.isPinned && !learning.isCurrent(featured.verse) && cursor != null) {
                GoToCurrentVerseCard(cursor.verse) { onOpen(cursor) }
            }
        } else if (hasVerses) {
            AllLearntCard()
        }
    }
}

@Composable
private fun PacksReviewLink(active: Int, total: Int, modifier: Modifier = Modifier, onClick: () -> Unit) {
    val colors = AppTheme.colors
    val label = if (active == total) "All $total packs" else "$active of $total packs"
    Row(
        modifier
            .verticalOverhang(12.dp)
            .semantics(mergeDescendants = true) { contentDescription = "Packs in review, $label" }
            .dimOnPress(onClick = onClick)
            .padding(vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        Text(label, style = AppType.callout, color = colors.accent, maxLines = 1)
        Icon(R.drawable.ic_caret_right, size = 12.dp, tint = colors.accent)
    }
}
