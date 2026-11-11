package joel.scripturememory.ui

import android.content.Context
import android.net.Uri
import java.io.File
import androidx.activity.compose.BackHandler
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.asPaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.Stable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.key
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.saveable.rememberSaveableStateHolder
import androidx.compose.runtime.setValue
import androidx.compose.runtime.snapshotFlow
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.compose.LifecycleEventEffect
import joel.scripturememory.R
import joel.scripturememory.model.AnalyticsEvent
import joel.scripturememory.model.AnkiImport
import joel.scripturememory.model.AnkiImporter
import joel.scripturememory.model.AppDefaults
import joel.scripturememory.model.BibleVersion
import joel.scripturememory.model.LearningStore
import joel.scripturememory.model.NewCardCap
import joel.scripturememory.model.OnboardingStart
import joel.scripturememory.model.Pack
import joel.scripturememory.model.PackPreferencesStore
import joel.scripturememory.model.PackSource
import joel.scripturememory.model.SRSQueueBuilder
import joel.scripturememory.model.SRSStore
import joel.scripturememory.model.SessionKind
import joel.scripturememory.model.StreakStore
import joel.scripturememory.model.TestSession
import joel.scripturememory.model.TestSessionViewModel
import joel.scripturememory.model.VerseCatalog
import joel.scripturememory.model.WidgetDestination
import joel.scripturememory.model.read
import joel.scripturememory.system.Analytics
import joel.scripturememory.system.Background
import joel.scripturememory.system.DeepLink
import joel.scripturememory.system.NotificationManager
import joel.scripturememory.system.OpenedFile
import joel.scripturememory.ui.components.CoverHost
import joel.scripturememory.ui.components.CoverTransition
import joel.scripturememory.ui.components.Covers
import joel.scripturememory.ui.components.DismissOnBack
import joel.scripturememory.ui.components.LocalBottomBarPadding
import joel.scripturememory.ui.components.LocalCovers
import joel.scripturememory.ui.components.Navigator
import joel.scripturememory.ui.components.StackHost
import joel.scripturememory.ui.components.TabBar
import joel.scripturememory.ui.components.TabBarHeight
import joel.scripturememory.ui.components.TabItem
import joel.scripturememory.ui.home.HomeScreen
import joel.scripturememory.ui.onboarding.LearningSetupScreen
import joel.scripturememory.ui.packs.AnkiImportSheet
import joel.scripturememory.ui.packs.PackListScreen
import joel.scripturememory.ui.pouch.PouchScreen
import joel.scripturememory.ui.quiz.TestSetupScreen
import joel.scripturememory.ui.search.VerseSearchScreen
import joel.scripturememory.ui.settings.SettingsScreen
import joel.scripturememory.ui.study.DailyReviewScreen
import joel.scripturememory.ui.theme.AppTheme
import joel.scripturememory.widget.WidgetBridge
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.FlowPreview
import kotlinx.coroutines.channels.ReceiveChannel
import kotlinx.coroutines.flow.debounce
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

private const val hasOnboardedKey = "hasOnboardedLearning.v1"
private const val homeTab = 0
private const val searchTab = 4

private val tabs = listOf(
    TabItem("Home", R.drawable.ic_house, R.drawable.ic_house_fill),
    TabItem("Packs", R.drawable.ic_cards, R.drawable.ic_cards_fill),
    TabItem("Quiz", R.drawable.ic_check_circle, R.drawable.ic_check_circle_fill),
    TabItem("Settings", R.drawable.ic_gear, R.drawable.ic_gear_fill),
    TabItem("Search", R.drawable.ic_magnifying_glass, R.drawable.ic_magnifying_glass_bold),
)

@Stable
private class AppShell(val covers: Covers, private val selectTab: (Int) -> Unit) {

    private val defaults = AppDefaults.standard
    private var rootCover: String? = null
    private var waitingLink: DeepLink? = null

    val hasOnboarded: Boolean get() = defaults.getBool(hasOnboardedKey) ?: false

    private val bibleVersion: BibleVersion get() = BibleVersion.saved()
    private val visiblePacks: List<Pack> get() = PackPreferencesStore.shared.visible(bibleVersion.packs)

    private val hasRestoredProgress: Boolean
        get() = LearningStore.shared.learntKeys.isNotEmpty() || SRSStore.shared.states.isNotEmpty()

    fun startOnboardingIfNeeded() {
        if (hasOnboarded) return
        if (hasRestoredProgress) {
            Analytics.log(
                AnalyticsEvent.OnboardingFinished(OnboardingStart.restoredFromICloud, bibleVersion.rawValue),
            )
            defaults.putBool(hasOnboardedKey, true)
            return
        }
        val showsWelcome = SRSStore.shared.states.isEmpty()
        covers.present("onboarding", CoverTransition.SlideDownOnly) { dismiss ->
            LearningSetupScreen(
                isOnboarding = true,
                showsWelcome = showsWelcome,
                onComplete = {
                    defaults.putBool(hasOnboardedKey, true)
                    dismiss()
                    val link = waitingLink
                    waitingLink = null
                    if (link != null) handle(link) else openStartingVerse()
                },
            )
        }
    }

    fun handle(link: DeepLink) {
        if (covers.isPresenting("onboarding")) {
            waitingLink = link
            return
        }
        when (link.uri.host) {
            "read" -> {
                if (link.isExternal) Analytics.log(AnalyticsEvent.OpenedFromWidget(WidgetDestination.read))
                openRead(link.uri)
            }
            "review" -> {
                if (link.isExternal) Analytics.log(AnalyticsEvent.OpenedFromWidget(WidgetDestination.review))
                openReview()
            }
            "search" -> selectTab(searchTab)
        }
    }

    private fun present(key: String, content: @Composable (dismiss: () -> Unit) -> Unit) {
        if (covers.isPresenting(key)) return
        rootCover?.let(covers::dismiss)
        rootCover = key
        covers.present(key) { dismiss ->
            DismissOnBack(onBack = dismiss)
            content(dismiss)
        }
    }

    private fun openRead(uri: Uri) {
        val packName = uri.getQueryParameter("pack") ?: return
        val pack = visiblePacks.firstOrNull { it.name == packName } ?: return
        val book = uri.getQueryParameter("book")
        val reference = uri.getQueryParameter("ref")
        val index = pack.verses.indexOfFirst { it.book == book && it.reference == reference }
            .coerceAtLeast(0)
        Analytics.log(AnalyticsEvent.PackOpened(pack.name, PackSource.widget))
        present("read-${pack.id}-$index") { dismiss ->
            PouchScreen(pack, index, animatesPouch = false, onClosed = dismiss)
        }
    }

    private fun openStartingVerse() {
        val verse = LearningStore.shared.currentVerse ?: return
        val pack = visiblePacks.firstOrNull { p -> p.verses.any { it.srsKey == verse.srsKey } } ?: return
        val index = pack.verses.indexOfFirst { it.srsKey == verse.srsKey }
        Analytics.log(AnalyticsEvent.PackOpened(pack.name, PackSource.onboarding))
        present("read-${pack.id}-$index") { dismiss ->
            PouchScreen(pack, index, onClosed = dismiss)
        }
    }

    private fun openReview() {
        val active = SRSStore.shared.activePacks(visiblePacks)
        val session = TestSession.dailyReview(
            activePacks = active,
            newCap = NewCardCap.current(),
            dailyReviewCap = defaults.getInt(NewCardCap.dailyReviewCapKey) ?: NewCardCap.dailyReviewCapDefault,
        ) ?: return
        TestSessionViewModel.clearPersistedProgress(SessionKind.srs)
        present("review-${session.id}") { dismiss ->
            DailyReviewScreen(session, onFinished = dismiss)
        }
    }
}

@OptIn(FlowPreview::class)
@Composable
fun AppRoot(deepLinks: ReceiveChannel<DeepLink>, openedFiles: ReceiveChannel<OpenedFile>) {
    var selected by rememberSaveable { mutableIntStateOf(homeTab) }
    val shell = remember {
        AppShell(Covers()) { selected = it }.also { it.startOnboardingIfNeeded() }
    }
    val covers = shell.covers
    val navigators = remember { List(tabs.size) { Navigator() } }
    val holders = tabs.map { rememberSaveableStateHolder() }
    val navBar = WindowInsets.navigationBars.asPaddingValues().calculateBottomPadding()
    val hasOnboarded = shell.hasOnboarded
    val context = LocalContext.current
    var ankiFile by remember { mutableStateOf<File?>(null) }

    LaunchedEffect(hasOnboarded) {
        if (hasOnboarded) StreakStore.shared.recordToday()
        WidgetBridge.sync()
    }
    LaunchedEffect(Unit) {
        Background.launch { NotificationManager.refreshFromSettings() }
        launch {
            snapshotFlow {
                listOf(
                    LearningStore.shared.learntKeys,
                    LearningStore.shared.pinnedKey,
                    BibleVersion.saved(),
                    PackPreferencesStore.shared.order,
                    PackPreferencesStore.shared.hidden,
                    SRSStore.shared.states,
                    SRSStore.shared.inactivePackNames,
                    StreakStore.shared.days,
                    NewCardCap.current(),
                    AppDefaults.standard.getInt(NewCardCap.dailyReviewCapKey),
                    AppDefaults.standard.getBool(SRSQueueBuilder.NewCardPolicy.reviewsKnownKey),
                )
            }.debounce(300).collect { WidgetBridge.sync() }
        }
        launch { LearningStore.shared.featuredVerseDidChange.collect { WidgetBridge.sync() } }
        launch {
            for (opened in openedFiles) {
                withContext(Dispatchers.IO) { acceptedAnkiFile(context, opened) }?.let { ankiFile = it }
            }
        }
        for (link in deepLinks) shell.handle(link)
    }
    LifecycleEventEffect(Lifecycle.Event.ON_RESUME) {
        if (shell.hasOnboarded) StreakStore.shared.recordToday()
        WidgetBridge.sync()
        Background.launch { VerseCatalog.refreshIfNeeded() }
    }
    LifecycleEventEffect(Lifecycle.Event.ON_STOP) {
        WidgetBridge.sync()
        Background.launch { NotificationManager.refreshFromSettings() }
    }

    BackHandler(enabled = selected != homeTab && !covers.isPresenting && !navigators[selected].canPop) {
        selected = homeTab
    }

    CompositionLocalProvider(LocalCovers provides covers) {
        Box(Modifier.fillMaxSize().background(AppTheme.colors.background)) {
            CompositionLocalProvider(LocalBottomBarPadding provides TabBarHeight + navBar) {
                Box(
                    Modifier
                        .fillMaxSize()
                        .then(if (covers.isPresenting) Modifier.clearAndSetSemantics {} else Modifier),
                ) {
                    key(selected) {
                        StackHost(
                            navigators[selected],
                            backEnabled = !covers.isPresenting,
                            holder = holders[selected],
                        ) { TabRoot(selected) }
                    }
                    TabBar(
                        tabs,
                        selected,
                        onSelect = { index ->
                            if (index == selected) navigators[index].popToRootAnimated() else selected = index
                        },
                        modifier = Modifier.align(Alignment.BottomCenter),
                    )
                }
            }
            CompositionLocalProvider(LocalBottomBarPadding provides navBar) {
                CoverHost(covers)
            }
        }
        ankiFile?.let { file ->
            key(file) { AnkiImportSheet(file, onDismiss = { ankiFile = null }) }
        }
    }
}

private fun acceptedAnkiFile(context: Context, opened: OpenedFile): File? {
    val file = runCatching { OpenedFile.copyToCache(context, opened.uri, fallbackExtension = "apkg") }.getOrNull()
        ?: return null
    if (opened.isNamedAnki) return file
    val readable = runCatching {
        val plan = AnkiImporter.plan(AnkiImport.read(file))
        plan.decks.isNotEmpty() || plan.matches.isNotEmpty()
    }.getOrDefault(false)
    if (!readable) file.delete()
    return file.takeIf { readable }
}

@Composable
private fun TabRoot(index: Int) {
    when (index) {
        0 -> HomeScreen()
        1 -> PackListScreen()
        2 -> TestSetupScreen()
        3 -> SettingsScreen()
        else -> VerseSearchScreen()
    }
}
