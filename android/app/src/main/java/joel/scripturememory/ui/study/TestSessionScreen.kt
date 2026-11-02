package joel.scripturememory.ui.study

import androidx.activity.compose.PredictiveBackHandler
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.SizeTransform
import androidx.compose.animation.animateContentSize
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.expandHorizontally
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.animation.scaleOut
import androidx.compose.animation.shrinkHorizontally
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.WindowInsetsSides
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.ime
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.only
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawing
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.layout.wrapContentHeight
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.SideEffect
import androidx.compose.runtime.derivedStateOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.runtime.snapshotFlow
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.clipToBounds
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.GraphicsLayerScope
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.input.pointer.util.VelocityTracker
import androidx.compose.ui.input.pointer.util.addPointerInputChange
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.platform.LocalSoftwareKeyboardController
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.min
import androidx.compose.ui.zIndex
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.compose.LifecycleEventEffect
import joel.scripturememory.R
import joel.scripturememory.model.CardSection
import joel.scripturememory.model.CardSwipeConfig
import joel.scripturememory.model.Date
import joel.scripturememory.model.LearningStore
import joel.scripturememory.model.SRSGrade
import joel.scripturememory.model.StudyMode
import joel.scripturememory.model.StudyWindow
import joel.scripturememory.model.TestSession
import joel.scripturememory.model.Verse
import joel.scripturememory.model.displayState
import joel.scripturememory.model.notePeek
import joel.scripturememory.model.suggestedGradeFor
import joel.scripturememory.system.HapticEngine
import joel.scripturememory.system.rememberSpeechRecognizer
import joel.scripturememory.ui.components.ChromeIconButton
import joel.scripturememory.ui.components.Icon
import joel.scripturememory.ui.components.LocalCovers
import joel.scripturememory.ui.components.PrimaryButton
import joel.scripturememory.ui.components.Text
import joel.scripturememory.ui.components.TopBar
import joel.scripturememory.ui.components.UndoToastHost
import joel.scripturememory.ui.components.pressable
import joel.scripturememory.ui.theme.AppLayout
import joel.scripturememory.ui.theme.AppMotion
import joel.scripturememory.ui.theme.AppTheme
import joel.scripturememory.ui.theme.AppType
import joel.scripturememory.ui.theme.StudyControlMetrics
import kotlin.coroutines.cancellation.CancellationException
import kotlin.math.abs
import kotlin.math.cos
import kotlin.math.sin
import kotlinx.coroutines.flow.drop
import kotlinx.coroutines.launch

private const val predictiveShrink = 0.08f
private val compactSummaryHeight = 480.dp

@Composable
fun rememberSessionClose(onClose: (() -> Unit)?): () -> Unit {
    val covers = LocalCovers.current
    return remember(covers, onClose) { onClose ?: { covers.dismiss() } }
}

@Composable
fun TestSessionScreen(
    session: TestSession,
    onSessionEnded: () -> Unit,
    onRoundEnded: ((grades: List<SRSGrade>, missed: List<Verse>) -> Unit)? = null,
    onClose: (() -> Unit)? = null,
) {
    val colors = AppTheme.colors
    val scope = rememberCoroutineScope()
    val speech = rememberSpeechRecognizer()
    val keyboard = LocalSoftwareKeyboardController.current
    val focusManager = LocalFocusManager.current
    val close = rememberSessionClose(onClose)
    val state = remember(session.id) {
        TestSessionState(
            session = session,
            speech = speech,
            scope = scope,
            showKeyboard = { keyboard?.show() },
            dropFocus = {
                focusManager.clearFocus(force = true)
                keyboard?.hide()
            },
        )
    }
    SideEffect {
        state.onSessionEnded = onSessionEnded
        state.onRoundEnded = onRoundEnded
        state.closeScreen = close
    }

    val vm = state.vm
    val predictive = remember { Animatable(0f) }

    PredictiveBackHandler { progress ->
        try {
            progress.collect { event -> predictive.snapTo(event.progress) }
            state.close()
        } catch (cancelled: CancellationException) {
            scope.launch { predictive.animateTo(0f, AppMotion.control()) }
            throw cancelled
        }
    }

    LifecycleEventEffect(Lifecycle.Event.ON_RESUME) { state.activeTime.resume() }
    LifecycleEventEffect(Lifecycle.Event.ON_PAUSE) { state.activeTime.pause() }
    DisposableEffect(state) {
        state.logStart()
        onDispose { state.logEnd(finished = false) }
    }
    LaunchedEffect(state) {
        kotlinx.coroutines.delay(200)
        state.focusInput()
    }
    LaunchedEffect(state) {
        snapshotFlow { vm.currentIndex }.drop(1).collect { state.indexChanged() }
    }
    LaunchedEffect(state) {
        snapshotFlow { speech.transcript }.drop(1).collect(state::transcriptChanged)
    }
    LaunchedEffect(state) {
        snapshotFlow { state.isPeeking }.collect { peeking ->
            if (peeking) vm.currentVerse?.let(vm::notePeek)
        }
    }
    LaunchedEffect(state) {
        snapshotFlow { state.submitFocus }.drop(1).collect(state::submitFocusChanged)
    }
    LaunchedEffect(state) {
        snapshotFlow { vm.isCardComplete }.collect { complete ->
            if (complete) state.hideKeyboard()
        }
    }

    BoxWithConstraints(
        Modifier
            .fillMaxSize()
            .graphicsLayer {
                val scale = 1f - predictiveShrink * predictive.value
                scaleX = scale
                scaleY = scale
            }
            .background(colors.background),
    ) {
        val keyboard = with(LocalDensity.current) { WindowInsets.ime.getBottom(this).toDp() }
        val dropsTitle = StudyWindow.dropsTitle((maxHeight - keyboard).value, 0f)
        Column(Modifier.fillMaxSize().windowInsetsPadding(WindowInsets.safeDrawing.only(WindowInsetsSides.Horizontal))) {
            if (!dropsTitle) SessionTopBar(state, Modifier.zIndex(1f))
            Row(Modifier.weight(1f).fillMaxWidth().then(if (dropsTitle) Modifier.statusBarsPadding() else Modifier)) {
                if (dropsTitle) SessionRail(state)
                Box(Modifier.weight(1f).fillMaxHeight().navigationBarsPadding().imePadding()) {
                    SessionBody(state, showsPosition = dropsTitle)
                    UndoToastHost(state.undoToastState) { state.undoToastState = it }
                }
            }
        }
        SpeechErrorAlert(speech) { state.focusInput() }
    }
}

@Composable
private fun SessionTopBar(state: TestSessionState, modifier: Modifier) {
    TopBar(
        title = state.sessionTitle,
        subtitle = state.positionLabel,
        showsBackground = false,
        modifier = modifier,
        leading = {
            if (state.isReview) {
                ChromeGroup {
                    ChromeGroupButton(R.drawable.ic_x, "Close", onClick = state::close)
                    ChromeGroupButton(
                        R.drawable.ic_arrow_u_up_left,
                        "Undo Last Rating",
                        enabled = state.vm.gradedOrder.isNotEmpty(),
                        onClick = state::undoLastGrade,
                    )
                }
            } else {
                ChromeGroup {
                    ChromeGroupButton(R.drawable.ic_x, "Close", onClick = state::close)
                }
            }
        },
        actions = {
            if (state.isEditing) {
                ChromeGroup { HideKeyboardButton(state) }
            }
        },
    )
}

@Composable
private fun SessionRail(state: TestSessionState) {
    Column(
        Modifier.padding(start = 8.dp, top = 8.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        ChromeGroup {
            ChromeGroupButton(R.drawable.ic_x, "Close", onClick = state::close)
        }
        if (state.isReview) {
            ChromeGroup {
                ChromeGroupButton(
                    R.drawable.ic_arrow_u_up_left,
                    "Undo Last Rating",
                    enabled = state.vm.gradedOrder.isNotEmpty(),
                    onClick = state::undoLastGrade,
                )
            }
        }
        if (state.isEditing) {
            ChromeGroup { HideKeyboardButton(state) }
        }
    }
}

@Composable
private fun HideKeyboardButton(state: TestSessionState) {
    Box(
        Modifier
            .size(44.dp)
            .semantics { contentDescription = "Hide Keyboard" }
            .pressable(pressedScale = 0.9f, onClick = state::hideKeyboard),
        contentAlignment = Alignment.Center,
    ) {
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Icon(R.drawable.ic_keyboard, size = 19.dp, tint = AppTheme.colors.label)
            Icon(R.drawable.ic_caret_down, Modifier.offset(y = (-2).dp), size = 8.dp, tint = AppTheme.colors.label)
        }
    }
}

@Composable
private fun PositionLabel(state: TestSessionState, modifier: Modifier) {
    val colors = AppTheme.colors
    Text(
        state.positionLabel,
        modifier
            .padding(8.dp)
            .clip(RoundedCornerShape(percent = 50))
            .background(colors.background.copy(alpha = 0.82f))
            .padding(horizontal = 8.dp, vertical = 4.dp)
            .semantics { contentDescription = "${state.sessionTitle}, ${state.positionLabel}" },
        style = AppType.caption,
        color = colors.secondaryLabel,
        maxLines = 1,
    )
}

@Composable
private fun SessionBody(state: TestSessionState, showsPosition: Boolean) {
    val vm = state.vm
    BoxWithConstraints(Modifier.fillMaxSize()) {
        val columnWidth = min(maxWidth, AppLayout.studyColumnWidth)
        val cardWidth = columnWidth - AppLayout.screenMargin * 2
        val cardHeight = cardWidth / AppLayout.cardAspect
        val isShort = maxHeight < AppLayout.shortStudyHeight
        val compactSummary = maxHeight < compactSummaryHeight

        Column(Modifier.width(columnWidth).fillMaxHeight().align(Alignment.TopCenter)) {
            BoxWithConstraints(Modifier.weight(1f).fillMaxWidth()) {
                val room = maxOf(72.dp, maxHeight - 12.dp)
                val pans = isShort && room < cardHeight
                val cardH = if (pans) cardHeight else min(cardHeight, room)
                val panned by animateFloatAsState(
                    if (pans) state.typingProgress else 0f,
                    AppMotion.control(),
                    label = "cardPan",
                )
                val density = LocalDensity.current
                val travel = with(density) { (room - cardHeight).toPx() }

                Box(
                    Modifier
                        .padding(top = 8.dp)
                        .align(Alignment.TopCenter)
                        .size(cardWidth, if (pans) room else cardH)
                        .then(if (pans) Modifier.clipToBounds() else Modifier),
                ) {
                    Box(
                        Modifier
                            .wrapContentHeight(Alignment.Top, unbounded = true)
                            .size(cardWidth, cardH)
                            .graphicsLayer { translationY = travel * panned },
                    ) {
                        CardStack(state)
                        PeekLayer(state, cardWidth, cardH)
                    }
                    if (showsPosition) PositionLabel(state, Modifier.align(Alignment.TopEnd))
                }
            }

            if (vm.verses.size > 1 && !state.isReview && !isShort) {
                Box(Modifier.padding(horizontal = AppLayout.screenMargin).padding(bottom = 6.dp)) {
                    VerseScrubberRow(
                        verseCount = vm.verses.size,
                        currentIndex = vm.currentIndex,
                        onIndexChange = state::scrubTo,
                        onScrubbingChange = state::scrubbingChanged,
                        onStepBack = state::stepBack,
                        onStepForward = state::stepForward,
                    )
                }
            }

            BottomControls(state, isShort, compactSummary)
        }
    }
}

@Composable
private fun PeekLayer(state: TestSessionState, width: Dp, height: Dp) {
    val verse = state.vm.currentVerse
    AnimatedVisibility(
        visible = state.isPeeking && verse != null,
        enter = fadeIn(AppMotion.control()),
        exit = fadeOut(AppMotion.control()),
    ) {
        if (verse != null) {
            PeekOverlayCard(
                verse = verse,
                cardLabel = state.vm.cardLabel(verse),
                width = width,
                height = height,
                showCardLabel = state.showsCardLabel,
            )
        }
    }
}

private fun GraphicsLayerScope.placeCard(x: Float, y: Float, scale: Float, degrees: Float) {
    val radians = Math.toRadians(degrees.toDouble())
    val sx = x * scale
    val sy = y * scale
    scaleX = scale
    scaleY = scale
    rotationZ = degrees
    translationX = (sx * cos(radians) - sy * sin(radians)).toFloat()
    translationY = (sx * sin(radians) + sy * cos(radians)).toFloat()
}

private fun Modifier.cardGestures(state: TestSessionState): Modifier = pointerInput(state) {
    val slop = viewConfiguration.touchSlop
    val dpPerPx = 1f / density
    awaitEachGesture {
        val down = awaitFirstDown(requireUnconsumed = false)
        val tracker = VelocityTracker()
        tracker.addPointerInputChange(down)
        var dragging = false
        var wandered = false
        var taken = false
        while (true) {
            val event = awaitPointerEvent()
            val change = event.changes.firstOrNull { it.id == down.id } ?: break
            val translation = (change.position - down.position) * dpPerPx
            if (!change.pressed) {
                if (dragging) {
                    val velocity = tracker.calculateVelocity()
                    state.dragEnded(translation, Offset(velocity.x, velocity.y) * dpPerPx)
                } else if (!wandered && !taken && !change.isConsumed) {
                    if (state.studyMode != StudyMode.submit && !state.vm.isCardComplete) state.focusInput()
                }
                break
            }
            tracker.addPointerInputChange(change)
            if (change.isConsumed && !dragging) taken = true
            val moved = change.position - down.position
            if (abs(moved.x) > slop || abs(moved.y) > slop) wandered = true
            if (!dragging && !taken && abs(moved.x) > slop && abs(moved.x) > abs(moved.y)) dragging = true
            if (dragging) {
                change.consume()
                state.drag(translation)
            }
        }
    }
}

@Composable
private fun CardStack(state: TestSessionState) {
    val vm = state.vm
    val density = LocalDensity.current.density
    val index = vm.currentIndex
    val showsPrevious by remember(state) {
        derivedStateOf { state.vm.currentIndex > 0 && state.dragOffset.x > 0f }
    }
    Box(Modifier.fillMaxSize().cardGestures(state)) {
        if (index + 2 < vm.verses.size) {
            Box(Modifier.fillMaxSize().graphicsLayer { placeCard(0f, 24f / 0.9f * density, 0.9f, 0f) }) {
                MakeCard(state, vm.verses[index + 2], index + 2, interactive = false)
            }
        }
        if (index + 1 < vm.verses.size) {
            Box(
                Modifier.fillMaxSize().graphicsLayer {
                    val forward = CardSwipeConfig.forwardDragProgress(state.dragOffset.x)
                    val scale = 0.95f + 0.05f * forward
                    placeCard(0f, 12f * (1f - forward) / scale * density, scale, 0f)
                },
            ) {
                MakeCard(state, vm.verses[index + 1], index + 1, interactive = false)
            }
        }
        val leaving = state.dissolveFrom
        if (leaving != null && leaving in vm.verses.indices) {
            MakeCard(state, vm.verses[leaving], leaving, interactive = false)
        }
        vm.currentVerse?.let { verse ->
            Box(
                Modifier.fillMaxSize().graphicsLayer {
                    val drag = state.dragOffset
                    val goingBack = drag.x > 0f
                    val back = CardSwipeConfig.backwardDragProgress(drag.x)
                    placeCard(
                        x = if (goingBack) 0f else drag.x * density,
                        y = (if (goingBack) back * 12f else drag.y * 0.1f) * density,
                        scale = if (goingBack) 1f - back * 0.05f else 1f,
                        degrees = if (goingBack) 0f else drag.x * 0.03f,
                    )
                    alpha = if (state.dissolveFrom != null) state.dissolve.value else 1f
                },
            ) {
                MakeCard(state, verse, index, interactive = true)
            }
        }
        if (showsPrevious) {
            val previous = vm.verses.getOrNull(index - 1)
            if (previous != null) {
                Box(
                    Modifier.fillMaxSize().graphicsLayer {
                        val x = state.dragOffset.x - CardSwipeConfig.prevCardOffset
                        placeCard(x * density, 0f, 1f, x * 0.02f)
                    },
                ) {
                    MakeCard(state, previous, index - 1, interactive = false)
                }
            }
        }
    }
}

@Composable
private fun MakeCard(state: TestSessionState, verse: Verse, verseIndex: Int, interactive: Boolean) {
    val vm = state.vm
    val learning = LearningStore.shared
    val studyMode = state.studyMode
    val hasResult = verse.id in vm.submitResults
    val isBehind = verseIndex < vm.currentIndex
    val isAhead = verseIndex > vm.currentIndex
    val isDirectNext = verseIndex == vm.currentIndex + 1
    val isDirectPrev = verseIndex == vm.currentIndex - 1

    val showSubmitSurface = studyMode == StudyMode.submit &&
        (interactive || (isDirectNext && !hasResult) || (isDirectPrev && !hasResult))

    if (showSubmitSurface) {
        SubmitCardView(
            verse = verse,
            cardLabel = vm.cardLabel(verse),
            titleText = if (interactive) vm.titleInput else "",
            onTitleChange = { if (interactive) vm.titleInput = it },
            verseText = if (interactive) vm.verseInput else "",
            onVerseChange = { if (interactive) vm.verseInput = it },
            result = if (interactive) vm.submitResults[verse.id] else null,
            focus = state.submitFocusRequesters,
            interactive = interactive,
            onFocusChange = { field, focused -> if (interactive) state.fieldFocusChanged(field, focused) },
            isCurrentLearning = learning.isCurrent(verse),
            showCardLabel = state.showsCardLabel,
        )
    } else {
        val forceMasked = studyMode == StudyMode.submit && !interactive &&
            ((isAhead && (!isDirectNext || hasResult)) || isBehind)
        FlashcardView(
            verse = verse,
            cardLabel = vm.cardLabel(verse),
            isReviewMode = true,
            titleRevealedCount = if (forceMasked) 0 else vm.revealedCount(verse.id, CardSection.title),
            verseRevealedCount = if (forceMasked) 0 else vm.revealedCount(verse.id, CardSection.verse),
            activeSection = vm.activeSection,
            onSectionTap = if (interactive) {
                { section ->
                    vm.activeSection = section
                    state.focusInput()
                }
            } else {
                null
            },
            showCardLabel = state.showsCardLabel,
            isCurrentLearning = learning.isCurrent(verse),
        )
    }
}

@Composable
private fun BottomControls(state: TestSessionState, isShort: Boolean, compactSummary: Boolean) {
    val vm = state.vm
    val learning = LearningStore.shared
    val studyMode = state.studyMode
    val showSummary = state.showSessionSummary
    Column(
        Modifier
            .fillMaxWidth()
            .animateContentSize(AppMotion.content())
            .padding(horizontal = AppLayout.screenMargin)
            .padding(top = 6.dp, bottom = if (isShort) 6.dp else 24.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        AnimatedContent(
            targetState = showSummary,
            transitionSpec = {
                (fadeIn(AppMotion.content()) + scaleIn(AppMotion.content(), initialScale = 0.8f))
                    .togetherWith(fadeOut(AppMotion.content()) + scaleOut(AppMotion.content(), targetScale = 0.8f))
                    .using(SizeTransform(clip = false))
            },
            label = "summary",
        ) { summary ->
            if (summary) {
                SessionCompletePanel(vm, studyMode, compact = compactSummary, onDone = state::finishSession)
            } else {
                CardControlBand(state)
            }
        }

        val markable = vm.currentVerse?.takeIf {
            !showSummary && !state.isReview && vm.isCardComplete && learning.isCurrent(it)
        }
        AnimatedVisibility(
            visible = markable != null,
            enter = fadeIn(AppMotion.content()) + scaleIn(AppMotion.content(), initialScale = 0.8f),
            exit = fadeOut(AppMotion.content()) + scaleOut(AppMotion.content(), targetScale = 0.8f),
        ) {
            MarkCompleteButton { markable?.let(state::markComplete) }
        }

        if (!showSummary && !state.isReview && vm.completedCount == vm.verses.size) {
            PrimaryButton("End Session", onClick = state::finishSession)
        }
    }
}

private enum class BandKind { Recall, Next, Grading, SubmitEntry, SubmitRetry }

private data class Band(val kind: BandKind, val verse: Verse?)

private fun bandFor(state: TestSessionState): Band {
    val vm = state.vm
    val verse = vm.currentVerse
    val kind = when {
        vm.isCardComplete -> if (state.isReview) BandKind.Grading else BandKind.Next
        state.studyMode != StudyMode.submit -> BandKind.Recall
        verse != null && verse.id in vm.submitResults ->
            if (state.isReview) BandKind.Grading else BandKind.SubmitRetry
        else -> BandKind.SubmitEntry
    }
    return Band(kind, verse)
}

@Composable
private fun CardControlBand(state: TestSessionState) {
    val vm = state.vm
    Row(verticalAlignment = Alignment.CenterVertically) {
        AnimatedVisibility(
            visible = !vm.isCardAnswered,
            enter = fadeIn(AppMotion.content()) + expandHorizontally(AppMotion.content()),
            exit = fadeOut(AppMotion.content()) + shrinkHorizontally(AppMotion.content()),
        ) {
            Box(Modifier.padding(end = StudyControlMetrics.rowSpacing)) {
                PeekHoldButton(state.isPeeking) { state.isPeeking = it }
            }
        }
        AnimatedContent(
            targetState = bandFor(state),
            modifier = Modifier.weight(1f),
            contentKey = { it.kind },
            transitionSpec = {
                fadeIn(AppMotion.content()).togetherWith(fadeOut(AppMotion.content()))
                    .using(SizeTransform(clip = false))
            },
            contentAlignment = Alignment.BottomCenter,
            label = "band",
        ) { band ->
            when (band.kind) {
                BandKind.Recall -> RecallInputField(
                    vm = vm,
                    studyMode = state.studyMode,
                    isListening = state.speech.isListening,
                    focusRequester = state.inputFocus,
                    onFocusChange = { state.isInputFocused = it },
                    onToggleSpeech = state::toggleSpeech,
                )
                BandKind.Next -> NextButton(state)
                BandKind.Grading -> band.verse?.let { GradingButtons(state, it) }
                BandKind.SubmitRetry -> SubmitRetryRow(state)
                BandKind.SubmitEntry -> SubmitAnswerRow(
                    isListening = state.speech.isListening,
                    canSubmit = vm.hasSubmitInput,
                    onToggleSpeech = state::toggleSpeech,
                    onHint = { vm.fillNextHintWord(startingWithVerse = state.submitFocus == joel.scripturememory.model.SubmitField.verse) },
                    onSubmit = state::submit,
                )
            }
        }
    }
}

@Composable
private fun GradingButtons(state: TestSessionState, verse: Verse) {
    val vm = state.vm
    SRSGradingButtons(
        state = vm.displayState(verse),
        suggested = vm.suggestedGradeFor(verse),
        selected = vm.sessionGrades[verse.id],
        now = Date.now(),
        onPick = { grade ->
            if (vm.currentVerse?.id == verse.id) state.gradeAndAdvance(grade)
        },
    )
}

@Composable
private fun NextButton(state: TestSessionState) {
    val colors = AppTheme.colors
    StudyActionButton(
        "Next",
        icon = R.drawable.ic_check_circle_fill,
        iconTint = colors.green,
        enabled = !state.isLastCard,
        disabledAlpha = 0.5f,
        verticalPadding = 14.6.dp,
        onClick = state::next,
    )
}

@Composable
private fun SubmitRetryRow(state: TestSessionState) {
    val colors = AppTheme.colors
    Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
        TryAgainButton(Modifier.weight(1f)) { state.vm.retrySubmit() }
        StudyActionButton(
            "Next",
            Modifier.weight(1f),
            foreground = colors.onAccent,
            background = colors.accent,
            enabled = !state.isLastCard,
            disabledAlpha = 0.5f,
            onClick = state::next,
        )
    }
}
