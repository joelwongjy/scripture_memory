package joel.scripturememory.ui.packs

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.only
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawing
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.layout.WindowInsetsSides
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.layout.positionInRoot
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.onClick
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.toSize
import joel.scripturememory.model.AnalyticsEvent
import joel.scripturememory.model.AnalyticsScreen
import joel.scripturememory.model.BibleVersion
import joel.scripturememory.model.FavoritesStore
import joel.scripturememory.model.LearningStore
import joel.scripturememory.model.Pack
import joel.scripturememory.model.PackPositions
import joel.scripturememory.model.PackPreferencesStore
import joel.scripturememory.model.PackSource
import joel.scripturememory.model.VerseSearch
import joel.scripturememory.system.Analytics
import joel.scripturememory.ui.components.ChromeTextButton
import joel.scripturememory.ui.components.CoverTransition
import joel.scripturememory.ui.components.LargeTitleList
import joel.scripturememory.ui.components.LocalCovers
import joel.scripturememory.ui.components.TrackScreen
import joel.scripturememory.ui.components.pressable
import joel.scripturememory.ui.pouch.PouchScreen
import joel.scripturememory.ui.theme.AppLayout
import joel.scripturememory.ui.theme.AppMotion
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlin.math.floor
import kotlin.math.max

private val minimumTileWidth = 160.dp

private class TileFrames {
    val byPack = HashMap<String, Rect>()
}

internal fun adaptiveColumns(width: Dp, minimum: Dp, spacing: Dp): Int =
    max(1, floor((width + spacing) / (minimum + spacing)).toInt())

@Composable
fun PackListScreen() {
    val bibleVersion = BibleVersion.saved()
    val packPrefs = PackPreferencesStore.shared
    val learning = LearningStore.shared
    val favorites = FavoritesStore.shared
    val covers = LocalCovers.current

    var openedPack by remember { mutableStateOf<String?>(null) }
    var showOrganizer by remember { mutableStateOf(false) }
    val tileFrames = remember { TileFrames() }

    val packs = bibleVersion.packs
    val visiblePacks = packPrefs.visible(packs)
    val tiles = remember(visiblePacks, favorites.keys) {
        listOfNotNull(favorites.pack(visiblePacks)) + visiblePacks
    }
    val currentPackName = learning.currentVerse?.packName

    TrackScreen(AnalyticsScreen.packs)
    LaunchedEffect(visiblePacks) { withContext(Dispatchers.Default) { VerseSearch.prewarm(visiblePacks) } }

    fun open(pack: Pack) {
        if (pack.verses.isEmpty()) return
        val index = PackPositions.startIndex(pack, learning.currentKey)
        Analytics.log(AnalyticsEvent.PackOpened(pack.name, PackSource.shelf))
        val origin = tileFrames.byPack[pack.id]
        if (AppMotion.reduceMotion || origin == null) {
            covers.present("pack-${pack.id}-$index") { dismiss ->
                PouchScreen(pack, index, onClosed = dismiss)
            }
            return
        }
        openedPack = pack.id
        covers.present("pack-${pack.id}-$index", CoverTransition.None, background = false) { dismiss ->
            PouchScreen(
                pack,
                index,
                shelf = { tileFrames.byPack[pack.id] ?: origin },
                onClosed = {
                    openedPack = null
                    dismiss()
                },
            )
        }
    }

    BoxWithConstraints(Modifier.windowInsetsPadding(WindowInsets.safeDrawing.only(WindowInsetsSides.Horizontal))) {
        val columns = adaptiveColumns(maxWidth - AppLayout.screenMargin * 2, minimumTileWidth, AppLayout.spacing)
        val rows = remember(tiles, columns) { tiles.chunked(columns) }
        LargeTitleList(
            title = "Packs",
            verticalSpacing = 0.dp,
            actions = {
                ChromeTextButton(
                    "Edit",
                    Modifier.semantics { contentDescription = "Edit packs" },
                    onClick = { showOrganizer = true },
                )
            },
        ) {
            items(rows.size, key = { rows[it].first().id }) { i ->
                Row(
                    Modifier
                        .fillMaxWidth()
                        .padding(horizontal = AppLayout.screenMargin)
                        .padding(top = if (i == 0) 12.dp else 0.dp, bottom = AppLayout.spacing),
                    horizontalArrangement = Arrangement.spacedBy(AppLayout.spacing),
                ) {
                    rows[i].forEach { pack ->
                        Box(
                            Modifier
                                .weight(1f)
                                .onGloballyPositioned { tileFrames.byPack[pack.id] = Rect(it.positionInRoot(), it.size.toSize()) }
                                .graphicsLayer { alpha = if (openedPack == pack.id) 0f else 1f }
                                .clearAndSetSemantics {
                                    contentDescription = "${pack.name}, ${pack.verses.size} cards"
                                    role = Role.Button
                                    onClick {
                                        open(pack)
                                        true
                                    }
                                }
                                .pressable { open(pack) },
                        ) {
                            PackCover(pack, isCurrentPack = pack.name == currentPackName)
                        }
                    }
                    repeat(columns - rows[i].size) { Spacer(Modifier.weight(1f)) }
                }
            }
        }
    }

    if (showOrganizer) {
        PackOrganizerSheet(allPacks = packs, onDismiss = { showOrganizer = false })
    }
}
