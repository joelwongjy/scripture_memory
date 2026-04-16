import SwiftUI

struct TestSessionView: View {

    // MARK: - State

    @StateObject private var vm:     TestSessionViewModel
    @StateObject private var speech: SpeechRecognizer = SpeechRecognizer()

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
    @State private var showVerseSelector     = false

    // SRS session bookkeeping. Lets the user swipe back to an already-graded
    // card and change the grade without compounding (regrade computes from
    // the captured pre-grade state, not the already-advanced one).
    @State private var sessionGrades:    [Int: SRSGrade]      = [:]
    @State private var preGradeStates:   [Int: SRSCardState]  = [:]

    @Environment(\.dismiss) private var dismiss

    let onSessionEnded: (() -> Void)?
    let sessionKind:    SessionKind

    // MARK: - Init

    init(session: TestSession, onSessionEnded: (() -> Void)? = nil) {
        _vm = StateObject(wrappedValue: TestSessionViewModel(verses: session.verses))
        self.onSessionEnded = onSessionEnded
        self.sessionKind    = session.kind
    }

    // MARK: - Body

    var body: some View {
        GeometryReader { geo in
            let cardWidth  = geo.size.width - 40
            let cardHeight = cardWidth * 3.0 / 5.0

            VStack(spacing: 0) {
                topBar

                // Per-verse progress dots — only in Entire Verse (submit) mode
                if studyMode == .submit {
                    progressDots
                        .padding(.horizontal, 24)
                        .padding(.top, 6)
                        .padding(.bottom, 2)
                }

                Spacer(minLength: 6)
                ZStack {
                    cardStack
                        .frame(width: cardWidth, height: cardHeight)
                    if isPeeking, let verse = vm.currentVerse {
                        PeekOverlayCard(
                            verse: verse,
                            cardLabel: vm.cardLabel(for: verse),
                            width: cardWidth,
                            height: cardHeight,
                            isPeeking: isPeeking
                        )
                    }
                }
                .frame(width: cardWidth, height: cardHeight)
                .frame(maxWidth: .infinity)
                Spacer(minLength: 6)

                scrubberRow
                    .padding(.horizontal, 20)
                    .padding(.bottom, 6)

                bottomControls
            }
        }
        .background(Color(.systemGroupedBackground))
        .onChange(of: vm.currentIndex) { _, _ in
            vm.clearInputs()
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
            switch speechTarget {
            case .title: vm.titleInput = text
            case .verse: vm.verseInput = text
            }
        }
        .onChange(of: submitFocus) { _, newFocus in
            guard speech.isListening, let newFocus else { return }
            speech.stopListening()
            speechTarget = newFocus
            speech.startListening()
        }
        .task {
            try? await Task.sleep(for: .milliseconds(300))
            focusInput()
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        ZStack {
            VStack(spacing: 2) {
                Text("Review Session")
                    .font(.system(size: 15, weight: .semibold))
                    .lineLimit(1)
                Text("\(vm.completedCount) / \(vm.verses.count) done")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                    .animation(.spring(response: 0.3), value: vm.completedCount)
            }

            HStack {
                Button {
                    if speech.isListening { speech.stopListening() }
                    dismiss()
                } label: {
                    Image(systemName: "xmark").studyChromeCircleButton()
                }

                Spacer()

                HStack(spacing: 8) {
                    // Verse selector dropdown
                    Button { showVerseSelector = true } label: {
                        Image(systemName: "list.bullet").studyChromeCircleButton()
                    }
                    // Score display — only in Entire Verse mode
                    if studyMode == .submit { scoreDisplay }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 12)
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
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { isScrubbing = false }
                    } label: {
                        HStack(spacing: 10) {
                            Text("\(verse.book) \(verse.reference)")
                                .font(.system(size: 16))
                                .foregroundColor(i == vm.currentIndex ? .blue : .primary)
                            Spacer()
                            if i == vm.currentIndex {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.blue)
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
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: vm.sessionScore)
    }

    // MARK: - Progress Dots
    //
    // One dot per verse. Size adapts so all dots fit in available width.
    // Gray = not yet done, green = done perfect, orange/red = done with mistakes (submit only).

    private var progressDots: some View {
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
                        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isCurrent)
                        .animation(.spring(response: 0.3,  dampingFraction: 0.8), value: submitted)
                        .animation(.spring(response: 0.3,  dampingFraction: 0.8), value: correct)
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .frame(height: 12)
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
                focusedField: $submitFocus
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
                } : nil
            )
        }
    }

    // MARK: - Scrubber

    private var scrubberRow: some View {
        VerseScrubberRow(
            verseCount: vm.verses.count,
            currentIndex: $vm.currentIndex,
            isScrubbing: $isScrubbing,
            showPositionLabel: true,
            trackHeight: 34,
            onScrubIndexChange: { vm.persistSession() },
            onStepBack: {
                isScrubbing = true
                vm.goBackward()
                HapticEngine.light()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { isScrubbing = false }
            },
            onStepForward: {
                isScrubbing = true
                vm.goForward()
                HapticEngine.light()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { isScrubbing = false }
            }
        )
    }

    // MARK: - Bottom Controls

    private var bottomControls: some View {
        VStack(spacing: 12) {
            if vm.isSessionComplete {
                sessionCompletePanel
            } else if vm.isCardComplete {
                if sessionKind == .srs, let verse = vm.currentVerse {
                    SRSGradingButtons(
                        state:     displayState(for: verse),
                        suggested: gradeButtonHighlight(for: verse),
                        now:       Date(),
                        onPick:    { gradeAndAdvance($0) }
                    )
                } else {
                    // Next button
                    Button {
                        isScrubbing = true
                        vm.goForward()
                        HapticEngine.light()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                            isScrubbing = false
                            refocusIfNeeded()
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.system(size: 18))
                            Text("Next")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14.6)
                        .background(Color(.secondarySystemGroupedBackground))
                        .cornerRadius(12)
                    }
                    .padding(.horizontal, 24)
                    .disabled(vm.currentIndex >= vm.verses.count - 1)
                    .opacity(vm.currentIndex >= vm.verses.count - 1 ? 0.5 : 1)
                }
            } else if studyMode == .submit {
                submitControls
            } else {
                inputField
            }

            if !vm.isSessionComplete && vm.completedCount == vm.verses.count {
                Button {
                    vm.clearProgress()
                    onSessionEnded?()
                    dismiss()
                } label: {
                    Text("End Session")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.blue)
                        .cornerRadius(12)
                }
                .padding(.horizontal, 24)
            }
        }
        .padding(.bottom, 24)
        .padding(.top, 6)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: vm.isCardComplete)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: vm.isSessionComplete)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: vm.completedCount)
    }

    // MARK: - Session Complete Panel

    private var sessionCompletePanel: some View {
        VStack(spacing: 16) {
            Text("Session Complete!")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.primary)

            if vm.sessionScore == 0 {
                Text("Perfect! 🎉")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.green)
            } else {
                Text("Score: \(vm.sessionScore)")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.red)
            }

            Text("\(vm.perfectCount) of \(vm.verses.count) perfect")
                .font(.system(size: 14))
                .foregroundColor(.secondary)

            HStack(spacing: 12) {
                Button {
                    vm.resetAllProgress()
                } label: {
                    Text("Try Again")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color(.secondarySystemGroupedBackground))
                        .cornerRadius(12)
                }

                Button {
                    vm.clearProgress()
                    onSessionEnded?()
                    dismiss()
                } label: {
                    Text("Done")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.blue)
                        .cornerRadius(12)
                }
            }
            .padding(.horizontal, 24)
        }
        .padding(.horizontal, 24)
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
                        suggested: gradeButtonHighlight(for: verse),
                        now:       Date(),
                        onPick:    { gradeAndAdvance($0) }
                    )
                } else {
                    HStack(spacing: 10) {
                        Button { vm.retrySubmit() } label: {
                            Label("Try Again", systemImage: "arrow.counterclockwise")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.primary)
                                .frame(maxWidth: .infinity).padding(.vertical, 12)
                                .background(Color(.secondarySystemGroupedBackground))
                                .cornerRadius(12)
                        }
                        Button {
                            isScrubbing = true
                            vm.goForward()
                            HapticEngine.light()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                                isScrubbing = false
                                refocusIfNeeded()
                            }
                        } label: {
                            Text("Next")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity).padding(.vertical, 12)
                                .background(Color.blue)
                                .cornerRadius(12)
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
                            .foregroundColor(speech.isListening ? .white : .primary)
                            .frame(width: 48, height: 48)
                            .background(speech.isListening ? Color.red : Color(.secondarySystemGroupedBackground))
                            .cornerRadius(12)
                    }
                    PeekEyeButton(isPeeking: $isPeeking)
                    let isEmpty = vm.titleInput.trimmingCharacters(in: .whitespaces).isEmpty
                              && vm.verseInput.trimmingCharacters(in: .whitespaces).isEmpty
                    Button {
                        if speech.isListening { speech.stopListening() }
                        let result = vm.handleSubmit()
                        submitFocus = nil
                        result?.isAllCorrect == true ? HapticEngine.success() : HapticEngine.error()
                    } label: {
                        Text("Submit")
                            .font(.system(size: 16, weight: .semibold)).foregroundColor(.white)
                            .frame(maxWidth: .infinity).padding(.vertical, 12)
                            .background(isEmpty ? Color(.systemGray3) : Color.blue)
                            .cornerRadius(12)
                    }
                    .disabled(isEmpty)
                    if submitFocus != nil {
                        Button { submitFocus = nil } label: {
                            Image(systemName: "keyboard.chevron.compact.down")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.secondary)
                                .frame(width: 48, height: 48)
                                .background(Color(.secondarySystemGroupedBackground))
                                .cornerRadius(12)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Input Field

    private var inputField: some View {
        HStack(spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "character.cursor.ibeam")
                    .foregroundColor(.secondary).font(.system(size: 16))

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
                            if correct { HapticEngine.light() } else { HapticEngine.error(); triggerShake($shakeOffset) }
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
                    // Peek and dismiss live in the keyboard toolbar so touching them
                    // never triggers UIKit's resign-on-touch-outside behaviour.
                    .toolbar {
                        ToolbarItemGroup(placement: .keyboard) {
                            Button {
                                isPeeking.toggle()
                                if isPeeking { HapticEngine.light() }
                            } label: {
                                Image(systemName: isPeeking ? "eye.fill" : "eye")
                                    .foregroundStyle(isPeeking ? AnyShapeStyle(Color.blue) : AnyShapeStyle(.secondary))
                            }
                            Spacer()
                            Button { isInputFocused = false } label: {
                                Image(systemName: "keyboard.chevron.compact.down")
                            }
                        }
                    }
            }
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(.separator).opacity(0.5), lineWidth: 0.5))
            .offset(x: shakeOffset)
        }
        .padding(.horizontal, 24)
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
                let canNext = vm.currentIndex < vm.verses.count - 1
                let canPrev = vm.currentIndex > 0
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
                if isHorizontal,
                   (dragOffset.width < -CardSwipeConfig.threshold || vx < -CardSwipeConfig.velocityThreshold),
                   vm.currentIndex < vm.verses.count - 1 {
                    swipeForward()
                } else if isHorizontal,
                          (dragOffset.width > CardSwipeConfig.threshold || vx > CardSwipeConfig.velocityThreshold),
                          vm.currentIndex > 0 {
                    swipeBackward()
                } else {
                    withAnimation(.spring(response: 0.3, dampingFraction: 1.0)) { dragOffset = .zero }
                    // Drag started (dismissing keyboard) but wasn't committed — restore focus.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { refocusIfNeeded() }
                }
            }
    }

    private func swipeForward() {
        isScrubbing = true
        isCardFlying = true
        flyDirection = -1
        HapticEngine.light()
        withAnimation(.easeOut(duration: 0.2)) {
            dragOffset = CGSize(width: -CardSwipeConfig.flyWidth, height: dragOffset.height)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { commitSwipe() }
    }

    private func swipeBackward() {
        isScrubbing = true
        isCardFlying = true
        flyDirection = 1
        HapticEngine.light()
        withAnimation(.easeOut(duration: 0.2)) {
            dragOffset = CGSize(width: CardSwipeConfig.prevCardOffset, height: 0)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { commitSwipe() }
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
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { isScrubbing = false }
    }

    // MARK: - Focus & Speech

    private func refocusIfNeeded() {
        guard !vm.isCardComplete && !vm.isSessionComplete else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { focusInput() }
    }

    private func focusInput() {
        studyMode == .submit ? (submitFocus = .title) : (isInputFocused = true)
    }

    private func toggleSpeech() {
        if speech.isListening {
            speech.stopListening()
        } else {
            speechTarget = submitFocus ?? .title
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

    /// Auto-suggested grade unless the user has already picked one this session,
    /// in which case the previously-picked grade stays highlighted.
    private func gradeButtonHighlight(for verse: Verse) -> SRSGrade {
        sessionGrades[verse.id] ?? suggestedGradeForCurrentCard()
    }

    private func suggestedGradeForCurrentCard() -> SRSGrade {
        guard let verse = vm.currentVerse else { return .good }
        let isAllCorrect: Bool = (studyMode == .submit)
            ? (vm.submitResults[verse.id]?.isAllCorrect == true)
            : true   // Other modes only complete via correct typing.
        return suggestedGrade(isAllCorrect: isAllCorrect, mistakes: vm.mistakes(for: verse.id))
    }

    private func gradeAndAdvance(_ grade: SRSGrade) {
        guard let verse = vm.currentVerse else { return }

        let firstGradeInSession = (sessionGrades[verse.id] == nil)
        if firstGradeInSession {
            // Capture pre-grade state so a later re-grade can recompute
            // from the original (no compounding). Brand-new cards have no
            // prior state — that case is handled in the regrade branch.
            if let current = SRSStore.shared.state(for: verse) {
                preGradeStates[verse.id] = current
            }
            SRSStore.shared.grade(verse: verse, grade: grade)
        } else {
            // Re-grade. Restore from captured prior state, or a fresh
            // new-card state for cards that had no state at session start.
            let prior = preGradeStates[verse.id]
                ?? SRSCardState.newCard(key: verse.srsKey, now: Date())
            SRSStore.shared.regrade(verse: verse, grade: grade, from: prior)
        }
        sessionGrades[verse.id] = grade

        if vm.currentIndex < vm.verses.count - 1 {
            isScrubbing = true
            vm.goForward()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
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
}

