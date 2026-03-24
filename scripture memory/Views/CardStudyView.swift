import SwiftUI

struct CardStudyView: View {

    // MARK: - State

    @StateObject private var vm:     CardStudyViewModel
    @StateObject private var speech: SpeechRecognizer = SpeechRecognizer()

    @AppStorage("studyMode")       private var studyMode:       StudyMode = .firstLetter
    @AppStorage("isVerticalScroll") private var isVerticalScroll = false

    @FocusState private var isInputFocused: Bool
    @FocusState private var submitFocus:    SubmitField?

    @State private var dragOffset:   CGSize  = .zero
    @State private var isCardFlying          = false
    @State private var flyDirection: Int     = 0
    @State private var shakeOffset:  CGFloat = 0
    @State private var speechTarget: SubmitField = .title
    @State private var isScrubbing           = false

    @Environment(\.dismiss) private var dismiss

    // MARK: - Init

    init(packName: String, verses: [Verse], initialIndex: Int = 0) {
        _vm = StateObject(wrappedValue: CardStudyViewModel(packName: packName, verses: verses, initialIndex: initialIndex))
    }

    // MARK: - Body

    var body: some View {
        GeometryReader { geo in
            let cardWidth  = geo.size.width - 40
            let cardHeight = cardWidth * 3.0 / 5.0

            VStack(spacing: 0) {
                topBar

                // Vertical scroll is for browsing in read mode only.
                // Review mode always shows a single focused card.
                if isVerticalScroll && !vm.isReviewMode {
                    verticalScrollCards(cardWidth: cardWidth, cardHeight: cardHeight)
                        .frame(maxHeight: .infinity)
                } else {
                    Spacer(minLength: 12)
                    cardStack
                        .frame(width: cardWidth, height: cardHeight)
                        .frame(maxWidth: .infinity)
                    Spacer(minLength: 12)
                }

                if !isVerticalScroll || vm.isReviewMode {
                    scrubberRow
                        .padding(.horizontal, 20)
                        .padding(.bottom, 6)
                }

                bottomControls
            }
        }
        .background(Color(.systemGroupedBackground))
        .onChange(of: vm.isReviewMode) { handleReviewModeChange($0) }
        .onChange(of: vm.currentIndex) { _ in
            vm.clearInputs()
            if speech.isListening { speech.stopListening() }
            if isScrubbing {
                if submitFocus != nil { submitFocus = .title }
            } else {
                refocusIfNeeded()
            }
        }
        .onChange(of: speech.transcript) { text in
            guard speech.isListening else { return }
            switch speechTarget {
            case .title: vm.titleInput = text
            case .verse: vm.verseInput = text
            }
        }
        .onChange(of: submitFocus) { newFocus in
            guard speech.isListening, let newFocus else { return }
            speech.stopListening()
            speechTarget = newFocus
            speech.startListening()
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        ZStack {
            // Title is always geometrically centred regardless of button count.
            VStack(spacing: 2) {
                Text(vm.packName)
                    .font(.system(size: 15, weight: .semibold))
                    .lineLimit(1)
                // Hide position counter in vertical-scroll read mode (it's meaningless there)
                if !isVerticalScroll || vm.isReviewMode {
                    Text("\(vm.currentIndex + 1) of \(vm.verses.count)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }

            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "xmark").studyChromeCircleButton()
                }

                Spacer()

                HStack(spacing: 8) {
                    if vm.canReset {
                        Button { vm.resetCurrentCard() } label: {
                            Image(systemName: "arrow.counterclockwise").studyChromeCircleButton()
                        }
                    }
                    Button {
                        vm.toggleShuffle()
                        HapticEngine.light()
                    } label: {
                        Image(systemName: "shuffle")
                            .studyChromeToggle(isOn: vm.isShuffled)
                    }
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            isVerticalScroll.toggle()
                        }
                    } label: {
                        Image(systemName: isVerticalScroll ? "rectangle.stack" : "list.bullet.rectangle")
                            .studyChromeToggle(isOn: isVerticalScroll)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 12)
    }

    // MARK: - Card Stack (horizontal swipe mode)

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
                // Entire Verse (submit) uses TextField + TextEditor — a card-wide drag steals taps from the editor.
                if studyMode == .submit {
                    frontCard
                } else {
                    frontCard.simultaneousGesture(swipeGesture)
                }
            }
            if vm.currentIndex > 0 && dragOffset.width > 0 {
                makeCard(verse: vm.verses[vm.currentIndex - 1], verseIndex: vm.currentIndex - 1, interactive: false)
                    .offset(x: dragOffset.width - CardSwipeConfig.prevCardOffset)
                    .rotationEffect(.degrees(Double(dragOffset.width - CardSwipeConfig.prevCardOffset) * 0.02))
                    .zIndex(3)
            }
        }
    }

    // MARK: - Vertical Scroll Mode

    private func verticalScrollCards(cardWidth: CGFloat, cardHeight: CGFloat) -> some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: true) {
                LazyVStack(spacing: 20) {
                    ForEach(Array(vm.verses.enumerated()), id: \.offset) { index, verse in
                        makeCard(verse: verse, verseIndex: index, interactive: index == vm.currentIndex)
                            .frame(width: cardWidth, height: cardHeight)
                            .id(index)
                            .overlay {
                                if index != vm.currentIndex {
                                    Color.clear.contentShape(Rectangle())
                                        .onTapGesture {
                                            HapticEngine.light()
                                            vm.currentIndex = index
                                        }
                                }
                            }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
            // LazyVStack: yield + delay so row ids exist before scrollTo. `onAppear` runs when returning
            // from review (the scroll view is removed during review, so scroll offset would otherwise reset).
            .onAppear {
                Task { await scrollVerticalReadListToCurrentVerse(proxy: proxy) }
            }
            .onChange(of: vm.currentIndex) { _, newIndex in
                withAnimation(.easeInOut(duration: 0.22)) {
                    proxy.scrollTo(newIndex, anchor: .center)
                }
            }
        }
    }

    /// Scrolls the vertical read list so `currentIndex` is centered (read mode / vertical list only).
    @MainActor
    private func scrollVerticalReadListToCurrentVerse(proxy: ScrollViewProxy) async {
        await Task.yield()
        try? await Task.sleep(for: .milliseconds(72))
        let idx = vm.currentIndex
        withAnimation(.easeInOut(duration: 0.24)) {
            proxy.scrollTo(idx, anchor: .center)
        }
    }

    // MARK: - Card Builders

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

        let showSubmitSurface = studyMode == .submit && vm.isReviewMode
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
            // Submit + Review stack: never read mode behind the front card while peeking (full verse).
            let forceMaskedPeek = studyMode == .submit && vm.isReviewMode && !interactive
                && ((isAhead && (!isDirectNext || hasResult)) || isBehind)
            let titleRev = forceMaskedPeek ? 0 : vm.revealedCount(for: verse.id, section: .title)
            let verseRev = forceMaskedPeek ? 0 : vm.revealedCount(for: verse.id, section: .verse)
            FlashcardView(
                verse: verse,
                cardLabel: vm.cardLabel(for: verse),
                isReviewMode: forceMaskedPeek ? true : vm.isReviewMode,
                titleRevealedCount: titleRev,
                verseRevealedCount: verseRev,
                activeSection: vm.activeSection,
                onSectionTap: interactive && vm.isReviewMode ? { section in
                    withAnimation(.easeOut(duration: 0.2)) { vm.activeSection = section }
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
            showPositionLabel: false,
            trackHeight: 44,
            onScrubIndexChange: nil,
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
        VStack(spacing: 6) {
            if vm.isReviewMode {
                if vm.isCardComplete {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green).font(.system(size: 22))
                        Text("Complete!")
                            .font(.system(size: 17, weight: .semibold)).foregroundColor(.green)
                    }
                    .transition(.scale.combined(with: .opacity))
                    .padding(.bottom, 2)
                } else if studyMode == .submit {
                    submitControls
                } else {
                    inputField
                }
            }

            if !isInputFocused && submitFocus == nil {
                Picker("Mode", selection: $vm.isReviewMode) {
                    Text("Read").tag(false)
                    Text("Review").tag(true)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 24)
                .padding(.top, 12)
            }
        }
        .padding(.bottom, 24)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: vm.isReviewMode)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: vm.isCardComplete)
    }

    /// Submit mode: mic + submit button before scoring, try-again after.
    private var submitControls: some View {
        let hasResult = vm.currentVerse.flatMap { vm.submitResults[$0.id] } != nil
        return Group {
            if hasResult {
                Button { vm.retrySubmit() } label: {
                    Label("Try Again", systemImage: "arrow.counterclockwise")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                        .background(Color(.secondarySystemGroupedBackground))
                        .cornerRadius(12)
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

    /// First-letter and full-word modes share this single text field.
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
                    .onChange(of: vm.inputText) { newValue in
                        guard !newValue.isEmpty else { return }
                        switch studyMode {
                        case .firstLetter:
                            let correct = vm.processFirstLetterInput(newValue)
                            DispatchQueue.main.async { vm.inputText = "" }
                            if correct { HapticEngine.light() } else { HapticEngine.error(); shakeAnimation() }
                        case .fullWord:
                            if vm.processFullWordInput(newValue) {
                                HapticEngine.light()
                            } else if newValue.hasSuffix(" ") {
                                HapticEngine.error(); shakeAnimation()
                            }
                        case .submit:
                            break
                        }
                    }
            }
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(.separator).opacity(0.5), lineWidth: 0.5))
            .offset(x: shakeOffset)

            if isInputFocused {
                Button { isInputFocused = false } label: {
                    Image(systemName: "keyboard.chevron.compact.down")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.secondary)
                        .frame(width: 48, height: 48)
                        .background(Color(.secondarySystemGroupedBackground))
                        .cornerRadius(12)
                }
            }
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
                let vx = value.predictedEndTranslation.width
                if (dragOffset.width < -CardSwipeConfig.threshold || vx < -CardSwipeConfig.velocityThreshold),
                   vm.currentIndex < vm.verses.count - 1 {
                    swipeForward()
                } else if (dragOffset.width > CardSwipeConfig.threshold || vx > CardSwipeConfig.velocityThreshold),
                          vm.currentIndex > 0 {
                    swipeBackward()
                } else {
                    withAnimation(.spring(response: 0.3, dampingFraction: 1.0)) { dragOffset = .zero }
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
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { isScrubbing = false }
    }

    // MARK: - Focus & Speech

    private func handleReviewModeChange(_ reviewing: Bool) {
        if reviewing && !vm.isCardComplete {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { focusInput() }
        } else {
            if speech.isListening { speech.stopListening() }
            isInputFocused = false
            submitFocus    = nil
        }
    }

    private func refocusIfNeeded() {
        guard vm.isReviewMode && !vm.isCardComplete else { return }
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

    // MARK: - Shake Animation

    private func shakeAnimation() {
        withAnimation(.interpolatingSpring(stiffness: 600, damping: 10)) { shakeOffset = 12 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.07) {
            withAnimation(.interpolatingSpring(stiffness: 600, damping: 12)) { shakeOffset = -8 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {
            withAnimation(.spring()) { shakeOffset = 0 }
        }
    }
}

private extension StudyMode {
    var inputPlaceholder: String {
        self == .fullWord
            ? "Type each word, press space to check..."
            : "Type first letter of each word..."
    }
}

#Preview {
    CardStudyView(packName: "5 Assurances", verses: Array(packsNIV84.first?.verses.prefix(5) ?? []))
}
