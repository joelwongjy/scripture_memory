package joel.scripturememory.ui.pouch

import android.window.BackEvent
import androidx.activity.compose.BackHandler
import androidx.activity.compose.PredictiveBackHandler
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.foundation.interaction.DragInteraction
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.asPaddingValues
import androidx.compose.foundation.layout.calculateEndPadding
import androidx.compose.foundation.layout.calculateStartPadding
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.requiredSize
import androidx.compose.foundation.layout.safeDrawing
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyListState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.TextAutoSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.SideEffect
import androidx.compose.runtime.derivedStateOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.runtime.snapshotFlow
import androidx.compose.runtime.withFrameNanos
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.clipToBounds
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.unit.toSize
import androidx.compose.ui.graphics.BlurEffect
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.CompositingStrategy
import androidx.compose.ui.graphics.TileMode
import androidx.compose.ui.graphics.TransformOrigin
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.pointer.PointerEventPass
import androidx.compose.ui.input.pointer.PointerInputScope
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.input.pointer.util.VelocityTracker
import androidx.compose.ui.layout.Layout
import androidx.compose.ui.layout.LayoutCoordinates
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.layout.onPlaced
import androidx.compose.ui.layout.positionInRoot
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.semantics.CustomAccessibilityAction
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.customActions
import androidx.compose.ui.semantics.onClick
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Constraints
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.IntSize
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.zIndex
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.compose.LifecycleEventEffect
import joel.scripturememory.R
import joel.scripturememory.model.AnalyticsEvent
import joel.scripturememory.model.AnalyticsScreen
import joel.scripturememory.model.AppDefaults
import joel.scripturememory.model.BibleVersion
import joel.scripturememory.ui.study.CapsuleShape
import joel.scripturememory.model.FavoritesStore
import joel.scripturememory.model.LearningStore
import joel.scripturememory.model.Pack
import joel.scripturememory.model.PackCloseMethod
import joel.scripturememory.model.PackListLayout
import joel.scripturememory.model.PackPositions
import joel.scripturememory.model.TestSession
import joel.scripturememory.model.Verse
import joel.scripturememory.model.VerseActionSource
import joel.scripturememory.system.Analytics
import joel.scripturememory.system.HapticEngine
import joel.scripturememory.system.TiltMonitor
import joel.scripturememory.ui.components.AppMenu
import joel.scripturememory.ui.components.ChromeIconButton
import joel.scripturememory.ui.components.ChromeTextButton
import joel.scripturememory.ui.components.FavoriteStarButton
import joel.scripturememory.ui.components.Icon
import joel.scripturememory.ui.components.JumpToCurrentButton
import joel.scripturememory.ui.components.LocalCovers
import joel.scripturememory.ui.components.MenuAction
import joel.scripturememory.ui.components.Text
import joel.scripturememory.ui.components.TrackScreen
import joel.scripturememory.ui.components.UndoToastHost
import joel.scripturememory.ui.components.UndoToastState
import joel.scripturememory.ui.components.VerseFastScrollOverlay
import joel.scripturememory.ui.components.pressable
import joel.scripturememory.ui.packs.PackCover
import joel.scripturememory.ui.packs.seriesCode
import joel.scripturememory.ui.packs.shortName
import joel.scripturememory.ui.study.TestSessionScreen
import joel.scripturememory.ui.theme.AppLayout
import joel.scripturememory.ui.theme.AppMotion
import joel.scripturememory.ui.theme.AppTheme
import joel.scripturememory.ui.theme.AppType
import joel.scripturememory.ui.theme.PouchInk
import kotlin.math.abs
import kotlin.math.ceil
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.launch

private const val jumpLabelShownKey = "pouch.jumpLabelShown.v1"
private val swipeSlop = 12.dp
private const val swipeFollow = 0.6f
private const val swipeCloseDistance = 80f
private const val swipeCloseFlick = 220f
private const val flickSeconds = 0.5f
private const val backTravel = 0.3f
private val completeShape = RoundedCornerShape(percent = 50)

@Composable
fun PouchScreen(
    pack: Pack,
    startIndex: Int,
    shelf: (() -> Rect)? = null,
    animatesPouch: Boolean = true,
    onClosed: () -> Unit,
) {
    val bibleVersion = BibleVersion.saved()
    val hasVersionChoice = pack.name in BibleVersion.niv11PackNames
    val verses = if (hasVersionChoice) {
        (bibleVersion.packs.firstOrNull { it.name == pack.name } ?: pack).verses
    } else {
        pack.verses
    }
    val colors = AppTheme.colors
    val scope = rememberCoroutineScope()
    val covers = LocalCovers.current
    val context = LocalContext.current
    val layoutDirection = LocalLayoutDirection.current
    val density = LocalDensity.current
    val closed by rememberUpdatedState(onClosed)
    val tilt = remember { TiltMonitor(context) }
    val learning = LearningStore.shared

    val c = remember {
        PouchController(
            verses = verses,
            start = min(max(startIndex, 0), max(verses.size - 1, 0)),
            reduce = AppMotion.reduceMotion || !animatesPouch,
            hasShelf = shelf != null,
            animatesPouch = animatesPouch,
            scope = scope,
        ).also { it.onClosed = { closed() } }
    }
    SideEffect { c.verses = verses }
    var undoToast by remember { mutableStateOf<UndoToastState?>(null) }
    var practiceOpen by remember { mutableStateOf(false) }
    var sceneOrigin by remember { mutableStateOf(Offset.Zero) }
    var screenOrigin by remember { mutableStateOf(Offset.Zero) }
    var screenSize by remember { mutableStateOf(IntSize.Zero) }

    var lastPractised by remember { mutableStateOf<Verse?>(null) }

    fun returnToPractisedCard() {
        practiceOpen = false
        val verse = lastPractised ?: return
        lastPractised = null
        val i = verses.indexOfFirst { it.srsKey == verse.srsKey }
        if (i < 0) return
        c.listScrolled = false
        c.index = i
        c.scrollTo(i, AppMotion.movement())
    }

    fun startPractice(i: Int) {
        val session = TestSession.practice(verses, i) ?: return
        practiceOpen = true
        covers.present("practice-${session.id}") { dismiss ->
            TestSessionScreen(
                session,
                onSessionEnded = {
                    returnToPractisedCard()
                    dismiss()
                },
                onClose = {
                    returnToPractisedCard()
                    dismiss()
                },
                onCardShown = { lastPractised = it },
            )
        }
    }

    fun practiseCard(verse: Verse) {
        val session = TestSession.practice(verse)
        practiceOpen = true
        covers.present("practice-${session.id}") { dismiss ->
            TestSessionScreen(
                session,
                onSessionEnded = {
                    practiceOpen = false
                    dismiss()
                },
                onClose = {
                    practiceOpen = false
                    dismiss()
                },
            )
        }
    }

    fun chooseVersion(version: BibleVersion) {
        if (version == bibleVersion) return
        c.dropLiftedCard()
        AppDefaults.standard.putString(BibleVersion.storageKey, version.rawValue)
        Analytics.log(AnalyticsEvent.SettingChanged("bibleVersion", version.rawValue))
    }

    fun markComplete(verse: Verse, source: VerseActionSource) {
        learning.markLearnt(verse)
        Analytics.log(AnalyticsEvent.LearntChanged(true, source))
        HapticEngine.success()
        undoToast = UndoToastState.markedComplete(verse, learning)
    }

    TrackScreen(AnalyticsScreen.pack)
    LifecycleEventEffect(Lifecycle.Event.ON_RESUME) { c.openTime.resume() }
    LifecycleEventEffect(Lifecycle.Event.ON_PAUSE) { c.openTime.pause() }
    LaunchedEffect(Unit) { c.appeared() }
    LaunchedEffect(c.fanned) { if (c.fanned) tilt.stop() else tilt.start() }
    DisposableEffect(Unit) {
        onDispose {
            tilt.stop()
            verses.getOrNull(c.index)?.let { PackPositions.save(it, pack.name) }
        }
    }

    val insets: PaddingValues = WindowInsets.safeDrawing.asPaddingValues()
    val below = insets.calculateBottomPadding()

    BackHandler(enabled = c.lifted != null) { c.putCardBack() }
    PredictiveBackHandler(enabled = !c.closing && !practiceOpen && c.lifted == null) { progress ->
        val travel = with(density) { maxOf(context.resources.displayMetrics.widthPixels.toFloat(), 1f) } * backTravel
        try {
            progress.collect { event ->
                val sign = if (event.swipeEdge == BackEvent.EDGE_RIGHT) -1f else 1f
                c.swipeOffset.snapTo(sign * event.progress * travel)
            }
            c.close(PackCloseMethod.edgeSwipe)
        } catch (cancelled: CancellationException) {
            scope.launch { c.swipeOffset.animateTo(0f, AppMotion.control()) }
            throw cancelled
        }
    }

    val blurPerLift = with(density) { 14.dp.toPx() }
    Box(Modifier.fillMaxSize().onPlaced { screenSize = it.size; screenOrigin = it.positionInRoot() }) {
        Box(
            Modifier
                .matchParentSize()
                .graphicsLayer { alpha = 1f - c.flight.value }
                .background(colors.background),
        )
        Column(
            Modifier
                .fillMaxSize()
                .graphicsLayer {
                    val radius = blurPerLift * c.liftAmount.value
                    renderEffect = if (radius > 0.5f) BlurEffect(radius, radius, TileMode.Decal) else null
                }
                .then(if (c.lifted != null) Modifier.clearAndSetSemantics { } else Modifier)
                .padding(
                    start = insets.calculateStartPadding(layoutDirection),
                    end = insets.calculateEndPadding(layoutDirection),
                    top = insets.calculateTopPadding(),
                ),
        ) {
            PouchTopBar(
                pack,
                c,
                version = bibleVersion.takeIf { hasVersionChoice },
                onVersion = ::chooseVersion,
                onPractice = { startPractice(c.index) },
            )
            BoxWithConstraints(
                Modifier
                    .weight(1f)
                    .fillMaxWidth()
                    .zIndex(-1f)
                    .onGloballyPositioned { sceneOrigin = it.positionInRoot() },
            ) {
                val sceneHeight = maxHeight - below
                val layout = PackListLayout(
                    maxWidth.value - 2 * AppLayout.screenMargin.value,
                    AppLayout.spacing.value,
                )
                val geometry = with(density) {
                    val w = layout.cardWidth.dp.toPx()
                    val h = (w / AppLayout.cardAspect).roundToInt()
                    ListGeometry(
                        sceneWidth = maxWidth.roundToPx(),
                        cardWidth = w.roundToInt(),
                        cardHeight = h,
                        spacing = AppLayout.spacing.roundToPx(),
                        below = below.roundToPx(),
                        viewport = maxHeight.roundToPx(),
                        count = verses.size,
                        layout = layout,
                        density = this.density,
                    )
                }
                c.geometry = geometry
                SideEffect { c.columns = layout.columns }
                LaunchedEffect(geometry.cardWidth) { c.dropLiftedCard() }
                val cardWidthDp = with(density) { geometry.cardWidth.toDp() }
                val cardHeightDp = with(density) { geometry.cardHeight.toDp() }

                if (c.fanned) {
                    FannedList(
                        c = c,
                        pack = pack,
                        geometry = geometry,
                        width = cardWidthDp,
                        height = cardHeightDp,
                        below = below,
                        screenOrigin = { screenOrigin },
                        onPractice = ::practiseCard,
                        onComplete = ::markComplete,
                    )
                }
                if (!c.fanned || !c.listSettled) {
                    PouchAndDeck(
                        c = c,
                        pack = pack,
                        tilt = tilt,
                        sceneWidth = maxWidth,
                        sceneHeight = sceneHeight,
                        cardWidth = cardWidthDp,
                        cardHeight = cardHeightDp,
                        geometry = geometry,
                        shelf = shelf,
                        sceneOrigin = { sceneOrigin },
                        onComplete = ::markComplete,
                    )
                }
                JumpToCurrent(
                    c,
                    geometry,
                    Modifier
                        .align(Alignment.BottomEnd)
                        .padding(end = AppLayout.screenMargin, bottom = 24.dp + below),
                )
                if (c.fanned && verses.size >= 2) {
                    PouchThumb(c, sceneHeight, Modifier.align(Alignment.TopEnd))
                }
            }
        }
        if (c.fanned && below > 0.dp) {
            Box(
                Modifier
                    .align(Alignment.BottomCenter)
                    .fillMaxWidth()
                    .height(below + 20.dp)
                    .background(
                        Brush.verticalGradient(
                            0f to colors.background.copy(alpha = 0f),
                            0.45f to colors.background,
                            1f to colors.background,
                        ),
                    ),
            )
        }
        c.lifted?.let { card ->
            val dim = if (AppTheme.isDark) 0.68f else 0.16f
            Box(
                Modifier
                    .matchParentSize()
                    .graphicsLayer { alpha = dim * c.liftAmount.value }
                    .background(Color.Black),
            )
            val area = with(density) {
                Rect(
                    insets.calculateStartPadding(layoutDirection).toPx(),
                    insets.calculateTopPadding().toPx(),
                    screenSize.width - insets.calculateEndPadding(layoutDirection).toPx(),
                    screenSize.height - insets.calculateBottomPadding().toPx(),
                )
            }
            LiftedCardView(
                verse = verses[card.index],
                isLearnt = learning.isLearnt(verses[card.index]),
                source = card.source,
                area = area,
                lift = { c.liftAmount.value },
                angle = { c.liftedAngle.value },
                drag = { Offset(c.liftedDragX.value, c.liftedDragY.value) },
                onDrag = { c.followCardSwipe(it.x, it.y) },
                onRelease = c::releaseCardSwipe,
                onFlip = c::flipLiftedCard,
                onPutBack = c::putCardBack,
            )
        }
        Box(Modifier.fillMaxSize().padding(bottom = below)) {
            UndoToastHost(undoToast) { undoToast = it }
        }
    }
}

@Composable
private fun PouchTopBar(
    pack: Pack,
    c: PouchController,
    version: BibleVersion?,
    onVersion: (BibleVersion) -> Unit,
    onPractice: () -> Unit,
) {
    val colors = AppTheme.colors
    var showsVersions by remember { mutableStateOf(false) }
    val counter = listOfNotNull(
        pack.seriesCode,
        PackListLayout.positionLabel(c.index, c.verses.size, c.columns),
    ).joinToString(" · ")
    Layout(
        content = {
            ChromeIconButton(
                R.drawable.ic_x,
                "Close",
                onClick = { if (c.fanned) c.close(PackCloseMethod.closeButton) },
            )
            Column(
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(1.dp),
            ) {
                FlowRow(
                    horizontalArrangement = Arrangement.spacedBy(6.dp, Alignment.CenterHorizontally),
                    verticalArrangement = Arrangement.spacedBy(2.dp),
                    itemVerticalAlignment = Alignment.CenterVertically,
                ) {
                    Text(
                        pack.shortName,
                        style = AppType.headline,
                        color = colors.label,
                        maxLines = 1,
                        autoSize = TextAutoSize.StepBased(AppType.headline.fontSize * 0.85f, AppType.headline.fontSize, 0.25.sp),
                    )
                    if (version != null) {
                        Box(
                            Modifier
                                .semantics {
                                    contentDescription = "Bible Version"
                                    stateDescription = version.displayName
                                }
                                .pressable(label = "Change the Bible version") {
                                    if (c.fanned) showsVersions = true
                                }
                                .clip(CapsuleShape)
                                .background(colors.fill)
                                .padding(horizontal = 8.dp, vertical = 2.dp),
                        ) {
                            Text(
                                version.displayName,
                                Modifier.clearAndSetSemantics { },
                                style = AppType.subheadline.copy(fontWeight = FontWeight.SemiBold),
                                color = colors.label,
                                maxLines = 1,
                            )
                            if (showsVersions) {
                                AppMenu(
                                    actions = BibleVersion.entries.map { option ->
                                        MenuAction(option.displayName, R.drawable.ic_check.takeIf { option == version }) {
                                            onVersion(option)
                                        }
                                    },
                                    onDismiss = { showsVersions = false },
                                )
                            }
                        }
                    }
                }
                Text(
                    counter,
                    style = AppType.caption.copy(fontFeatureSettings = "tnum"),
                    color = colors.secondaryLabel,
                    maxLines = 1,
                    autoSize = TextAutoSize.StepBased(AppType.caption.fontSize * 0.7f, AppType.caption.fontSize, 0.25.sp),
                )
            }
            ChromeTextButton("Practice", onClick = { if (c.fanned) onPractice() })
        },
        modifier = Modifier
            .fillMaxWidth()
            .graphicsLayer { alpha = 1f - c.flight.value }
            .padding(horizontal = AppLayout.screenMargin, vertical = 8.dp)
            .heightIn(min = 44.dp),
    ) { measurables, constraints ->
        val loose = constraints.copy(minWidth = 0, minHeight = 0)
        val close = measurables[0].measure(loose)
        val practice = measurables[2].measure(loose)
        val gap = (AppLayout.spacing / 2).roundToPx()
        val width = constraints.maxWidth
        val room = (width - close.width - practice.width - 2 * gap).coerceAtLeast(0)
        val title = measurables[1].measure(loose.copy(maxWidth = room))
        val (x, _) = PackListLayout.titleSpan(
            width.toFloat(), close.width.toFloat(), practice.width.toFloat(), title.width.toFloat(), gap.toFloat(),
        )
        val height = maxOf(close.height, title.height, practice.height, constraints.minHeight)
        layout(width, height) {
            close.place(0, (height - close.height) / 2)
            title.place(x.roundToInt(), (height - title.height) / 2)
            practice.place(width - practice.width, (height - practice.height) / 2)
        }
    }
}


@Composable
private fun PouchThumb(c: PouchController, height: Dp, modifier: Modifier = Modifier) {
    val verses = c.verses
    VerseFastScrollOverlay(
        verseCount = verses.size,
        scrollFraction = c.listFraction ?: (c.index.toDouble() / (verses.size - 1)),
        containerHeight = height,
        titleProvider = { verses.getOrNull(it)?.title.orEmpty() },
        referenceProvider = { i -> verses.getOrNull(i)?.let { "${it.book} ${it.reference}" }.orEmpty() },
        onScrub = { fraction ->
            c.listScrolled = true
            c.scrubTo(fraction)
        },
        modifier = modifier.height(height),
        shownIndex = c.index,
    )
}

@Composable
private fun JumpToCurrent(c: PouchController, geometry: ListGeometry, modifier: Modifier = Modifier) {
    val learning = LearningStore.shared
    val current by remember { derivedStateOf { c.verses.indexOfFirst { learning.isCurrent(it) }.takeIf { it >= 0 } } }
    val target = current
    AnimatedVisibility(
        visible = c.fanned && target != null && geometry.layout.row(c.index) != geometry.layout.row(target),
        modifier = modifier,
        enter = fadeIn(tween(200)),
        exit = fadeOut(tween(200)),
    ) {
        JumpToCurrentButton(
            startExpanded = AppDefaults.standard.getBool(jumpLabelShownKey) != true,
            onExpandedShown = { AppDefaults.standard.putBool(jumpLabelShownKey, true) },
        ) {
            val to = current ?: return@JumpToCurrentButton
            HapticEngine.light()
            c.listScrolled = false
            c.index = to
            c.scrollTo(to, AppMotion.movement())
        }
    }
}

@Composable
private fun PouchAndDeck(
    c: PouchController,
    pack: Pack,
    tilt: TiltMonitor,
    sceneWidth: Dp,
    sceneHeight: Dp,
    cardWidth: Dp,
    cardHeight: Dp,
    geometry: ListGeometry,
    shelf: (() -> Rect)?,
    sceneOrigin: () -> Offset,
    onComplete: (Verse, VerseActionSource) -> Unit,
) {
    val verses = c.verses
    val learning = LearningStore.shared
    val density = LocalDensity.current
    val dark = AppTheme.isDark
    val index = c.index
    val w = sceneWidth.value
    val h = sceneHeight.value
    val widthLimit = geometry.layout.pouchWidthLimit
    val m = remember(w, h, widthLimit) { PouchMetrics.fitting(w, h - 12f, widthLimit) }
    val style = remember(dark) { PlasticStyle(dark) }
    val sceneTop = (h - 2 * m.halfHeight) / 2
    val cardFrame = m.cardFrame
    val coverCenter = Offset(w / 2, sceneTop + m.halfHeight / 2 + cardFrame.center.y)

    fun card(i: Int): PouchCard = when {
        i < -1 -> PouchCard.None
        i < 0 -> PouchCard.CoverBack
        i < verses.size -> PouchCard.Verse(i)
        i == verses.size -> PouchCard.BackPage
        else -> PouchCard.None
    }

    fun stackEdges(n: Int) = min(7, ceil(max(n, 0).toDouble() / 5).toInt())
    val slots = PouchSlots(card(index - 1), card(index), stackEdges(index - 1), stackEdges(verses.size - index))
    val deckEdges = min(5, ceil(max(verses.size - index - 1, 0).toDouble() / 8).toInt())

    @Composable
    fun face(card: PouchCard) {
        CardFace(card, c, pack, cardWidth, onComplete)
    }

    Box(Modifier.fillMaxSize().clearAndSetSemantics { }) {
        Box(
            Modifier
                .size(sceneWidth, sceneHeight)
                .graphicsLayer {
                    val f = c.flight.value
                    val tile = shelf?.invoke()
                    val origin = sceneOrigin()
                    val cx = coverCenter.x.dp.toPx()
                    val cy = coverCenter.y.dp.toPx()
                    val shelfScale = if (tile != null) tile.width / m.cardWidth.dp.toPx() else 1f
                    val s = 1f + (shelfScale - 1f) * f
                    scaleX = s
                    scaleY = s
                    transformOrigin = TransformOrigin(coverCenter.x / w, coverCenter.y / h)
                    translationX = if (tile != null) (tile.center.x - origin.x - cx) * f else 0f
                    translationY = if (tile != null) (tile.center.y - origin.y - cy) * f else 0f
                },
        ) {
            Box(Modifier.matchParentSize().graphicsLayer { alpha = min(1f, (1f - c.flight.value) * 4f) }) {
                Box(
                    Modifier
                        .matchParentSize()
                        .graphicsLayer {
                            val lift = c.lift.value
                            alpha = max(0f, 1f - 0.55f * lift - 0.45f * c.spread.value)
                            scaleX = 1f - 0.04f * lift
                            scaleY = 1f - 0.04f * lift
                        },
                    contentAlignment = Alignment.Center,
                ) {
                    PouchScene(
                        m = m,
                        style = style,
                        slots = slots,
                        openness = { c.openness.value },
                        lift = { c.lift.value },
                        tilt = { tilt.roll },
                        face = { card ->
                            ScaledCard(cardWidth, cardHeight) { face(card) }
                        },
                        cover = {
                            Box(Modifier.fillMaxSize().graphicsLayer { compositingStrategy = CompositingStrategy.Offscreen }) {
                                PackCover(
                                    pack,
                                    Modifier.fillMaxSize(),
                                    cornerRadius = 2.dp,
                                    showsShadow = false,
                                )
                            }
                        },
                    )
                }
            }
            if (shelf != null) {
                val shelfScale = with(density) { shelf().width / m.cardWidth.dp.toPx() }
                Box(
                    Modifier
                        .offset((coverCenter.x - m.cardWidth / 2).dp, (coverCenter.y - m.cardHeight / 2).dp)
                        .size(m.cardWidth.dp, m.cardHeight.dp)
                        .graphicsLayer { alpha = min(1f, max(0f, c.flight.value * 3f - 2f)) },
                ) {
                    PackCover(
                        pack,
                        Modifier.fillMaxSize(),
                        isCurrentPack = pack.name == learning.currentVerse?.packName,
                        cornerRadius = AppLayout.cardRadius / shelfScale,
                    )
                }
            }
        }

        val pocketCenter = with(density) { Offset((w / 2).dp.toPx(), (sceneTop + m.halfHeight + cardFrame.center.y).dp.toPx()) }
        Box(Modifier.fillMaxSize().clipToBounds()) {
            LiftedDeck(
                lift = { c.lift.value },
                spread = { c.spread.value },
                pocketCenter = pocketCenter,
                listCenter = { Offset(geometry.centerX(c.index), c.closeCenterY ?: geometry.midY(c.index)) },
                pocketWidth = m.cardWidth,
                listWidth = cardWidth,
                listHeight = cardHeight,
                listPitch = geometry.pitch.toFloat(),
                columnPitch = geometry.columnPitch,
                layout = geometry.layout,
                frontCard = index,
                around = { k ->
                    if (k == 0) card(index) else if (index + k in verses.indices) PouchCard.Verse(index + k) else PouchCard.None
                },
                edges = deckEdges,
                drift = { c.swipeOffset.value },
                face = { card -> face(card) },
            )
        }

        if (!c.closing) {
            Box(
                Modifier
                    .fillMaxSize()
                    .pointerInput(geometry.pitch) {
                        awaitEachGesture {
                            val down = awaitFirstDown(requireUnconsumed = false)
                            val tracker = VelocityTracker()
                            tracker.addPosition(down.uptimeMillis, down.position)
                            var last = down.position
                            do {
                                val event = awaitPointerEvent()
                                val change = event.changes.firstOrNull { it.id == down.id } ?: break
                                tracker.addPosition(change.uptimeMillis, change.position)
                                last = change.position
                            } while (change.pressed)
                            val velocity = tracker.calculateVelocity().y
                            val flick = ((last.y - down.position.y) + velocity * flickSeconds)
                            c.finishOpening(flick, geometry.pitch.toFloat(), geometry.layout.columns)
                        }
                    },
            )
        }
    }
}

@Composable
private fun ScaledCard(designWidth: Dp, designHeight: Dp, content: @Composable () -> Unit) {
    Layout(content, Modifier.fillMaxSize()) { measurables, constraints ->
        val placeable = measurables.first().measure(Constraints.fixed(designWidth.roundToPx(), designHeight.roundToPx()))
        val scale = constraints.maxWidth.toFloat() / placeable.width
        layout(constraints.maxWidth, constraints.maxHeight) {
            placeable.placeWithLayer(0, 0) {
                scaleX = scale
                scaleY = scale
                transformOrigin = TransformOrigin(0f, 0f)
                compositingStrategy = CompositingStrategy.Offscreen
            }
        }
    }
}

@Composable
private fun CardFace(
    card: PouchCard,
    c: PouchController,
    pack: Pack,
    width: Dp,
    onComplete: (Verse, VerseActionSource) -> Unit,
) {
    val verses = c.verses
    val learning = LearningStore.shared
    when {
        card is PouchCard.Verse && card.index in verses.indices -> {
            ListCard(verses[card.index], width, onComplete)
        }
        card is PouchCard.BackPage -> PaperAppearance {
            PouchBackPageCard(pack.name, verses.size, verses.count(learning::isLearnt), width)
        }
        card is PouchCard.CoverBack -> PaperAppearance {
            PaperFace(
                Modifier.size(width, width / AppLayout.cardAspect),
                PouchInk.paperBack(AppTheme.isDark),
            )
        }
        else -> Unit
    }
}

@Composable
private fun ListCard(
    verse: Verse,
    width: Dp,
    onComplete: (Verse, VerseActionSource) -> Unit,
    modifier: Modifier = Modifier,
) {
    val learning = LearningStore.shared
    val isCurrent = learning.isCurrent(verse)
    val density = LocalDensity.current
    PaperAppearance {
        PouchVerseCard(verse, learning.isLearnt(verse), width, modifier) {
            if (isCurrent) {
                val green = PouchInk.green(AppTheme.isDark)
                Row(
                    Modifier
                        .pressable { onComplete(verse, VerseActionSource.card) }
                        .clip(completeShape)
                        .background(green)
                        .padding(horizontal = 10.dp, vertical = 6.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(4.dp),
                ) {
                    Icon(R.drawable.ic_check, size = 12.dp, tint = Color.White)
                    Text(
                        "Complete",
                        style = AppType.caption.copy(
                            fontWeight = FontWeight.SemiBold,
                            fontSize = with(density) { 12.dp.toSp() },
                            lineHeight = with(density) { 16.dp.toSp() },
                        ),
                        color = Color.White,
                        maxLines = 1,
                    )
                }
            }
            Box(Modifier.size(30.dp), contentAlignment = Alignment.CenterEnd) {
                FavoriteStarButton(verse, Modifier.requiredSize(44.dp).offset(x = (-7).dp), Alignment.CenterEnd)
            }
        }
    }
}

@OptIn(ExperimentalFoundationApi::class)
@Composable
private fun FannedList(
    c: PouchController,
    pack: Pack,
    geometry: ListGeometry,
    width: Dp,
    height: Dp,
    below: Dp,
    screenOrigin: () -> Offset,
    onPractice: (Verse) -> Unit,
    onComplete: (Verse, VerseActionSource) -> Unit,
) {
    val verses = c.verses
    val listState = remember {
        val s = geometry.scrollFor(c.index)
        LazyListState(s / geometry.pitch, s % geometry.pitch).also { c.listState = it }
    }
    var measuredFor by remember { mutableStateOf(geometry.cardWidth to geometry.viewport) }

    LaunchedEffect(Unit) {
        withFrameNanos {}
        withFrameNanos {}
        c.listSettled = true
    }
    LaunchedEffect(geometry.cardWidth, geometry.viewport) {
        val size = geometry.cardWidth to geometry.viewport
        if (size != measuredFor) {
            measuredFor = size
            c.listScrolled = false
            c.scrollTo(c.index, null)
        }
    }
    LaunchedEffect(listState, geometry) {
        snapshotFlow { listState.firstVisibleItemIndex * geometry.pitch + listState.firstVisibleItemScrollOffset }
            .collect { offset ->
                c.listFraction = geometry.fraction(offset)
                if (c.listScrolled) {
                    val shown = geometry.cardShown(offset.toFloat(), c.index)
                    if (shown != c.index) c.index = shown
                }
            }
    }
    LaunchedEffect(listState) {
        listState.interactionSource.interactions.collect {
            if (it is DragInteraction.Start) c.listScrolled = true
        }
    }

    Box(
        Modifier
            .fillMaxSize()
            .pointerInput(c) { closeSwipe(c) },
    ) {
        LazyColumn(
            state = listState,
            modifier = Modifier
                .fillMaxSize()
                .graphicsLayer {
                    alpha = if (c.listSettled) 1f else 0f
                    translationX = c.swipeOffset.value
                }
                .clipToBounds(),
            contentPadding = PaddingValues(top = AppLayout.spacing, bottom = AppLayout.spacing + below),
            verticalArrangement = Arrangement.spacedBy(AppLayout.spacing),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            items(geometry.rows, key = { it }) { row ->
                val first = geometry.layout.firstCard(row)
                Row(horizontalArrangement = Arrangement.spacedBy(AppLayout.spacing)) {
                    for (i in first until first + geometry.layout.columns) {
                        if (i < verses.size) {
                            FannedCard(
                                verses[i],
                                width,
                                height,
                                isLifted = c.lifted?.index == i,
                                onLift = { c.liftCard(i, it.translate(-screenOrigin())) },
                                onPractice = { onPractice(verses[i]) },
                                onComplete = onComplete,
                            )
                        } else {
                            Spacer(Modifier.size(width, height))
                        }
                    }
                }
            }
        }
    }
}

@OptIn(ExperimentalFoundationApi::class)
@Composable
private fun FannedCard(
    verse: Verse,
    width: Dp,
    height: Dp,
    isLifted: Boolean,
    onLift: (Rect) -> Unit,
    onPractice: () -> Unit,
    onComplete: (Verse, VerseActionSource) -> Unit,
) {
    val learning = LearningStore.shared
    val favorites = FavoritesStore.shared
    var showsMenu by remember { mutableStateOf(false) }
    val source = remember { MutableInteractionSource() }
    val pressed by source.collectIsPressedAsState()
    val scale by animateFloatAsState(if (pressed) 0.97f else 1f, AppMotion.control(), label = "cardPress")
    val isFavorite = favorites.isFavorite(verse)
    val isLearnt = learning.isLearnt(verse)
    val placed = remember { arrayOfNulls<LayoutCoordinates>(1) }

    fun lift() {
        placed[0]?.takeIf { it.isAttached }?.let { onLift(Rect(it.positionInRoot(), it.size.toSize())) }
    }

    fun toggleStar() {
        Analytics.log(AnalyticsEvent.StarChanged(!favorites.isFavorite(verse), VerseActionSource.menu))
        favorites.toggle(verse)
    }

    fun toggleLearnt() {
        if (learning.isLearnt(verse)) {
            learning.unmarkLearnt(verse)
            Analytics.log(AnalyticsEvent.LearntChanged(false, VerseActionSource.menu))
            HapticEngine.light()
        } else {
            onComplete(verse, VerseActionSource.menu)
        }
    }

    Box(
        Modifier
            .size(width, height)
            .onPlaced { placed[0] = it }
            .graphicsLayer {
                scaleX = scale
                scaleY = scale
                alpha = if (isLifted) 0f else 1f
            }
            .listCardShadow()
            .clearAndSetSemantics {
                contentDescription = "${verse.title}, ${verse.book} ${verse.reference}. ${verse.verse}"
                role = Role.Button
                onClick("Lifts the card and turns it over") {
                    lift()
                    true
                }
                customActions = listOf(
                    CustomAccessibilityAction("Practice This Card") {
                        onPractice()
                        true
                    },
                    CustomAccessibilityAction(if (isFavorite) "Unstar" else "Star") {
                        toggleStar()
                        true
                    },
                    CustomAccessibilityAction(if (isLearnt) "Mark as not learnt" else "Mark as learnt") {
                        toggleLearnt()
                        true
                    },
                )
            }
            .combinedClickable(
                interactionSource = source,
                indication = null,
                onClick = ::lift,
                onLongClick = {
                    HapticEngine.light()
                    showsMenu = true
                },
            ),
    ) {
        ListCard(verse, width, onComplete)
        if (showsMenu) {
            AppMenu(
                actions = listOf(
                    MenuAction("Practice This Card", R.drawable.ic_keyboard, onClick = onPractice),
                    MenuAction(
                        if (isFavorite) "Unstar" else "Star",
                        if (isFavorite) R.drawable.ic_star_fill else R.drawable.ic_star,
                    ) {
                        HapticEngine.light()
                        toggleStar()
                    },
                    if (isLearnt) {
                        MenuAction("Mark as Not Learnt", R.drawable.ic_arrow_u_up_left, onClick = ::toggleLearnt)
                    } else {
                        MenuAction("Mark as Learnt", R.drawable.ic_check_circle, onClick = ::toggleLearnt)
                    },
                ),
                onDismiss = { showsMenu = false },
            )
        }
    }
}

private suspend fun PointerInputScope.closeSwipe(c: PouchController) {
    val slop = swipeSlop.toPx()
    awaitEachGesture {
        val down = awaitFirstDown(requireUnconsumed = false, pass = PointerEventPass.Initial)
        val tracker = VelocityTracker()
        tracker.addPosition(down.uptimeMillis, down.position)
        while (true) {
            val change = awaitPointerEvent(PointerEventPass.Initial).changes.firstOrNull { it.id == down.id } ?: return@awaitEachGesture
            if (!change.pressed || change.isConsumed) return@awaitEachGesture
            tracker.addPosition(change.uptimeMillis, change.position)
            val moved = change.position - down.position
            if (moved.getDistance() >= slop) {
                if (abs(moved.x) <= abs(moved.y) * 1.5f) return@awaitEachGesture
                change.consume()
                break
            }
        }
        var dx = 0f
        while (true) {
            val change = awaitPointerEvent(PointerEventPass.Initial).changes.firstOrNull { it.id == down.id } ?: break
            if (!change.pressed) break
            tracker.addPosition(change.uptimeMillis, change.position)
            dx = change.position.x - down.position.x
            change.consume()
            val follow = dx * swipeFollow
            c.followSwipe(follow)
        }
        val velocity = tracker.calculateVelocity().x
        val distance = dx / density
        val flick = (dx + velocity * flickSeconds) / density
        if (abs(distance) > swipeCloseDistance || abs(flick) > swipeCloseFlick) {
            c.close(PackCloseMethod.edgeSwipe)
        } else {
            c.releaseSwipe()
        }
    }
}
