import SwiftUI

struct TestSessionView: View {

    // MARK: - State

    @StateObject private var vm:     TestSessionViewModel
    @StateObject private var speech: SpeechRecognizer = SpeechRecognizer()
    @ObservedObject private var learning = LearningStore.shared

    @AppStorage("studyMode") private var studyMode: StudyMode = .firstLetter

    @FocusState private var isInputFocused: Bool
    @FocusState private var submitFocus:    SubmitField?

    @State private var dragOffset:   CGSize  = .zero
    @State private var isCardFlying          = false
    @State private var flyDirection: Int     = 0
    @State private var shakeOffset:  CGFloat = 0
    @State private var speechTarget: SubmitField = .title
    @State private var isScrubbing           = false
    @State private var isPeeking             = false
    /// Verses the user revealed via hold-to-peek this session — a failed recall
    /// that pulls the grade suggestion down to "Again".
    @State private var peekedVerseIds:       Set<Int> = []
    @State private var showVerseSelector     = false
    /// Pending "marked complete" undo prompt.
    @State private var undoToastState:       UndoToastState?

    // SRS session bookkeeping. Lets the user swipe back to an already-graded
    // card and change the grade without compounding (regrade computes from
    // the captured pre-grade state, not the already-advanced one).
    @State private var sessionGrades:    [Int: SRSGrade]      = [:]
    /// Difficulty the user has selected (filled) for the current card but not yet
    /// confirmed — lets them change it before committing. Reset on each new card.
    @State private var pendingGrade:     SRSGrade?            = nil
    @State private var preGradeStates:   [Int: SRSCardState]  = [:]
    /// Verse ids in the order they were graded — the Anki-style Undo stack. SRS
    /// review runs forward-only; Undo pops the last grade and returns to that card.
    @State private var gradedOrder:      [Int]                = []
    /// Verses whose Good/Easy grade auto-advanced the learning cursor, so Undo can
    /// put the cursor back.
    @State private var autoLearntIds:    Set<Int>             = []

    @Environment(\.dismiss) private var dismiss

    let onSessionEnded: (() -> Void)?
    let sessionKind:    SessionKind

    // MARK: - Init

    init(session: TestSession, onSessionEnded: (() -> Void)? = nil) {
        _vm = StateObject(wrappedValue: TestSessionViewModel(verses: session.verses))
        self.onSessionEnded = onSessionEnded
        self.sessionKind    = session.kind
    }

    /// Header title matches where the session was launched: the SRS daily flow
    /// reads "Review", the user-picked self-test from the Quiz tab reads "Quiz".
    private var sessionTitle: String {
        sessionKind == .srs ? "Review" : "Quiz"
    }

    /// A quiz is drawn from packs the user hand-picked, so naming the pack on the
    /// card hands them half the answer. The SRS deck is dealt to them and mixes
    /// everything they're learning, so there the label is orientation, not a clue.
    private var showsCardLabel: Bool { sessionKind == .srs }

    // MARK: - Body

    var body: some View {
        GeometryReader { geo in
            let cardWidth  = geo.size.width - 2 * AppLayout.screenMargin
            let cardHeight = cardWidth * 3.0 / 5.0

            VStack(spacing: 0) {
                topBar

                // Per-verse progress dots — only in Entire Verse (submit) mode
                if studyMode == .submit {
                    progressDots
                        .padding(.horizontal, AppLayout.screenMargin)
                        .padding(.top, 6)
                        .padding(.bottom, 2)
                }

                GeometryReader { area in
                    let cardH = max(cardHeight, min(cardWidth * 0.82, area.size.height - 12))
                    ZStack {
                        cardStack
                            .frame(width: cardWidth, height: cardH)
                        if isPeeking, let verse = vm.currentVerse {
                            PeekOverlayCard(
                                verse: verse,
                                cardLabel: vm.cardLabel(for: verse),
                                width: cardWidth,
                                height: cardH,
                                isPeeking: isPeeking,
                                showCardLabel: showsCardLabel
                            )
                            .allowsHitTesting(false)
                            .transition(.opacity)
                            .zIndex(100)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                // Anki-style review is forward-only — you advance by grading, and
                // Undo (top bar) reverts the last grade — so it has no scrubber.
                // Quiz keeps free navigation.
                if vm.verses.count > 1, sessionKind != .srs {
                    scrubberRow
                        .padding(.horizontal, AppLayout.screenMargin)
                        .padding(.bottom, 6)
                }

                bottomControls
            }
        }
        .background(Color(.systemGroupedBackground))
        .undoToast($undoToastState)
        .speechErrorAlert(speech)
        .onChange(of: vm.currentIndex) { _, _ in
            vm.clearInputs()
            vm.resetDictation()
            pendingGrade = nil   // each card starts from its own suggested difficulty
            if speech.isListening { speech.stopListening() }
            if isScrubbing {
                // Don't dismiss the keyboard — just point focus at the title field
                // of the new card. If it was already closed, leave it closed.
                if submitFocus != nil { submitFocus = .title }
                // isInputFocused (non-submit modes) needs no change — same TextField stays focused.
            } else {
                refocusIfNeeded()
            }
        }
        .onChange(of: speech.transcript) { _, text in
            guard speech.isListening else { return }
            // Entire Verse collects the transcript as free text to submit; the two
            // typing modes match it word by word against the hidden verse instead.
            if studyMode == .submit {
                switch speechTarget {
                case .title: vm.titleInput = text
                case .verse: vm.verseInput = text
                }
            } else {
                vm.processDictation(text)
            }
        }
        .onChange(of: isPeeking) { _, peeking in
            // Revealing the answer is a failed recall — remember it so the grade
            // suggestion reflects that the user needed to look.
            if peeking, let verse = vm.currentVerse { peekedVerseIds.insert(verse.id) }
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

    /// A text field is focused (keyboard up). Used to pin the card below the top
    /// bar so the verse title isn't covered when the keyboard pushes content up.
    // MARK: - Top Bar

    private var topBar: some View {
        ZStack {
            VStack(spacing: 2) {
                Text(sessionTitle)
                    .font(.system(size: 15, weight: .semibold))
                    .lineLimit(1)
                // Position and progress on one line, rather than two counters in
                // the same two-line slot. Read/Review already puts position in its
                // subtitle ("5 of 60"), so this matches it — and the standalone
                // "1 / 245" under the scrubber goes away, since the thumb already
                // says roughly where you are and the text was the redundant half.
                Text("\(vm.currentIndex + 1) of \(vm.verses.count) · \(vm.completedCount) done")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.secondary)
                    .lineLimit(1)
                    .animation(AppMotion.content, value: vm.completedCount)
            }

            HStack {
                Button {
                    if speech.isListening { speech.stopListening() }
                    dismiss()
                } label: {
                    Image(systemName: "xmark").studyChromeCircleButton()
                }
                .accessibilityLabel("Close session")

                // Undo the last grade — the forward-only review's back affordance.
                // Kept on the leading edge so it stays reachable even while the
                // keyboard is up on the next card.
                if sessionKind == .srs {
                    Button { undoLastGrade() } label: {
                        Image(systemName: "arrow.uturn.backward").studyChromeCircleButton()
                    }
                    .disabled(gradedOrder.isEmpty)
                    .opacity(gradedOrder.isEmpty ? 0.3 : 1)
                    .accessibilityLabel("Undo last rating")
                }

                Spacer()

                // While typing, a guaranteed-visible "Done" replaces the trailing
                // controls (the keyboard's own toolbar item is unreliable here).
                if isInputFocused || submitFocus != nil {
                    Button {
                        isInputFocused = false
                        submitFocus = nil
                    } label: {
                        Text("Done")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color.accentColor)
                    }
                    .accessibilityLabel("Close keyboard")
                } else {
                    HStack(spacing: 8) {
                        // Verse selector (jump anywhere) — Quiz only; SRS review is
                        // forward-only, so free jumping doesn't belong there.
                        if sessionKind != .srs {
                            Button { showVerseSelector = true } label: {
                                Image(systemName: "list.bullet").studyChromeCircleButton()
                            }
                            .accessibilityLabel("Jump to verse")
                        }
                        // Score display — only in Entire Verse mode
                        if studyMode == .submit { scoreDisplay }
                    }
                }
            }
        }
        .padding(.horizontal, AppLayout.screenMargin)
        .padding(.top, 12)
        .padding(.bottom, 12)
        .animation(AppMotion.control, value: isInputFocused)
        .animation(AppMotion.control, value: submitFocus)
        .sheet(isPresented: $showVerseSelector) {
            verseSelectorSheet
        }
    }

    // MARK: - Verse Selector Sheet

    private var verseSelectorSheet: some View {
        NavigationStack {
            List {
                ForEach(Array(vm.verses.enumerated()), id: \.offset) { i, verse in
                    Button {
                        isScrubbing    = true
                        vm.currentIndex = i
                        showVerseSelector = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + AppMotion.settle) { isScrubbing = false }
                    } label: {
                        HStack(spacing: 10) {
                            Text("\(verse.book) \(verse.reference)")
                                .font(.system(size: 16))
                                .foregroundStyle(i == vm.currentIndex ? Color.accentColor : Color.primary)
                            Spacer()
                            if i == vm.currentIndex {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .listStyle(.plain)
            .navigationTitle("Jump to Verse")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showVerseSelector = false }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private var scoreDisplay: some View {
        Group {
            if vm.isSessionComplete && vm.sessionScore == 0 {
                Text("✓")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.green)
                    .frame(width: 36, height: 36)
                    .background(Color(.secondarySystemBackground), in: Circle())
            } else if vm.sessionScore < 0 {
                Text("\(vm.sessionScore)")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.red)
                    .frame(width: 36, height: 36)
                    .background(Color(.secondarySystemBackground), in: Circle())
            } else {
                Text("0")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .frame(width: 36, height: 36)
                    .background(Color(.secondarySystemBackground), in: Circle())
            }
        }
        .animation(AppMotion.content, value: vm.sessionScore)
    }

    // MARK: - Progress Dots
    //
    // One dot per verse. Size adapts so all dots fit in available width.
    // Gray = not yet done, green = done perfect, orange/red = done with mistakes (submit only).

    /// One dot per verse for short sessions; a continuous bar once dots would
    /// shrink below legibility (≈ sub-3pt). Both convey position/progress; the
    /// bar additionally carries a VoiceOver value.
    @ViewBuilder
    private var progressDots: some View {
        if vm.verses.count > 24 {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.secondary.opacity(0.2))
                    Capsule()
                        .fill(Color.accentColor)
                        .frame(width: max(6, geo.size.width * CGFloat(vm.completedCount) / CGFloat(max(1, vm.verses.count))))
                        .animation(AppMotion.movement, value: vm.completedCount)
                }
            }
            .frame(height: 6)
            .accessibilityElement()
            .accessibilityLabel("Session progress")
            .accessibilityValue("\(vm.completedCount) of \(vm.verses.count) done")
        } else {
            GeometryReader { geo in
                let count   = vm.verses.count
                let spacing = CGFloat(3)
                let maxDot  = CGFloat(8)
                let dotSize = min(maxDot, (geo.size.width - spacing * CGFloat(max(1, count - 1))) / CGFloat(max(1, count)))

                HStack(spacing: spacing) {
                    ForEach(Array(vm.verses.enumerated()), id: \.offset) { i, verse in
                        let submitted = vm.hasSubmitted(verse)
                        let correct   = vm.submitResults[verse.id]?.isAllCorrect == true
                        let isCurrent = i == vm.currentIndex

                        Circle()
                            .fill(dotColor(submitted: submitted, correct: correct))
                            .frame(width: dotSize, height: dotSize)
                            .scaleEffect(isCurrent ? 1.4 : 1.0)
                            .animation(AppMotion.control, value: isCurrent)
                            .animation(AppMotion.content, value: submitted)
                            .animation(AppMotion.content, value: correct)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .frame(height: 12)
            .accessibilityElement()
            .accessibilityLabel("Session progress")
            .accessibilityValue("\(vm.completedCount) of \(vm.verses.count) done")
        }
    }

    private func dotColor(submitted: Bool, correct: Bool) -> Color {
        guard submitted else { return Color.secondary.opacity(0.25) }
        return correct ? .green : .red
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
                // Always allow swipe (the gesture filters vertical drags so editor scroll/selection still work).
                // Card-wide tap-to-focus is gated to non-submit modes only — in submit mode it would force focus
                // to the title field even when the user taps the verse TextEditor.
                let swipingCard = frontCard.simultaneousGesture(swipeGesture)
                if studyMode == .submit {
                    swipingCard
                } else {
                    swipingCard
                        // Simultaneous so title/verse (underscore) taps still reach FlashcardView's section handler,
                        // while taps elsewhere on the card still bring up the keyboard.
                        .simultaneousGesture(
                            TapGesture().onEnded {
                                guard !vm.isCardComplete && !vm.isSessionComplete else { return }
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

        // Submit UI on the front card; empty submit surface on the card directly above or below
        // (forward / back swipe) when it has no graded result yet — matches becoming current and
        // avoids masked underscore flash. Never show a stored diff on a non-interactive card.
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
            // Submit stack peeks: never read mode behind the front card (full verse = answer).
            let forceMaskedPeek = studyMode == .submit && !interactive
                && ((isAhead && (!isDirectNext || hasResult)) || isBehind)
            let titleRev = forceMaskedPeek ? 0 : vm.revealedCount(for: verse.id, section: .title)
            let verseRev = forceMaskedPeek ? 0 : vm.revealedCount(for: verse.id, section: .verse)
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
            // The count moved to the nav bar subtitle.
            showPositionLabel: false,
            trackHeight: 34,
            onScrubIndexChange: { vm.persistSession() },
            onStepBack: {
                isScrubbing = true
                vm.goBackward()
                HapticEngine.light()
                DispatchQueue.main.asyncAfter(deadline: .now() + AppMotion.settle) { isScrubbing = false }
            },
            onStepForward: {
                isScrubbing = true
                vm.goForward()
                HapticEngine.light()
                DispatchQueue.main.asyncAfter(deadline: .now() + AppMotion.settle) { isScrubbing = false }
            }
        )
    }

    // MARK: - Bottom Controls

    /// In an SRS review the session isn't "done" until every card has been
    /// **graded** — not merely revealed. `vm.isSessionComplete` flips true as soon
    /// as the last card is *revealed* (first-letter / full-word) or entered
    /// *perfectly* (submit); showing the summary then would skip the final card's
    /// grading buttons and the card would never get scheduled. Quiz sessions have
    /// no grading, so they keep the plain reveal-based completion.
    private var showSessionSummary: Bool {
        if sessionKind == .srs {
            return vm.verses.allSatisfy { sessionGrades[$0.id] != nil }
        }
        return vm.isSessionComplete
    }

    private var bottomControls: some View {
        VStack(spacing: 12) {
            if showSessionSummary {
                sessionCompletePanel
            } else {
                cardControlBand
            }

            // Quiz (non-SRS) has no grade to key off, so completing the current
            // stopped verse here still offers a manual "Mark as Complete". In SRS a
            // Good/Easy grade advances the cursor automatically (see gradeAndAdvance).
            if !showSessionSummary, sessionKind != .srs, vm.isCardComplete,
               let v = vm.currentVerse, learning.isCurrent(v) {
                markLearntRow(for: v)
            }

            // SRS: pick a difficulty above (changeable), then confirm to schedule the
            // card and move on. Confirming the last card ends the session. Gated on
            // `isCardAnswered` (not `isCardComplete`) so it tracks the grading selector
            // exactly — in submit mode a *wrong* answer is answered-but-not-complete,
            // and still needs a Confirm to commit the grade.
            if !showSessionSummary, sessionKind == .srs, vm.isCardAnswered,
               let verse = vm.currentVerse {
                // `currentSelection` is nil only in first-letter mode before the user
                // picks (no auto-suggestion) — keep Confirm disabled until they do.
                let pick = currentSelection(for: verse)
                Button {
                    guard let grade = pick else { return }
                    pendingGrade = nil
                    gradeAndAdvance(grade)
                } label: {
                    Text(pick == nil ? "Pick a difficulty to continue" : "Confirm")
                        .font(.headline).frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(.accentColor)
                .disabled(pick == nil)
            } else if !showSessionSummary, sessionKind != .srs,
                      vm.completedCount == vm.verses.count {
                // Quiz (non-SRS) has no grading, so it keeps an explicit end button.
                Button {
                    endSession()
                } label: {
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

    /// Active-card controls (every state except the finished-session summary),
    /// with the always-present hold-to-peek button anchored to the leading edge
    /// so it stays put regardless of which controls are showing.
    private var cardControlBand: some View {
        HStack(alignment: .center, spacing: StudyControlMetrics.rowSpacing) {
            // Peeking only makes sense while the verse is still hidden — once the
            // card is answered (revealed, or submitted right or wrong) the text is
            // already on the card, so drop the button.
            if !vm.isCardAnswered {
                PeekHoldButton(isPeeking: $isPeeking)
                    .transition(.opacity)
            }
            Group {
                if vm.isCardComplete {
                    if sessionKind == .srs, let verse = vm.currentVerse {
                        SRSGradingButtons(
                            state:     displayState(for: verse),
                            suggested: suggestedGradeFor(verse),
                            selected:  currentSelection(for: verse),
                            now:       Date(),
                            onPick:    { pendingGrade = $0 }
                        )
                    } else {
                        nextButton
                    }
                } else if studyMode == .submit {
                    submitControls
                } else {
                    inputField
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var nextButton: some View {
        Button {
            isScrubbing = true
            vm.goForward()
            HapticEngine.light()
            DispatchQueue.main.asyncAfter(deadline: .now() + AppMotion.settle) {
                isScrubbing = false
                refocusIfNeeded()
            }
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
            .roundedRect(StudyControlMetrics.cornerRadius)
        }
        .disabled(vm.currentIndex >= vm.verses.count - 1)
        .opacity(vm.currentIndex >= vm.verses.count - 1 ? 0.5 : 1)
    }

    /// When the card under review is the current stopped verse, let the user mark
    /// it learnt right here — advancing the Home cursor. The SRS grade still
    /// schedules the card and moves on, so this never replaces grading; once
    /// tapped, the cursor moves and the row hides itself.
    private func markLearntRow(for verse: Verse) -> some View {
        Button {
            learning.markLearnt(verse)
            HapticEngine.success()
            // One tap, right under the card, and it advances the learning cursor —
            // give it a moment's grace before it's final.
            undoToastState = UndoToastState(message: "Marked as complete") {
                learning.unmarkLearnt(verse)
            }
        } label: {
            Label("Complete", systemImage: "checkmark.circle.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.white)
                .frame(maxWidth: .infinity).padding(.vertical, 12)
                .background(Color.green)
                .roundedRect(StudyControlMetrics.cornerRadius)
        }
        .accessibilityLabel("Mark current verse as complete")
        .transition(.scale.combined(with: .opacity))
    }

    // MARK: - Session Complete Panel

    private var sessionCompletePanel: some View {
        VStack(spacing: 16) {
            Image(systemName: vm.sessionScore == 0 ? "checkmark.seal.fill" : "checkmark.circle.fill")
                .font(.system(size: 40))
                .foregroundStyle(vm.sessionScore == 0 ? Color.green : Color.accentColor)
                .symbolEffect(.bounce, options: .nonRepeating)

            Text("Session Complete!")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Color.primary)

            // Mistakes are only tracked in Entire Verse (submit) mode, so a
            // score is meaningless in first-letter / full-word sessions.
            if studyMode == .submit {
                if vm.sessionScore == 0 {
                    Text("Perfect!")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color.green)
                } else {
                    Text("Score: \(vm.sessionScore)")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color.red)
                }

                Text("\(vm.perfectCount) of \(vm.verses.count) perfect")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.secondary)
            } else {
                Text("\(vm.verses.count) verses reviewed")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.secondary)
            }

            HStack(spacing: 12) {
                Button {
                    vm.resetAllProgress()
                } label: {
                    Text("Try Again")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color(.secondarySystemGroupedBackground))
                        .roundedRect(StudyControlMetrics.cornerRadius)
                }

                Button {
                    vm.clearProgress()
                    onSessionEnded?()
                    dismiss()
                } label: {
                    Text("Done")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.accentColor)
                        .roundedRect(StudyControlMetrics.cornerRadius)
                }
            }
        }
        .transition(.scale.combined(with: .opacity))
    }

    // MARK: - Submit Controls

    private var submitControls: some View {
        let hasResult = vm.currentVerse.flatMap { vm.submitResults[$0.id] } != nil
        return Group {
            if hasResult {
                if sessionKind == .srs, let verse = vm.currentVerse {
                    SRSGradingButtons(
                        state:     displayState(for: verse),
                        suggested: suggestedGradeFor(verse),
                        selected:  currentSelection(for: verse),
                        now:       Date(),
                        onPick:    { pendingGrade = $0 }
                    )
                } else {
                    HStack(spacing: 10) {
                        Button { vm.retrySubmit() } label: {
                            Label("Try Again", systemImage: "arrow.counterclockwise")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Color.primary)
                                .frame(maxWidth: .infinity).padding(.vertical, 12)
                                .background(Color(.secondarySystemGroupedBackground))
                                .roundedRect(StudyControlMetrics.cornerRadius)
                        }
                        Button {
                            isScrubbing = true
                            vm.goForward()
                            HapticEngine.light()
                            DispatchQueue.main.asyncAfter(deadline: .now() + AppMotion.settle) {
                                isScrubbing = false
                                refocusIfNeeded()
                            }
                        } label: {
                            Text("Next")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Color.white)
                                .frame(maxWidth: .infinity).padding(.vertical, 12)
                                .background(Color.accentColor)
                                .roundedRect(StudyControlMetrics.cornerRadius)
                        }
                        .disabled(vm.currentIndex >= vm.verses.count - 1)
                        .opacity(vm.currentIndex >= vm.verses.count - 1 ? 0.5 : 1)
                    }
                }
            } else {
                HStack(spacing: 10) {
                    Button { toggleSpeech() } label: {
                        Image(systemName: speech.isListening ? "mic.fill" : "mic")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(speech.isListening ? Color.white : Color.primary)
                            .frame(width: StudyControlMetrics.buttonSize, height: StudyControlMetrics.buttonSize)
                            .background(speech.isListening ? Color.red : Color(.secondarySystemGroupedBackground))
                            .roundedRect(StudyControlMetrics.cornerRadius)
                    }
                    .accessibilityLabel(speech.isListening ? "Stop dictation" : "Dictate verse")

                    submitHintButton

                    let isEmpty = vm.titleInput.trimmingCharacters(in: .whitespaces).isEmpty
                              && vm.verseInput.trimmingCharacters(in: .whitespaces).isEmpty
                    Button {
                        if speech.isListening { speech.stopListening() }
                        let result = vm.handleSubmit()
                        submitFocus = nil
                        result?.isAllCorrect == true ? HapticEngine.success() : HapticEngine.error()
                    } label: {
                        Text("Submit")
                            .font(.system(size: 16, weight: .semibold)).foregroundStyle(Color.white)
                            .frame(maxWidth: .infinity).padding(.vertical, 12)
                            .background(isEmpty ? Color(.systemGray3) : Color.accentColor)
                            .roundedRect(StudyControlMetrics.cornerRadius)
                    }
                    .disabled(isEmpty)
                }
            }
        }
    }

    // MARK: - Input Field

    private var inputField: some View {
        HStack(spacing: 10) {
            HStack(spacing: 10) {
                dictationButton

                TextField(studyMode.inputPlaceholder, text: $vm.inputText)
                    .font(.system(size: 17))
                    .focused($isInputFocused)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .onChange(of: vm.inputText) { _, newValue in
                        guard !newValue.isEmpty else { return }
                        switch studyMode {
                        case .firstLetter:
                            let correct = vm.processFirstLetterInput(newValue)
                            DispatchQueue.main.async { vm.inputText = "" }
                            if correct {
                                HapticEngine.light()
                            } else {
                                // Deliberately unscored — a mistyped letter is as likely a
                                // fat finger as a memory lapse. Same for full word below.
                                // See `TestSessionViewModel.recordMistake`.
                                HapticEngine.error(); triggerShake($shakeOffset)
                            }
                        case .fullWord:
                            if vm.processFullWordInput(newValue) {
                                HapticEngine.light()
                            } else if newValue.hasSuffix(" ") {
                                HapticEngine.error(); triggerShake($shakeOffset)
                            }
                        case .submit:
                            break
                        }
                    }
                    // Keyboard dismissal lives in the top bar ("Done") — a single,
                    // reliable affordance instead of a second keyboard-toolbar one.
            }
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground))
            .roundedRect(StudyControlMetrics.cornerRadius)
            .overlay(RoundedRectangle(cornerRadius: StudyControlMetrics.cornerRadius, style: .continuous).stroke(Color(.separator).opacity(0.5), lineWidth: 0.5))
            .offset(x: shakeOffset)

            hintButton
        }
    }

    /// Speak the verse instead of typing it. Takes the slot the decorative
    /// "character.cursor.ibeam" glyph used to occupy inside the text field: the
    /// control row (peek, field, hint) has no width left for a fourth button, and
    /// that glyph was ornament. Entire Verse mode keeps its own larger mic in
    /// `submitControls` — this field only exists in the two typing modes.
    ///
    /// A `Button`, so pressing it doesn't resign the field's first responder and
    /// dismiss the keyboard mid-verse.
    private var dictationButton: some View {
        Button { toggleSpeech() } label: {
            Image(systemName: speech.isListening ? "mic.fill" : "mic")
                .font(.system(size: 16))
                .foregroundStyle(speech.isListening ? Color.red : Color.secondary)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 22, height: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(speech.isListening ? "Stop dictation" : "Dictate verse")
    }

    /// Reveals the next hidden word (verse first, then title). Wrapped in a
    /// Button so the touch is a recognized tap target and doesn't resign the
    /// keyboard's first responder.
    private var hintButton: some View {
        Button {
            vm.revealHint()
            HapticEngine.light()
        } label: {
            Image(systemName: "lightbulb")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.primary)
                .frame(width: StudyControlMetrics.buttonSize, height: StudyControlMetrics.buttonSize)
                .background(Color(.secondarySystemGroupedBackground))
                .roundedRect(StudyControlMetrics.cornerRadius)
        }
        .buttonStyle(.plain)
    }

    /// Entire Verse's hint: types the next word straight into the answer box.
    private var submitHintButton: some View {
        Button {
            fillNextHintWord()
            HapticEngine.light()
        } label: {
            Image(systemName: "lightbulb")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.primary)
                .frame(width: StudyControlMetrics.buttonSize, height: StudyControlMetrics.buttonSize)
                .background(Color(.secondarySystemGroupedBackground))
                .roundedRect(StudyControlMetrics.cornerRadius)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Reveal next word")
    }

    /// Extends whichever box you're in by one word, falling through to the other
    /// once that one is complete. Mirrors `CardStudyView.fillNextHintWord`.
    private func fillNextHintWord() {
        guard let verse = vm.currentVerse else { return }
        let startWithVerse = submitFocus == .verse
        let sections: [(target: String, isTitle: Bool)] = startWithVerse
            ? [(verse.verse, false), (verse.title, true)]
            : [(verse.title, true), (verse.verse, false)]

        for section in sections {
            let typed = section.isTitle ? vm.titleInput : vm.verseInput
            guard let filled = HintFill.next(target: section.target, typed: typed) else { continue }
            if section.isTitle { vm.titleInput = filled } else { vm.verseInput = filled }
            return
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

    private func refocusIfNeeded() {
        guard !vm.isCardComplete && !vm.isSessionComplete else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { focusInput() }
    }

    /// Puts the keyboard back on the answer input, re-arming until it actually takes.
    ///
    /// Completing a card unmounts the input field (grading buttons take its place),
    /// so on the *next* card the field is a freshly inserted view. A lone
    /// `isInputFocused = true` fired while that insertion is still animating in gets
    /// dropped on the floor — which is why the keyboard stayed shut for the rest of
    /// the session once you finished your first verse. Retrying costs nothing when
    /// focus lands on the first attempt (the guard below stops immediately).
    private func focusInput(retriesLeft: Int = 4) {
        studyMode == .submit ? (submitFocus = .title) : (isInputFocused = true)
        guard retriesLeft > 0 else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            // Card finished or session over while we waited — leave the keyboard alone.
            guard !vm.isCardComplete, !vm.isSessionComplete else { return }
            let landed = studyMode == .submit ? (submitFocus != nil) : isInputFocused
            if !landed { focusInput(retriesLeft: retriesLeft - 1) }
        }
    }

    private func toggleSpeech() {
        if speech.isListening {
            speech.stopListening()
        } else {
            speechTarget = submitFocus ?? .title
            // The recognizer restarts its transcript from empty, so the
            // already-matched count has to start over with it.
            vm.resetDictation()
            speech.startListening()
        }
    }

    // MARK: - SRS Helpers

    private func currentSRSState(for verse: Verse) -> SRSCardState {
        SRSStore.shared.state(for: verse)
            ?? SRSCardState.newCard(key: verse.srsKey, now: Date())
    }

    /// State to feed `SRSGradingButtons` for prediction labels.
    /// - First visit: live state from the store.
    /// - Already graded this session: the captured pre-grade state, so the
    ///   "1d / 4d / 12d" labels reflect what each grade WOULD do from the
    ///   original (not the already-advanced) state.
    private func displayState(for verse: Verse) -> SRSCardState {
        if let prior = preGradeStates[verse.id] { return prior }
        if sessionGrades[verse.id] != nil {
            // Brand-new card graded this session — predictions show the
            // fresh-card behavior the user originally saw.
            return SRSCardState.newCard(key: verse.srsKey, now: Date())
        }
        return currentSRSState(for: verse)
    }

    /// The grade currently shown as **selected** (filled) and that Confirm will
    /// commit: the user's explicit pick, else a grade already applied this session
    /// (regrade when scrubbing back), else the suggestion. `nil` only when nothing
    /// is picked and there's no suggestion — first-letter mode before the user
    /// chooses — which keeps Confirm disabled until they pick.
    private func currentSelection(for verse: Verse) -> SRSGrade? {
        pendingGrade ?? sessionGrades[verse.id] ?? suggestedGradeFor(verse)
    }

    /// The algorithm's recommended grade — shown with the "Suggested" tag.
    ///
    /// Only Entire Verse mode produces one, because it's the only mode that scores an
    /// answer: it diffs what you actually wrote against the verse. The two typing
    /// modes reveal the text a word at a time and no longer count slips at all (a
    /// mistyped letter says more about the keyboard than about recall — see
    /// `TestSessionViewModel.recordMistake`), so there's nothing left to base a
    /// recommendation on and the choice is the user's.
    private func suggestedGradeFor(_ verse: Verse) -> SRSGrade? {
        guard studyMode == .submit else { return nil }
        // Peeking at the answer is a failed recall — never suggest better than Again.
        if peekedVerseIds.contains(verse.id) { return .again }

        let allCorrect = vm.submitResults[verse.id]?.isAllCorrect == true
        return suggestedGrade(isAllCorrect: allCorrect, mistakes: vm.mistakes(for: verse.id))
    }

    /// Ends the session. In SRS, any card that's finished but still ungraded — e.g.
    /// the user typed the last card and tapped "End Session" instead of a grade —
    /// gets its suggested grade applied first, so the review actually counts
    /// (schedules the card) instead of silently dropping.
    private func endSession() {
        if sessionKind == .srs {
            var gradedAny = false
            for verse in vm.verses where sessionGrades[verse.id] == nil && vm.isVerseComplete(verse) {
                // First-letter mode has no auto-suggestion; default an ungraded-but-
                // finished card to Good so ending the session still schedules it.
                let grade = suggestedGradeFor(verse) ?? .good
                if let prior = SRSStore.shared.state(for: verse) { preGradeStates[verse.id] = prior }
                SRSStore.shared.grade(verse: verse, grade: grade, alreadyKnew: learning.isLearnt(verse))
                sessionGrades[verse.id] = grade
                gradedAny = true
            }
            if gradedAny { StreakStore.shared.recordToday() }
        }
        vm.clearProgress()
        onSessionEnded?()
        dismiss()
    }

    private func gradeAndAdvance(_ grade: SRSGrade) {
        guard let verse = vm.currentVerse else { return }
        StreakStore.shared.recordToday()   // grading a review verse counts toward the streak

        let firstGradeInSession = (sessionGrades[verse.id] == nil)
        if firstGradeInSession {
            // Capture pre-grade state so a later re-grade can recompute
            // from the original (no compounding). Brand-new cards have no
            // prior state — that case is handled in the regrade branch.
            if let current = SRSStore.shared.state(for: verse) {
                preGradeStates[verse.id] = current
            }
            SRSStore.shared.grade(verse: verse, grade: grade, alreadyKnew: learning.isLearnt(verse))
        } else {
            // Re-grade. Restore from captured prior state, or a fresh
            // new-card state for cards that had no state at session start.
            let prior = preGradeStates[verse.id]
                ?? SRSStore.initialState(key: verse.srsKey, alreadyKnew: learning.isLearnt(verse), now: Date())
            SRSStore.shared.regrade(verse: verse, grade: grade, from: prior)
        }
        if firstGradeInSession { gradedOrder.append(verse.id) }
        sessionGrades[verse.id] = grade

        // Auto-advance the Home learning cursor: a solid recall (Good/Easy) of the
        // verse you're currently learning marks it learnt and moves the cursor on —
        // no manual "Mark as Complete" step. Again/Hard keep you on the verse.
        // Recorded in `autoLearntIds` so Undo can put the cursor back.
        if grade == .good || grade == .easy, learning.isCurrent(verse) {
            learning.markLearnt(verse)
            autoLearntIds.insert(verse.id)
        }

        if vm.currentIndex < vm.verses.count - 1 {
            isScrubbing = true
            vm.goForward()
            DispatchQueue.main.asyncAfter(deadline: .now() + AppMotion.settle) {
                isScrubbing = false
                refocusIfNeeded()
            }
        } else {
            // Last card — close the session.
            vm.clearProgress()
            onSessionEnded?()
            dismiss()
        }
    }

    /// Anki-style Undo: revert the most recent grade (last-in-first-out) and return
    /// to that card so it can be re-rated. Rolls back the card's SRS schedule to its
    /// captured pre-grade state and, if that grade had auto-advanced the learning
    /// cursor, restores the cursor too. The card keeps its revealed/submitted state,
    /// so the grading buttons are right there for a fresh rating.
    private func undoLastGrade() {
        guard let lastId = gradedOrder.last,
              let idx = vm.verses.firstIndex(where: { $0.id == lastId }) else { return }
        let verse = vm.verses[idx]

        // A nil captured state means the card had no schedule before, so revert
        // removes its state — and hands back the consumed new-card slot, unless it
        // was a verse the user already knew (those never took one).
        let prior = preGradeStates[lastId]
        SRSStore.shared.revert(verse: verse, to: prior,
                               wasNewlyIntroduced: prior == nil && !learning.isLearnt(verse))

        if autoLearntIds.remove(lastId) != nil {
            learning.unmarkLearnt(verse)
        }

        sessionGrades.removeValue(forKey: lastId)
        preGradeStates.removeValue(forKey: lastId)
        gradedOrder.removeLast()
        pendingGrade = nil

        // Return to the just-ungraded card to re-rate it.
        isScrubbing = true
        vm.currentIndex = idx
        HapticEngine.light()
        DispatchQueue.main.asyncAfter(deadline: .now() + AppMotion.settle) { isScrubbing = false }
    }
}

