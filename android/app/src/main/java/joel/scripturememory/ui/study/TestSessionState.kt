package joel.scripturememory.ui.study

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.VectorConverter
import androidx.compose.animation.core.animate
import androidx.compose.runtime.Stable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.geometry.Offset
import joel.scripturememory.model.ActiveTimer
import joel.scripturememory.model.AnalyticsEvent
import joel.scripturememory.model.AnalyticsScreen
import joel.scripturememory.model.AppDefaults
import joel.scripturememory.model.CardSwipeConfig
import joel.scripturememory.model.Date
import joel.scripturememory.model.LearningStore
import joel.scripturememory.model.SRSGrade
import joel.scripturememory.model.SRSPhase
import joel.scripturememory.model.SRSQueueBuilder
import joel.scripturememory.model.SRSStore
import joel.scripturememory.model.SessionKind
import joel.scripturememory.model.StudyMode
import joel.scripturememory.model.StudySessionKind
import joel.scripturememory.model.StudySessionStart
import joel.scripturememory.model.StudySessionSummary
import joel.scripturememory.model.SubmitField
import joel.scripturememory.model.TestSession
import joel.scripturememory.model.TestSessionViewModel
import joel.scripturememory.model.Verse
import joel.scripturememory.model.grade
import joel.scripturememory.model.undoLastGrade
import joel.scripturememory.system.Analytics
import joel.scripturememory.system.HapticEngine
import joel.scripturememory.system.SpeechRecognizer
import joel.scripturememory.ui.components.UndoToastState
import joel.scripturememory.ui.theme.AppMotion
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlin.math.abs

private const val refocusDelayMillis = 100L
private const val focusRetryMillis = 120L
private const val predictedEndSeconds = 0.25f

@Stable
internal class TestSessionState(
    val session: TestSession,
    val speech: SpeechRecognizer,
    private val scope: CoroutineScope,
    private val showKeyboard: () -> Unit,
    private val dropFocus: () -> Unit,
) {
    val vm = TestSessionViewModel(session.verses, session.kind)

    var onSessionEnded: () -> Unit = {}
    var onRoundEnded: ((List<SRSGrade>, List<Verse>) -> Unit)? = null
    var closeScreen: () -> Unit = {}

    val inputFocus = FocusRequester()
    val submitFocusRequesters = SubmitFocus()

    var isInputFocused by mutableStateOf(false)
    var submitFocus by mutableStateOf<SubmitField?>(null)
    var dragOffset by mutableStateOf(Offset.Zero)
        private set
    var isScrubbing by mutableStateOf(false)
    var isPeeking by mutableStateOf(false)
    var undoToastState by mutableStateOf<UndoToastState?>(null)
    var dissolveFrom by mutableStateOf<Int?>(null)
        private set
    val dissolve = Animatable(1f)

    private var isCardFlying = false
    private var flyDirection = 0
    private var speechTarget = SubmitField.title
    private var flyJob: Job? = null
    private var dragJob: Job? = null
    private var dissolveJob: Job? = null

    var activeTime = ActiveTimer()
        private set
    private var undoCount = 0
    private var usedVoice = false
    private var loggedStart = false
    private var loggedEnd = false

    val isReview: Boolean get() = session.kind == SessionKind.srs

    val studyMode: StudyMode get() = StudyMode.saved()

    val sessionTitle: String
        get() = when (session.kind) {
            SessionKind.srs -> if (session.round > 1) "Another look" else "Review"
            SessionKind.pack -> "Practice"
            SessionKind.custom -> "Quiz"
        }

    val showsCardLabel: Boolean get() = isReview

    val positionLabel: String get() = "Card ${vm.currentIndex + 1} of ${vm.verses.size}"

    val isEditing: Boolean get() = isInputFocused || submitFocus != null

    val isLastCard: Boolean get() = vm.currentIndex >= vm.verses.size - 1

    val typingProgress: Float get() = typingProgress(vm.currentIndex)

    val showSessionSummary: Boolean
        get() = if (isReview) vm.verses.all { it.id in vm.sessionGrades } else vm.isSessionComplete

    private fun typingProgress(index: Int): Float {
        val verse = vm.verses.getOrNull(index) ?: return 0f
        val total = verse.titleWords.size + verse.verseWords.size
        if (total <= 0) return 0f
        val typed = vm.revealedCount(verse.id, joel.scripturememory.model.CardSection.title) +
            vm.revealedCount(verse.id, joel.scripturememory.model.CardSection.verse)
        return typed.toFloat() / total
    }

    fun hideKeyboard() {
        isInputFocused = false
        submitFocus = null
        dropFocus()
    }

    fun close() {
        if (speech.isListening) speech.stopListening()
        dropFocus()
        closeScreen()
    }

    fun indexChanged() {
        vm.clearInputs()
        vm.resetDictation()
        if (speech.isListening) speech.stopListening()
        if (isScrubbing) {
            if (submitFocus != null) focusSubmit(SubmitField.title)
        } else {
            refocusIfNeeded()
        }
    }

    fun transcriptChanged(text: String) {
        if (speech.isListening) vm.applyDictation(text, speechTarget)
    }

    fun submitFocusChanged(newFocus: SubmitField?) {
        if (!speech.isListening || newFocus == null) return
        speech.stopListening()
        speechTarget = newFocus
        speech.startListening()
    }

    fun fieldFocusChanged(field: SubmitField, focused: Boolean) {
        if (focused) {
            submitFocus = field
        } else if (submitFocus == field) {
            submitFocus = null
        }
    }

    fun toggleSpeech() {
        if (speech.isListening) {
            speech.stopListening()
        } else {
            speechTarget = submitFocus ?: SubmitField.title
            vm.resetDictation()
            speech.startListening()
            usedVoice = true
        }
    }

    fun submit() {
        if (speech.isListening) speech.stopListening()
        val result = vm.handleSubmit()
        hideKeyboard()
        if (result?.isAllCorrect == true) HapticEngine.success() else HapticEngine.error()
    }

    fun markComplete(verse: Verse) {
        val learning = LearningStore.shared
        learning.markLearnt(verse)
        HapticEngine.success()
        undoToastState = UndoToastState.markedComplete(verse, learning)
    }

    fun stepBack() {
        HapticEngine.light()
        moveProgrammatically(refocus = false) { vm.goBackward() }
    }

    fun stepForward() {
        HapticEngine.light()
        moveProgrammatically(refocus = false) { vm.goForward() }
    }

    fun next() {
        HapticEngine.light()
        moveProgrammatically { vm.goForward() }
    }

    fun scrubTo(index: Int) {
        dissolving { vm.currentIndex = index }
        vm.saveProgress()
    }

    fun scrubbingChanged(scrubbing: Boolean) {
        if (scrubbing) {
            isScrubbing = true
        } else {
            scope.launch {
                delay(AppMotion.settleMillis)
                isScrubbing = false
            }
        }
    }

    fun drag(translation: Offset) {
        if (abs(translation.x) <= abs(translation.y)) return
        if (isCardFlying) commitSwipe()
        val swipeNav = session.kind != SessionKind.srs
        val canNext = swipeNav && vm.currentIndex < vm.verses.size - 1
        val canPrev = swipeNav && vm.currentIndex > 0
        dragJob?.cancel()
        dragOffset = CardSwipeConfig.clampedDragTranslation(translation, canNext, canPrev)
    }

    fun dragEnded(translation: Offset, velocity: Offset) {
        if (isCardFlying) commitSwipe()
        val isHorizontal = abs(translation.x) > abs(translation.y)
        val predicted = velocity.x * predictedEndSeconds
        val swipeNav = session.kind != SessionKind.srs
        if (isHorizontal && swipeNav &&
            (dragOffset.x < -CardSwipeConfig.threshold || predicted < -CardSwipeConfig.velocityThreshold) &&
            vm.currentIndex < vm.verses.size - 1
        ) {
            swipeForward()
        } else if (isHorizontal && swipeNav &&
            (dragOffset.x > CardSwipeConfig.threshold || predicted > CardSwipeConfig.velocityThreshold) &&
            vm.currentIndex > 0
        ) {
            swipeBackward()
        } else {
            animateDrag(Offset.Zero)
            scope.launch {
                delay(AppMotion.settleShortMillis)
                refocusIfNeeded()
            }
        }
    }

    private fun animateDrag(target: Offset) {
        dragJob?.cancel()
        val start = dragOffset
        dragJob = scope.launch {
            animate(Offset.VectorConverter, start, target, animationSpec = AppMotion.control()) { value, _ ->
                dragOffset = value
            }
        }
    }

    private fun swipeForward() {
        isScrubbing = true
        isCardFlying = true
        flyDirection = -1
        HapticEngine.light()
        animateDrag(Offset(-CardSwipeConfig.flyWidth, dragOffset.y))
        scheduleCommit()
    }

    private fun swipeBackward() {
        isScrubbing = true
        isCardFlying = true
        flyDirection = 1
        HapticEngine.light()
        animateDrag(Offset(CardSwipeConfig.prevCardOffset, 0f))
        scheduleCommit()
    }

    private fun scheduleCommit() {
        flyJob?.cancel()
        flyJob = scope.launch {
            delay(AppMotion.settleShortMillis)
            commitSwipe()
        }
    }

    private fun commitSwipe() {
        if (!isCardFlying) return
        flyJob?.cancel()
        dragJob?.cancel()
        if (flyDirection < 0) vm.goForward() else if (flyDirection > 0) vm.goBackward()
        dragOffset = Offset.Zero
        isCardFlying = false
        flyDirection = 0
        if (!vm.isCardComplete && !vm.isSessionComplete) focusInput()
        scope.launch {
            delay(AppMotion.settleMillis)
            isScrubbing = false
        }
    }

    private fun dissolving(move: () -> Unit) {
        val from = vm.currentIndex
        val before = typingProgress(from)
        move()
        if (vm.currentIndex == from || typingProgress(vm.currentIndex) == before) return
        dissolveJob?.cancel()
        dissolveFrom = from
        dissolveJob = scope.launch {
            dissolve.snapTo(0f)
            dissolve.animateTo(1f, AppMotion.control())
            dissolveFrom = null
        }
    }

    private fun moveProgrammatically(refocus: Boolean = true, move: () -> Unit) {
        isScrubbing = true
        dissolving(move)
        scope.launch {
            delay(AppMotion.settleMillis)
            isScrubbing = false
            if (refocus) refocusIfNeeded()
        }
    }

    private fun refocusIfNeeded() {
        if (vm.isCardComplete) return
        scope.launch {
            delay(refocusDelayMillis)
            focusInput()
        }
    }

    private fun request(requester: FocusRequester) {
        val taken = runCatching { requester.requestFocus() }.getOrDefault(false)
        if (taken) showKeyboard()
    }

    private fun focusSubmit(field: SubmitField) {
        val focus = submitFocusRequesters
        request(if (field == SubmitField.title) focus.title else focus.verse)
    }

    fun focusInput(retriesLeft: Int = 4) {
        val submits = studyMode == StudyMode.submit
        if (submits) focusSubmit(SubmitField.title) else request(inputFocus)
        if (retriesLeft <= 0) return
        scope.launch {
            delay(focusRetryMillis)
            if (vm.isCardComplete) return@launch
            val landed = if (submits) submitFocus != null else isInputFocused
            if (!landed) focusInput(retriesLeft - 1)
        }
    }

    fun finishSession() {
        logEnd(finished = true)
        TestSessionViewModel.clearPersistedProgress(session.kind)
        onSessionEnded()
        closeScreen()
    }

    fun gradeAndAdvance(grade: SRSGrade) {
        vm.grade(grade)
        if (isLastCard) {
            val roundEnded = onRoundEnded
            if (roundEnded != null) {
                logEnd(finished = true)
                TestSessionViewModel.clearPersistedProgress(session.kind)
                roundEnded(vm.verses.mapNotNull { vm.sessionGrades[it.id] }, missedCards())
            } else {
                finishSession()
            }
        } else {
            moveProgrammatically { vm.goForward() }
        }
    }

    private fun missedCards(): List<Verse> {
        val soon = Date.now().addingTimeInterval(SRSQueueBuilder.learnAhead)
        return vm.verses.filter { verse ->
            val state = SRSStore.shared.state(verse) ?: return@filter false
            state.phase == SRSPhase.learning && state.due <= soon
        }
    }

    fun undoLastGrade() {
        val index = vm.undoLastGrade() ?: return
        undoCount += 1
        HapticEngine.light()
        moveProgrammatically(refocus = false) { vm.currentIndex = index }
    }

    private val analyticsKind: StudySessionKind
        get() = when (session.kind) {
            SessionKind.srs -> if (session.round > 1) StudySessionKind.extraRound else StudySessionKind.review
            SessionKind.custom -> StudySessionKind.quiz
            SessionKind.pack -> StudySessionKind.practice
        }

    fun logStart() {
        if (loggedStart) return
        loggedStart = true
        activeTime = ActiveTimer()
        val screen = when {
            isReview -> AnalyticsScreen.dailyReview
            session.kind == SessionKind.pack -> AnalyticsScreen.practice
            else -> AnalyticsScreen.quizSession
        }
        Analytics.log(AnalyticsEvent.ScreenViewed(screen))
        var newCards = 0
        var learningCards = 0
        var dueCards = 0
        var knownCards = 0
        if (isReview) {
            for (verse in vm.verses) {
                when (SRSStore.shared.state(verse)?.phase) {
                    null -> if (LearningStore.shared.isLearnt(verse)) knownCards += 1 else newCards += 1
                    SRSPhase.learning -> learningCards += 1
                    SRSPhase.review -> dueCards += 1
                }
            }
        }
        Analytics.log(
            AnalyticsEvent.SessionStarted(
                StudySessionStart(
                    kind = analyticsKind,
                    cards = vm.verses.size,
                    studyMode = studyMode.rawValue,
                    hardMode = AppDefaults.standard.getBool("hardMode") ?: false,
                    newCards = newCards,
                    learningCards = learningCards,
                    dueCards = dueCards,
                    knownCards = knownCards,
                    reviewedToday = if (isReview) SRSStore.shared.reviewedToday() else 0,
                    pack = if (session.kind == SessionKind.pack) vm.verses.firstOrNull()?.packName else null,
                ),
            ),
        )
    }

    fun logEnd(finished: Boolean) {
        if (!loggedStart || loggedEnd) return
        loggedEnd = true
        val grades = vm.verses.mapNotNull { vm.sessionGrades[it.id] }
        Analytics.log(
            AnalyticsEvent.SessionEnded(
                StudySessionSummary(
                    kind = analyticsKind,
                    finished = finished,
                    cards = vm.verses.size,
                    cardsDone = if (isReview) grades.size else vm.completedCount,
                    seconds = activeTime.elapsed(),
                    again = grades.count { it == SRSGrade.again },
                    hard = grades.count { it == SRSGrade.hard },
                    good = grades.count { it == SRSGrade.good },
                    easy = grades.count { it == SRSGrade.easy },
                    peeks = vm.peekedVerseIds.size,
                    undos = undoCount,
                    mistakes = -vm.sessionScore,
                    usedVoice = usedVoice,
                ),
            ),
        )
    }
}
