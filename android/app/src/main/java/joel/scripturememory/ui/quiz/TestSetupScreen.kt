package joel.scripturememory.ui.quiz

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.WindowInsetsSides
import androidx.compose.foundation.layout.asPaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.ime
import androidx.compose.foundation.layout.only
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawing
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.lazy.LazyItemScope
import androidx.compose.foundation.lazy.LazyListScope
import androidx.compose.foundation.lazy.items
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.snapshots.Snapshot
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.max
import joel.scripturememory.model.AnalyticsScreen
import joel.scripturememory.model.AppDefaults
import joel.scripturememory.model.BibleVersion
import joel.scripturememory.model.Catalogue
import joel.scripturememory.model.FavoritesStore
import joel.scripturememory.model.LearningStore
import joel.scripturememory.model.Pack
import joel.scripturememory.model.PackPreferencesStore
import joel.scripturememory.model.SessionKind
import joel.scripturememory.model.TestSession
import joel.scripturememory.model.TestSessionViewModel
import joel.scripturememory.model.Verse
import joel.scripturememory.model.Wording
import joel.scripturememory.system.HapticEngine
import joel.scripturememory.ui.components.AlertAction
import joel.scripturememory.ui.components.AppAlert
import joel.scripturememory.ui.components.BottomActionBar
import joel.scripturememory.ui.components.ChromeTextButton
import joel.scripturememory.ui.components.ReadableList
import joel.scripturememory.ui.components.ListRow
import joel.scripturememory.ui.components.LocalBottomBarPadding
import joel.scripturememory.ui.components.LocalCovers
import joel.scripturememory.ui.components.PrimaryButton
import joel.scripturememory.ui.components.TrackScreen
import joel.scripturememory.ui.components.groupedRow
import joel.scripturememory.ui.components.readableColumn
import joel.scripturememory.ui.components.Divider
import joel.scripturememory.ui.study.TestSessionScreen
import joel.scripturememory.ui.theme.AppMotion
import joel.scripturememory.ui.theme.AppTheme
import joel.scripturememory.ui.theme.AppType

private const val savedSessionKey = "lastTestSessionVerseIds"
private const val quizCountKey = "reviewSetupQuizCount"
private val compactBarHeight = 480.dp

private sealed interface PackListItem {
    val key: String

    data class Header(val pack: Pack) : PackListItem {
        override val key get() = "pack_${pack.id}"
    }

    data class Row(val verse: Verse, val pack: Pack) : PackListItem {
        override val key get() = "verse_${pack.id}_${verse.id}"
    }
}

private fun seriesTitle(pack: Pack): String = when {
    pack.isUserMade -> "Your Packs"
    pack.name.startsWith("DEP") -> "DEP 242"
    pack.name.startsWith("TMS 180") -> "TMS 180"
    pack.name == "5 Assurances" || pack.name == "TMS 60" -> "Growing in Christ"
    else -> "More Packs"
}

private fun listFormatted(names: List<String>): String = when (names.size) {
    0 -> ""
    1 -> names[0]
    2 -> "${names[0]} and ${names[1]}"
    else -> names.dropLast(1).joinToString(", ") + ", and ${names.last()}"
}

private fun packDetail(pack: Pack, selected: Int, learning: LearningStore): String {
    if (selected > 0) return "$selected of ${pack.verses.size} selected"
    val learnt = pack.verses.count(learning::isLearnt)
    val count = Wording.verses(pack.verses.size)
    if (learnt == 0) return count
    return "$count · ${if (learnt == pack.verses.size) "all" else "$learnt"} learnt"
}

@Composable
fun TestSetupScreen() {
    val covers = LocalCovers.current
    val learning = LearningStore.shared
    val favorites = FavoritesStore.shared
    val packPrefs = PackPreferencesStore.shared
    val bibleVersion = BibleVersion.saved()
    val visiblePacks = packPrefs.visible(bibleVersion.packs)
    val catalogue = remember(visiblePacks) { Catalogue.verses(visiblePacks) }
    val packSeries = remember(visiblePacks) {
        val series = LinkedHashMap<String, MutableList<Pack>>()
        for (pack in visiblePacks) series.getOrPut(seriesTitle(pack)) { mutableListOf() }.add(pack)
        series.map { it.key to it.value.toList() }
    }

    var selectedVerseIds by remember { mutableStateOf(emptySet<Int>()) }
    var expandedPackIds by remember { mutableStateOf(emptySet<String>()) }
    val dragFrames = remember { DragSelectFrames() }
    var dragSelects by remember { mutableStateOf(true) }
    val dragVisited = remember { HashSet<Int>() }
    var quizCount by remember { mutableIntStateOf(15) }
    var savedSession by remember { mutableStateOf<TestSession?>(null) }
    var showOverwriteAlert by remember { mutableStateOf(false) }
    val entry = remember { QuizCountEntry() }
    var barHeight by remember { mutableIntStateOf(0) }

    val selectedCount = selectedVerseIds.size
    val clampedCount = quizCount.coerceAtMost(selectedCount).coerceAtLeast(1)

    fun clearSession() {
        savedSession = null
        AppDefaults.standard.remove(savedSessionKey)
    }

    fun present(session: TestSession) {
        covers.present("quiz-${session.id}") { _ ->
            TestSessionScreen(session, onSessionEnded = ::clearSession)
        }
    }

    fun dismissSavedSession() {
        clearSession()
        TestSessionViewModel.clearPersistedProgress(SessionKind.custom)
    }

    fun launchNewSession() {
        TestSessionViewModel.clearPersistedProgress(SessionKind.custom)
        val verses = bibleVersion.packs.flatMap { pack -> pack.verses.filter { it.id in selectedVerseIds } }
        val session = TestSession(verses.shuffled().take(clampedCount))
        AppDefaults.standard.putString(savedSessionKey, session.verses.joinToString(",") { it.id.toString() })
        savedSession = session
        present(session)
    }

    fun loadSavedSession() {
        if (savedSession != null) return
        val ids = AppDefaults.standard.getString(savedSessionKey)
            ?.split(",")?.mapNotNull(String::toIntOrNull).orEmpty()
        if (ids.isEmpty()) return
        val wanted = ids.toSet()
        val byId = HashMap<Int, Verse>()
        for (pack in bibleVersion.packs) {
            for (verse in pack.verses) if (verse.id in wanted) byId[verse.id] = verse
        }
        val ordered = ids.mapNotNull(byId::get)
        if (ordered.isNotEmpty()) savedSession = TestSession(ordered)
    }

    fun select(verses: List<Verse>) {
        selectedVerseIds = verses.map { it.id }.toSet()
    }

    fun versesUpTo(verse: Verse): List<Verse> {
        val i = catalogue.indexOfFirst { it.id == verse.id }
        return if (i < 0) emptyList() else catalogue.take(i + 1)
    }

    fun versesUpToCurrent(): List<Verse> {
        val current = learning.currentVerse ?: return catalogue
        val i = catalogue.indexOfFirst { it.srsKey == current.srsKey }
        return if (i < 0) emptyList() else catalogue.take(i + 1)
    }

    fun handleDragSelect(point: androidx.compose.ui.geometry.Offset, isFirst: Boolean) {
        val id = dragFrames.row(point) ?: return
        if (isFirst) {
            dragVisited.clear()
            dragSelects = id !in selectedVerseIds
        }
        if (!dragVisited.add(id)) return
        selectedVerseIds = if (dragSelects) selectedVerseIds + id else selectedVerseIds - id
        HapticEngine.light()
    }

    TrackScreen(AnalyticsScreen.quiz)
    LaunchedEffect(Unit) {
        AppDefaults.standard.getInt(quizCountKey)?.takeIf { it >= 1 }?.let { quizCount = it }
        loadSavedSession()
    }
    LaunchedEffect(selectedVerseIds) {
        if (selectedVerseIds.isNotEmpty()) quizCount = clampedCount
    }
    LaunchedEffect(quizCount) {
        AppDefaults.standard.putInt(quizCountKey, quizCount)
    }

    val density = LocalDensity.current
    val inset = LocalBottomBarPadding.current
    val barSpace = with(density) { barHeight.toDp() }

    BoxWithConstraints(
        Modifier
            .fillMaxSize()
            .windowInsetsPadding(WindowInsets.safeDrawing.only(WindowInsetsSides.Horizontal))
            .twoFingerDragSelect(::handleDragSelect) { dragVisited.clear() },
    ) {
        val compactBar = maxHeight < compactBarHeight
        CompositionLocalProvider(LocalBottomBarPadding provides inset + barSpace) {
            ReadableList(
                title = "Quiz",
                showsLargeTitle = true,
                verticalSpacing = 0.dp,
                actions = {
                    if (selectedVerseIds.isNotEmpty()) {
                        ChromeTextButton("Deselect All", tint = AppTheme.colors.accent) {
                            selectedVerseIds = emptySet()
                            HapticEngine.light()
                        }
                    }
                },
            ) {
                savedSession?.let { session ->
                    item(key = "inProgress") {
                        Column(Modifier.animateItem()) {
                            SectionHeader("In Progress")
                            val sessionIds = remember(session.id) { session.verses.map { it.id }.toSet() }
                            val packsText = remember(session.id, bibleVersion) {
                                listFormatted(
                                    bibleVersion.packs
                                        .filter { pack -> pack.verses.any { it.id in sessionIds } }
                                        .map { it.shortName },
                                )
                            }
                            val presenting = covers.isPresenting
                            val done = remember(session.id, presenting) {
                                Snapshot.withoutReadObservation {
                                    TestSessionViewModel.savedCompletedCount(SessionKind.custom, session.verses)
                                }
                            }
                            Box(Modifier.groupedRow(0, 1)) {
                                ResumeRow(
                                    done = done,
                                    total = session.verses.size,
                                    packsText = packsText,
                                    onResume = { present(session) },
                                    onEnd = ::dismissSavedSession,
                                )
                            }
                        }
                    }
                }

                item(key = "quickPick") {
                    Column(Modifier.animateItem()) {
                        SectionHeader("Quick Pick")
                        val upToCurrent = versesUpToCurrent()
                        val starred = favorites.verses(visiblePacks)
                        val hasBoth = upToCurrent.isNotEmpty() && starred.isNotEmpty()
                        if (upToCurrent.isNotEmpty()) {
                            Box(Modifier.groupedRow(0, if (hasBoth) 2 else 1)) {
                                ListRow(
                                    title = "Up to current verse",
                                    titleColor = AppTheme.colors.accent,
                                    value = learning.currentVerse?.let { "${it.book} ${it.reference}" }
                                        ?: Wording.verses(upToCurrent.size),
                                    onClick = {
                                        select(upToCurrent)
                                        HapticEngine.light()
                                    },
                                )
                            }
                        }
                        if (starred.isNotEmpty()) {
                            Column(Modifier.groupedRow(if (hasBoth) 1 else 0, if (hasBoth) 2 else 1)) {
                                if (hasBoth) Divider(Modifier.padding(start = 16.dp, end = 16.dp))
                                ListRow(
                                    title = "Favourites",
                                    titleColor = AppTheme.colors.accent,
                                    value = "${starred.size}",
                                    onClick = {
                                        select(starred)
                                        HapticEngine.light()
                                    },
                                )
                            }
                        }
                    }
                }

                packSeries.forEach { (title, packs) ->
                    item(key = "series_$title") { SectionHeader(title, Modifier.animateItem()) }
                    val rows = packs.flatMap { pack ->
                        buildList {
                            add(PackListItem.Header(pack))
                            if (pack.id in expandedPackIds) pack.verses.forEach { add(PackListItem.Row(it, pack)) }
                        }
                    }
                    items(rows.size, key = { rows[it].key }) { index ->
                        val last = index == rows.size - 1
                        Box(Modifier.animateItem().groupedRow(index, rows.size)) {
                            when (val row = rows[index]) {
                                is PackListItem.Header -> {
                                    val pack = row.pack
                                    val ids = remember(pack) { pack.verses.map { it.id }.toSet() }
                                    val selectedInPack = ids.count { it in selectedVerseIds }
                                    val allSelected = selectedInPack == pack.verses.size && pack.verses.isNotEmpty()
                                    PackHeaderRow(
                                        pack = pack,
                                        detail = packDetail(pack, selectedInPack, learning),
                                        allSelected = allSelected,
                                        someSelected = selectedInPack > 0,
                                        isExpanded = pack.id in expandedPackIds,
                                        showsDivider = !last,
                                        onToggleSelection = {
                                            selectedVerseIds = if (allSelected) selectedVerseIds - ids else selectedVerseIds + ids
                                            HapticEngine.light()
                                        },
                                        onToggleExpanded = {
                                            expandedPackIds = if (pack.id in expandedPackIds) {
                                                expandedPackIds - pack.id
                                            } else {
                                                expandedPackIds + pack.id
                                            }
                                        },
                                    )
                                }
                                is PackListItem.Row -> {
                                    val verse = row.verse
                                    val isSelected = verse.id in selectedVerseIds
                                    VerseSelectRow(
                                        verse = verse,
                                        tint = row.pack.tint,
                                        isSelected = isSelected,
                                        showsDivider = !last,
                                        frames = dragFrames,
                                        onToggle = {
                                            selectedVerseIds = if (isSelected) selectedVerseIds - verse.id else selectedVerseIds + verse.id
                                            HapticEngine.light()
                                        },
                                        onSelectUpTo = {
                                            select(versesUpTo(verse))
                                            HapticEngine.light()
                                        },
                                    )
                                }
                            }
                        }
                    }
                }
            }
        }

        val ime = WindowInsets.ime.asPaddingValues().calculateBottomPadding()
        AnimatedVisibility(
            visible = selectedVerseIds.isNotEmpty(),
            modifier = Modifier
                .align(Alignment.BottomCenter)
                .padding(bottom = max(ime, inset)),
            enter = slideInVertically(AppMotion.content()) { it } + fadeIn(AppMotion.content()),
            exit = slideOutVertically(AppMotion.content()) { it } + fadeOut(AppMotion.content()),
        ) {
            BottomActionBar(
                Modifier
                    .onSizeChanged { barHeight = it.height }
                    .background(AppTheme.colors.background),
            ) {
                Column(Modifier.readableColumn(), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    val picker = @Composable {
                        QuizCountPicker(
                            count = quizCount,
                            maximum = selectedCount,
                            onCountChange = { quizCount = it },
                            entry = entry,
                        )
                    }
                    val start = {
                        if (savedSession != null) showOverwriteAlert = true else launchNewSession()
                    }
                    if (compactBar) {
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(16.dp),
                        ) {
                            Box(Modifier.weight(1f)) { picker() }
                            PrimaryButton("Start", Modifier.weight(1f), onClick = start)
                        }
                    } else {
                        picker()
                        PrimaryButton("Start", onClick = start)
                    }
                    QuizCountKeyboardBar(selectedCount, entry)
                }
            }
        }
    }

    LaunchedEffect(selectedVerseIds.isEmpty()) {
        if (selectedVerseIds.isEmpty()) barHeight = 0
    }

    if (showOverwriteAlert) {
        AppAlert(
            title = "Existing Session",
            message = "You have an unfinished session. Starting a new one will overwrite it.",
            actions = listOf(
                AlertAction("Keep Session", isCancel = true),
                AlertAction("Start New", isDestructive = true, onClick = ::launchNewSession),
            ),
            onDismiss = { showOverwriteAlert = false },
        )
    }
}
