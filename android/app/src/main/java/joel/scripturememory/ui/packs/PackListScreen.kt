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
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.key
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.layout.positionInRoot
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.CustomAccessibilityAction
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.customActions
import androidx.compose.ui.semantics.heading
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
import joel.scripturememory.model.UserPackStore
import joel.scripturememory.model.VerseSearch
import joel.scripturememory.system.Analytics
import joel.scripturememory.R
import joel.scripturememory.system.HapticEngine
import joel.scripturememory.ui.components.AppMenu
import joel.scripturememory.ui.components.ChromeIconButton
import joel.scripturememory.ui.components.ChromeTextButton
import joel.scripturememory.ui.components.MenuAction
import joel.scripturememory.ui.components.CoverTransition
import joel.scripturememory.ui.components.LargeTitleList
import joel.scripturememory.ui.components.LocalCovers
import joel.scripturememory.ui.components.Text
import joel.scripturememory.ui.components.TrackScreen
import joel.scripturememory.ui.components.pressable
import joel.scripturememory.ui.pouch.PouchScreen
import joel.scripturememory.ui.theme.AppLayout
import joel.scripturememory.ui.theme.AppMotion
import joel.scripturememory.ui.theme.AppTheme
import joel.scripturememory.ui.theme.AppType
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import kotlin.math.floor
import kotlin.math.max

private val minimumTileWidth = 160.dp
private const val minimumColumns = 2
private const val listHeaderItems = 2

private class EditedPack(val packID: String?, val addsVerse: Boolean = false)

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
    var editing by remember { mutableStateOf<EditedPack?>(null) }
    var importing by remember { mutableStateOf(false) }
    var showsAddMenu by remember { mutableStateOf(false) }
    var menuPack by remember { mutableStateOf<String?>(null) }
    val tileFrames = remember { TileFrames() }
    val userPacks = UserPackStore.shared
    var knownPackIDs by remember { mutableStateOf(userPacks.userPacks.map { it.id }) }
    var createdPackID by remember { mutableStateOf<String?>(null) }
    val listState = rememberLazyListState()
    val scope = rememberCoroutineScope()

    fun revealNewPack() {
        val known = knownPackIDs.toSet()
        knownPackIDs = userPacks.userPacks.map { it.id }
        createdPackID = userPacks.userPacks.lastOrNull { it.id !in known }?.name
    }

    val packs = bibleVersion.packs
    val visiblePacks = packPrefs.visible(packs)
    val split = visiblePacks.indexOfFirst { it.isUserMade }
        .takeIf { it >= 0 && visiblePacks.drop(it).all { pack -> pack.isUserMade } }
    val tiles = remember(visiblePacks, favorites.keys) {
        listOfNotNull(favorites.pack(visiblePacks)) + visiblePacks.take(split ?: visiblePacks.size)
    }
    val ownTiles = remember(visiblePacks) { split?.let { visiblePacks.drop(it) }.orEmpty() }
    val currentPackName = learning.currentVerse?.packName

    TrackScreen(AnalyticsScreen.packs)
    LaunchedEffect(visiblePacks) { withContext(Dispatchers.Default) { VerseSearch.prewarm(visiblePacks) } }

    fun open(pack: Pack) {
        if (pack.verses.isEmpty()) {
            pack.userPackID?.let { editing = EditedPack(it, addsVerse = true) }
            return
        }
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

    @Composable
    fun PackRow(row: List<Pack>, columns: Int, isFirst: Boolean) {
        Row(
            Modifier
                .fillMaxWidth()
                .padding(horizontal = AppLayout.screenMargin)
                .padding(top = if (isFirst) 12.dp else 0.dp, bottom = AppLayout.spacing),
            horizontalArrangement = Arrangement.spacedBy(AppLayout.spacing),
        ) {
            row.forEach { pack ->
                Box(
                    Modifier
                        .weight(1f)
                        .onGloballyPositioned { tileFrames.byPack[pack.id] = Rect(it.positionInRoot(), it.size.toSize()) }
                        .graphicsLayer { alpha = if (openedPack == pack.id) 0f else 1f }
                        .clearAndSetSemantics {
                            contentDescription = if (pack.verses.size == 1) "${pack.name}, 1 card" else "${pack.name}, ${pack.verses.size} cards"
                            role = Role.Button
                            onClick {
                                open(pack)
                                true
                            }
                            pack.userPackID?.let { id ->
                                customActions = listOf(
                                    CustomAccessibilityAction("Add Verse") {
                                        editing = EditedPack(id, addsVerse = true)
                                        true
                                    },
                                    CustomAccessibilityAction("Edit Pack") {
                                        editing = EditedPack(id)
                                        true
                                    },
                                )
                            }
                        }
                        .pressable(
                            onLongClick = pack.userPackID?.let {
                                {
                                    HapticEngine.medium()
                                    menuPack = pack.id
                                }
                            },
                        ) { open(pack) },
                ) {
                    PackCover(pack, isCurrentPack = pack.name == currentPackName)
                    val id = pack.userPackID
                    if (menuPack == pack.id && id != null) {
                        AppMenu(
                            actions = listOf(
                                MenuAction("Add Verse", R.drawable.ic_plus) { editing = EditedPack(id, addsVerse = true) },
                                MenuAction("Edit Pack", R.drawable.ic_pencil) { editing = EditedPack(id) },
                            ),
                            onDismiss = { menuPack = null },
                        )
                    }
                }
            }
            repeat(columns - row.size) { Spacer(Modifier.weight(1f)) }
        }
    }

    BoxWithConstraints(Modifier.windowInsetsPadding(WindowInsets.safeDrawing.only(WindowInsetsSides.Horizontal))) {
        val columns = minimumColumns.coerceAtLeast(adaptiveColumns(maxWidth - AppLayout.screenMargin * 2, minimumTileWidth, AppLayout.spacing))
        val rows = remember(tiles, columns) { tiles.chunked(columns) }
        val ownRows = remember(ownTiles, columns) { ownTiles.chunked(columns) }
        LaunchedEffect(createdPackID, rows, ownRows) {
            val name = createdPackID ?: return@LaunchedEffect
            val row = rows.indexOfFirst { r -> r.any { it.id == name } }.takeIf { it >= 0 }
                ?: ownRows.indexOfFirst { r -> r.any { it.id == name } }.takeIf { it >= 0 }?.let { rows.size + 1 + it }
                ?: return@LaunchedEffect
            createdPackID = null
            val index = row + listHeaderItems
            scope.launch {
                val viewport = listState.layoutInfo.viewportSize.height
                val rowHeight = listState.layoutInfo.visibleItemsInfo.lastOrNull()?.size ?: 0
                listState.animateScrollToItem(index, -(viewport - rowHeight) / 2)
            }
        }
        LargeTitleList(
            title = "Packs",
            state = listState,
            verticalSpacing = 0.dp,
            actions = {
                ChromeTextButton(
                    "Edit",
                    Modifier.semantics { contentDescription = "Edit packs" },
                    onClick = { showOrganizer = true },
                )
                Box {
                    ChromeIconButton(R.drawable.ic_plus, "Add Pack", iconSize = 16.dp, onClick = { showsAddMenu = true })
                    if (showsAddMenu) {
                        AppMenu(
                            actions = listOf(
                                MenuAction("New Pack", R.drawable.ic_stack) { editing = EditedPack(null) },
                                MenuAction("Import from Anki", R.drawable.ic_download) { importing = true },
                            ),
                            onDismiss = { showsAddMenu = false },
                        )
                    }
                }
            },
        ) {
            items(rows.size, key = { rows[it].first().id }) { i -> PackRow(rows[i], columns, isFirst = i == 0) }
            if (ownRows.isNotEmpty()) {
                item(key = "yourPacks") {
                    Text(
                        "Your Packs",
                        Modifier
                            .fillMaxWidth()
                            .padding(horizontal = AppLayout.screenMargin)
                            .padding(top = if (rows.isEmpty()) 12.dp else AppLayout.spacing, bottom = AppLayout.spacing)
                            .semantics { heading() },
                        style = AppType.title3,
                        color = AppTheme.colors.label,
                    )
                }
                items(ownRows.size, key = { ownRows[it].first().id }) { i -> PackRow(ownRows[i], columns, isFirst = false) }
            }
        }
    }

    if (showOrganizer) {
        PackOrganizerSheet(allPacks = packs, onDismiss = { showOrganizer = false })
    }
    editing?.let { item ->
        key(item) {
            PackEditorSheet(item.packID, item.addsVerse, onDismiss = {
                editing = null
                revealNewPack()
            })
        }
    }
    if (importing) {
        AnkiImportSheet(onDismiss = {
            importing = false
            revealNewPack()
        })
    }
}
