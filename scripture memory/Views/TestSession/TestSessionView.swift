import SwiftUI

/// A Quiz (free navigation, scored in Entire Verse mode) or a daily SRS review
/// (forward-only; each card is rated to schedule it).
struct TestSessionView: View {

    // MARK: - State

    @StateObject private var vm:     TestSessionViewModel
    @StateObject private var speech: SpeechRecognizer = SpeechRecognizer()
    @ObservedObject private var learning = LearningStore.shared

    @AppStorage(StudyMode.storageKey) private var studyMode: StudyMode = .firstLetter

    @FocusState private var isInputFocused: Bool
    @FocusState private var submitFocus:    SubmitField?

    @State private var dragOffset:   CGSize  = .zero
    @State private var isCardFlying          = false
    @State private var flyDirection: Int     = 0
    @State private var speechTarget: SubmitField = .title
    @State private var isScrubbing           = false
    @State private var isPeeking             = false
    /// Pending "marked complete" undo prompt.
    @State private var undoToastState:       UndoToastState?

    @Environment(\.dismiss) private var dismiss

    let onSessionEnded: (() -> Void)?
    /// A review's last card was rated: called with this round's ratings and the
    /// cards that went back into learning, in place of closing the screen.
    let onRoundEnded:   ((_ grades: [SRSGrade], _ missed: [Verse]) -> Void)?
    let sessionKind:    SessionKind
    let round:          Int

    // MARK: - Init

    init(session: TestSession, onSessionEnded: (() -> Void)? = nil,
         onRoundEnded: ((_ grades: [SRSGrade], _ missed: [Verse]) -> Void)? = nil) {
        _vm = StateObject(wrappedValue: TestSessionViewModel(verses: session.verses, kind: session.kind))
        self.onSessionEnded = onSessionEnded
        self.onRoundEnded   = onRoundEnded
        self.sessionKind    = session.kind
        self.round          = session.round
    }

    private var isReview: Bool { sessionKind == .srs }

    /// The daily review reads "Review", and "Another look" once it comes back
    /// round to the cards you missed; a self-test picked on the Quiz tab, "Quiz".
    private var sessionTitle: String {
        switch sessionKind {
        case .srs:    return round > 1 ? "Another look" : "Review"
        case .pack:   return "Practice"
        case .custom: return "Quiz"
        }
    }

    /// A quiz is drawn from packs the user picked, so naming the pack on the card
    /// would give half the answer away. The review deck mixes everything, so there
    /// the label is orientation, not a clue.
    private var showsCardLabel: Bool { isReview }

    private var positionLabel: String { "Card \(vm.currentIndex + 1) of \(vm.verses.count)" }

    private var isEditing: Bool { isInputFocused || submitFocus != nil }

    private var isLastCard: Bool { vm.currentIndex >= vm.verses.count - 1 }

    // MARK: - Body

    var body: some View {
        GeometryReader { geo in
            // Full width on a phone; a centred column on a wide window.
            let columnWidth = min(geo.size.width, AppLayout.studyColumnWidth)
            let cardWidth   = columnWidth - 2 * AppLayout.screenMargin
            let cardHeight  = cardWidth / AppLayout.cardAspect

            VStack(spacing: 0) {
                topBar

                GeometryReader { area in
                    let room  = max(120, area.size.height - 12)
                    let cardH = min(max(cardHeight, min(cardWidth * 0.82, room)), room)
                    ZStack {
                        cardStack
                            .frame(width: cardWidth, height: cardH)
                        if isPeeking, let verse = vm.currentVerse {
                            PeekOverlayCard(
                                verse: verse,
                                cardLabel: vm.cardLabel(for: verse),
                                width: cardWidth,
                                height: cardH,
                                showCardLabel: showsCardLabel
                            )
                            .allowsHitTesting(false)
                            .transition(.opacity)
                            .zIndex(100)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                // Review is forward-only (you advance by rating; Undo goes back),
                // so only Quiz gets the scrubber.
                if vm.verses.count > 1, !isReview {
                    scrubberRow
                        .padding(.horizontal, AppLayout.screenMargin)
                        .padding(.bottom, 6)
                }

                bottomControls
            }
            .frame(width: columnWidth)
            .frame(maxWidth: .infinity)
        }
        .background(Color(.systemGroupedBackground))
        .undoToast($undoToastState)
        .speechErrorAlert(speech)
        .tracksStudyScreen()
        .onChange(of: vm.currentIndex) { _, _ in
            vm.clearInputs()
            vm.resetDictation()
            vm.pendingGrade = nil   // each card starts from its own suggestion
            if speech.isListening { speech.stopListening() }
            if isScrubbing {
                // A programmatic move keeps the keyboard as it was; just point
                // Entire Verse's focus at the new card's title.
                if submitFocus != nil { submitFocus = .title }
            } else {
                refocusIfNeeded()
            }
        }
        .onChange(of: speech.transcript) { _, text in
            guard speech.isListening else { return }
            vm.applyDictation(text, to: speechTarget)
        }
        .onChange(of: isPeeking) { _, peeking in
            if peeking, let verse = vm.currentVerse { vm.notePeek(at: verse) }
        }
        .onChange(of: submitFocus) { _, newFocus in
            guard speech.isListening, let newFocus else { return }
            speech.stopListening()
            speechTarget = newFocus
            speech.startListening()
        }
        .task {
            try? await Task.sleep(for: .milliseconds(200))
            focusInput()
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        ZStack {
            VStack(spacing: 1) {
                Text(sessionTitle)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                Text(positionLabel)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.secondary)
                    .monospacedDigit()
                    .lineLimit(1)
                    .contentTransition(.numericText())
                    .animation(AppMotion.content, value: positionLabel)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .floatingGlass(in: Capsule())

            HStack {
                Button {
                    if speech.isListening { speech.stopListening() }
                    dismiss()
                } label: {
                    Image(systemName: "xmark").floatingGlassButton()
                }
                .accessibilityLabel("Close session")

                // Undo the last rating. On the leading edge so it stays reachable
                // while the keyboard is up.
                if isReview {
                    Button(action: undoLastGrade) {
                        Image(systemName: "arrow.uturn.backward").floatingGlassButton()
                    }
                    .disabled(vm.gradedOrder.isEmpty)
                    .opacity(vm.gradedOrder.isEmpty ? 0.3 : 1)
                    .accessibilityLabel("Undo last rating")
                }

                Spacer()

                if isEditing {
                    KeyboardDoneButton {
                        isInputFocused = false
                        submitFocus = nil
                    }
                }
            }
        }
        .padding(.horizontal, AppLayout.screenMargin)
        .padding(.vertical, 8)
        .animation(AppMotion.control, value: isInputFocused)
        .animation(AppMotion.control, value: submitFocus)
    }

    // MARK: - Card Stack

    private var cardStack: some View {
        ZStack {
            if vm.currentIndex + 2 < vm.verses.count {
                backgroundCard(at: vm.currentIndex + 2)
                    .scaleEffect(0.90).offset(y: 24).zIndex(0)
            }
            if vm.currentIndex + 1 < vm.verses.count {
                backgroundCard(at: vm.currentIndex + 1)
                    .scaleEffect(0.95 + 0.05 * forwardDragProgress)
                    .offset(y: 12 * (1 - forwardDragProgress))
                    .zIndex(1)
            }
            if let verse = vm.currentVerse {
                let goingBack = dragOffset.width > 0
                let frontCard = makeCard(verse: verse, verseIndex: vm.currentIndex, interactive: true)
                    .offset(x: goingBack ? 0 : dragOffset.width,
                            y: goingBack ? backwardDragProgress * 12 : dragOffset.height * 0.1)
                    .scaleEffect(goingBack ? 1.0 - backwardDragProgress * 0.05 : 1.0)
                    .rotationEffect(goingBack ? .zero : .degrees(Double(dragOffset.width) * 0.03))
                    .zIndex(2)
                // The swipe gesture ignores vertical drags, so text editing still works.
                let swipingCard = frontCard.simultaneousGesture(swipeGesture)
                if studyMode == .submit {
                    // The card is two text inputs here; a card-wide tap would
                    // steal focus from the verse editor.
                    swipingCard
                } else {
                    swipingCard
                        // Tap anywhere on the card to bring the keyboard back.
                        .simultaneousGesture(
                            TapGesture().onEnded {
                                guard !vm.isCardComplete else { return }
                                focusInput()
                            }
                        )
                }
            }
            if vm.currentIndex > 0 && dragOffset.width > 0 {
                makeCard(verse: vm.verses[vm.currentIndex - 1], verseIndex: vm.currentIndex - 1, interactive: false)
                    .offset(x: dragOffset.width - CardSwipeConfig.prevCardOffset)
                    .rotationEffect(.degrees(Double(dragOffset.width - CardSwipeConfig.prevCardOffset) * 0.02))
                    .allowsHitTesting(false)
                    .zIndex(3)
            }
        }
    }

    @ViewBuilder
    private func backgroundCard(at index: Int) -> some View {
        if vm.verses.indices.contains(index) {
            makeCard(verse: vm.verses[index], verseIndex: index, interactive: false)
        }
    }

    @ViewBuilder
    private func makeCard(verse: Verse, verseIndex: Int, interactive: Bool) -> some View {
        let hasResult = vm.submitResults[verse.id] != nil
        let isBehind = verseIndex < vm.currentIndex
        let isAhead = verseIndex > vm.currentIndex
        let isDirectNext = verseIndex == vm.currentIndex + 1
        let isDirectPrev = verseIndex == vm.currentIndex - 1

        // Entire Verse: the front card, and an unanswered neighbour about to swipe
        // in, show the input surface so it doesn't flash masked text on arrival.
        let showSubmitSurface = studyMode == .submit
            && (interactive || (isDirectNext && !hasResult) || (isDirectPrev && !hasResult))

        if showSubmitSurface {
            SubmitCardView(
                verse: verse,
                cardLabel: vm.cardLabel(for: verse),
                titleText: interactive ? $vm.titleInput : .constant(""),
                verseText: interactive ? $vm.verseInput : .constant(""),
                result: interactive ? vm.submitResults[verse.id] : nil,
                focusedField: $submitFocus,
                isCurrentLearning: learning.isCurrent(verse),
                showCardLabel: showsCardLabel
            )
            .allowsHitTesting(interactive)
        } else {
            // Entire Verse: cards behind the front one stay fully masked.
            let forceMasked = studyMode == .submit && !interactive
                && ((isAhead && (!isDirectNext || hasResult)) || isBehind)
            let titleRev = forceMasked ? 0 : vm.revealedCount(for: verse.id, section: .title)
            let verseRev = forceMasked ? 0 : vm.revealedCount(for: verse.id, section: .verse)
            FlashcardView(
                verse: verse,
                cardLabel: vm.cardLabel(for: verse),
                isReviewMode: true,
                titleRevealedCount: titleRev,
                verseRevealedCount: verseRev,
                activeSection: vm.activeSection,
                onSectionTap: interactive ? { section in
                    vm.activeSection = section
                    DispatchQueue.main.async { focusInput() }
                } : nil,
                showCardLabel: showsCardLabel,
                isCurrentLearning: learning.isCurrent(verse)
            )
        }
    }

    // MARK: - Scrubber

    private var scrubberRow: some View {
        VerseScrubberRow(
            verseCount: vm.verses.count,
            currentIndex: $vm.currentIndex,
            isScrubbing: $isScrubbing,
            trackHeight: 34,
            onScrubIndexChange: { vm.saveProgress() },
            onStepBack: {
                HapticEngine.light()
                moveProgrammatically(refocus: false) { vm.goBackward() }
            },
            onStepForward: {
                HapticEngine.light()
                moveProgrammatically(refocus: false) { vm.goForward() }
            }
        )
    }

    // MARK: - Bottom Controls

    /// A review isn't over until every card is rated, not merely revealed;
    /// otherwise the last card would never get its rating buttons.
    private var showSessionSummary: Bool {
        isReview ? vm.allCardsGraded : vm.isSessionComplete
    }

    private var bottomControls: some View {
        VStack(spacing: 12) {
            if showSessionSummary {
                SessionCompletePanel(vm: vm, studyMode: studyMode, onDone: finishSession)
            } else {
                cardControlBand
            }

            // Quiz has no rating to advance the learning cursor, so finishing the
            // current learning verse offers a manual "Complete".
            if !showSessionSummary, !isReview, vm.isCardComplete,
               let v = vm.currentVerse, learning.isCurrent(v) {
                MarkCompleteButton {
                    learning.markLearnt(v)
                    HapticEngine.success()
                    undoToastState = .markedComplete(v, learning: learning)
                }
                .accessibilityLabel("Mark current verse as complete")
                .transition(.scale.combined(with: .opacity))
            }

            // Review: pick a rating above (changeable), then Confirm to schedule
            // the card and move on. Gated on `isCardAnswered` so a wrong Entire
            // Verse answer still needs rating.
            if !showSessionSummary, isReview, vm.isCardAnswered, let verse = vm.currentVerse {
                let pick = vm.currentSelection(for: verse)
                Button {
                    guard let grade = pick, vm.currentVerse?.id == verse.id else { return }
                    gradeAndAdvance(grade)
                } label: {
                    Text(pick == nil ? "Pick a difficulty to continue" : "Confirm")
                        .font(.headline).frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(.accentColor)
                .disabled(pick == nil)
            } else if !showSessionSummary, !isReview, vm.completedCount == vm.verses.count {
                Button(action: finishSession) {
                    Text("End Session").font(.headline).frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(.accentColor)
            }
        }
        .padding(.horizontal, AppLayout.screenMargin)
        .padding(.bottom, 24)
        .padding(.top, 6)
        .animation(AppMotion.content, value: vm.isCardComplete)
        .animation(AppMotion.content, value: vm.isCardAnswered)
        .animation(AppMotion.content, value: vm.isSessionComplete)
        .animation(AppMotion.content, value: vm.completedCount)
    }

    /// The current card's controls. Hold-to-peek sits on the leading edge until
    /// the card is answered.
    private var cardControlBand: some View {
        HStack(alignment: .center, spacing: StudyControlMetrics.rowSpacing) {
            if !vm.isCardAnswered {
                PeekHoldButton(isPeeking: $isPeeking)
                    .transition(.opacity)
            }
            Group {
                if vm.isCardComplete {
                    if isReview, let verse = vm.currentVerse {
                        gradingButtons(for: verse)
                    } else {
                        nextButton
                    }
                } else if studyMode == .submit {
                    submitControls
                } else {
                    RecallInputField(vm: vm, studyMode: studyMode,
                                     isListening: speech.isListening,
                                     isFocused: $isInputFocused,
                                     onToggleSpeech: toggleSpeech)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func gradingButtons(for verse: Verse) -> some View {
        SRSGradingButtons(
            state:     vm.displayState(for: verse),
            suggested: vm.suggestedGradeFor(verse),
            selected:  vm.currentSelection(for: verse),
            now:       Date(),
            onPick:    { vm.pendingGrade = $0 }
        )
    }

    private var nextButton: some View {
        Button {
            HapticEngine.light()
            moveProgrammatically { vm.goForward() }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color.green)
                    .font(.system(size: 18))
                Text("Next")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundStyle(Color.primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14.6)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(Capsule())
        }
        .disabled(isLastCard)
        .opacity(isLastCard ? 0.5 : 1)
    }

    /// Entire Verse mode: mic + Submit before scoring; after, rating buttons in a
    /// review, or Try Again + Next in a quiz.
    @ViewBuilder
    private var submitControls: some View {
        let hasResult = vm.currentVerse.flatMap { vm.submitResults[$0.id] } != nil
        if hasResult {
            if isReview, let verse = vm.currentVerse {
                gradingButtons(for: verse)
            } else {
                HStack(spacing: 10) {
                    TryAgainButton { vm.retrySubmit() }
                    Button {
                        HapticEngine.light()
                        moveProgrammatically { vm.goForward() }
                    } label: {
                        Text("Next").studyActionLabel(foreground: .white, background: .accentColor)
                    }
                    .disabled(isLastCard)
                    .opacity(isLastCard ? 0.5 : 1)
                }
            }
        } else {
            SubmitAnswerRow(
                isListening: speech.isListening,
                canSubmit: vm.hasSubmitInput,
                onToggleSpeech: toggleSpeech,
                onHint: { vm.fillNextHintWord(startingWithVerse: submitFocus == .verse) },
                onSubmit: {
                    if speech.isListening { speech.stopListening() }
                    let result = vm.handleSubmit()
                    submitFocus = nil
                    result?.isAllCorrect == true ? HapticEngine.success() : HapticEngine.error()
                }
            )
        }
    }

    // MARK: - Swipe Gesture

    private var forwardDragProgress: CGFloat {
        CardSwipeConfig.forwardDragProgress(dragWidth: dragOffset.width)
    }

    private var backwardDragProgress: CGFloat {
        CardSwipeConfig.backwardDragProgress(dragWidth: dragOffset.width)
    }

    private var swipeGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                // Skip predominantly-vertical drags so TextEditor scroll/selection in submit mode survives.
                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                if isCardFlying { commitSwipe() }
                // Forward-only SRS review: no swipe navigation (advance by grading,
                // step back via Undo). Quiz keeps free swiping.
                let swipeNav = sessionKind != .srs
                let canNext = swipeNav && vm.currentIndex < vm.verses.count - 1
                let canPrev = swipeNav && vm.currentIndex > 0
                dragOffset = CardSwipeConfig.clampedDragTranslation(
                    value.translation,
                    canGoNext: canNext,
                    canGoPrev: canPrev
                )
            }
            .onEnded { value in
                if isCardFlying { commitSwipe() }
                let isHorizontal = abs(value.translation.width) > abs(value.translation.height)
                let vx = value.predictedEndTranslation.width
                let swipeNav = sessionKind != .srs
                if isHorizontal, swipeNav,
                   (dragOffset.width < -CardSwipeConfig.threshold || vx < -CardSwipeConfig.velocityThreshold),
                   vm.currentIndex < vm.verses.count - 1 {
                    swipeForward()
                } else if isHorizontal, swipeNav,
                          (dragOffset.width > CardSwipeConfig.threshold || vx > CardSwipeConfig.velocityThreshold),
                          vm.currentIndex > 0 {
                    swipeBackward()
                } else {
                    withAnimation(AppMotion.control) { dragOffset = .zero }
                    // Drag started (dismissing keyboard) but wasn't committed — restore focus.
                    DispatchQueue.main.asyncAfter(deadline: .now() + AppMotion.settleShort) { refocusIfNeeded() }
                }
            }
    }

    private func swipeForward() {
        isScrubbing = true
        isCardFlying = true
        flyDirection = -1
        HapticEngine.light()
        withAnimation(AppMotion.control) {
            dragOffset = CGSize(width: -CardSwipeConfig.flyWidth, height: dragOffset.height)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + AppMotion.settleShort) { commitSwipe() }
    }

    private func swipeBackward() {
        isScrubbing = true
        isCardFlying = true
        flyDirection = 1
        HapticEngine.light()
        withAnimation(AppMotion.control) {
            dragOffset = CGSize(width: CardSwipeConfig.prevCardOffset, height: 0)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + AppMotion.settleShort) { commitSwipe() }
    }

    private func commitSwipe() {
        guard isCardFlying else { return }
        var t = Transaction()
        t.disablesAnimations = true
        withTransaction(t) {
            if flyDirection < 0 {
                vm.goForward()
            } else if flyDirection > 0 {
                vm.goBackward()
            }
            dragOffset = .zero
            isCardFlying = false
            flyDirection = 0
        }
        // Refocus immediately so the keyboard comes back before its dismiss animation finishes.
        if !vm.isCardComplete && !vm.isSessionComplete { focusInput() }
        DispatchQueue.main.asyncAfter(deadline: .now() + AppMotion.settle) { isScrubbing = false }
    }

    // MARK: - Focus & Speech

    /// Runs a move the user didn't make by dragging (a button, a jump, a rating).
    /// `isScrubbing` marks it as programmatic until the animation settles; then
    /// the keyboard comes back if there's a card to type.
    private func moveProgrammatically(refocus: Bool = true, _ move: () -> Void) {
        isScrubbing = true
        move()
        DispatchQueue.main.asyncAfter(deadline: .now() + AppMotion.settle) {
            isScrubbing = false
            if refocus { refocusIfNeeded() }
        }
    }

    private func refocusIfNeeded() {
        guard !vm.isCardComplete else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { focusInput() }
    }

    /// Puts the keyboard back on the answer input, retrying until it takes.
    /// Finishing a card unmounts the input, and focusing a field that's still
    /// animating in gets dropped; retrying costs nothing when the first attempt lands.
    private func focusInput(retriesLeft: Int = 4) {
        studyMode == .submit ? (submitFocus = .title) : (isInputFocused = true)
        guard retriesLeft > 0 else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            guard !vm.isCardComplete else { return }
            let landed = studyMode == .submit ? (submitFocus != nil) : isInputFocused
            if !landed { focusInput(retriesLeft: retriesLeft - 1) }
        }
    }

    private func toggleSpeech() {
        if speech.isListening {
            speech.stopListening()
        } else {
            speechTarget = submitFocus ?? .title
            // The recognizer restarts its transcript from empty, so the matched
            // word count starts over with it.
            vm.resetDictation()
            speech.startListening()
        }
    }

    // MARK: - Session Flow

    /// Clears saved progress and closes the session.
    private func finishSession() {
        TestSessionViewModel.clearPersistedProgress(for: sessionKind)
        onSessionEnded?()
        dismiss()
    }

    /// Rates the current card, then moves on (or ends the round after the last card).
    private func gradeAndAdvance(_ grade: SRSGrade) {
        vm.grade(grade)
        if isLastCard {
            if let onRoundEnded {
                TestSessionViewModel.clearPersistedProgress(for: sessionKind)
                onRoundEnded(vm.verses.compactMap { vm.sessionGrades[$0.id] }, missedCards())
            } else {
                finishSession()
            }
        } else {
            moveProgrammatically { vm.goForward() }
        }
    }

    /// Cards this round put back into learning and due again within the
    /// learn-ahead window.
    private func missedCards() -> [Verse] {
        let soon = Date().addingTimeInterval(SRSQueueBuilder.learnAhead)
        return vm.verses.filter { verse in
            guard let state = SRSStore.shared.state(for: verse) else { return false }
            return state.phase == .learning && state.due <= soon
        }
    }

    /// Undo the last rating and go back to that card to rate it again.
    private func undoLastGrade() {
        guard let index = vm.undoLastGrade() else { return }
        HapticEngine.light()
        moveProgrammatically(refocus: false) { vm.currentIndex = index }
    }
}
