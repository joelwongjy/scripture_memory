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

    @Environment(\.dismiss) private var dismiss

    // MARK: - Swipe Constants

    private enum Swipe {
        static let threshold:         CGFloat = 80
        static let velocityThreshold: CGFloat = 400
        static let flyWidth:          CGFloat = 600
        static let prevCardOffset:    CGFloat = 420
    }

    // MARK: - Init

    init(packName: String, verses: [Verse]) {
        _vm = StateObject(wrappedValue: CardStudyViewModel(packName: packName, verses: verses))
    }

    // MARK: - Body

    var body: some View {
        GeometryReader { geo in
            let cardWidth  = geo.size.width - 40
            let cardHeight = cardWidth * 3.0 / 5.0

            VStack(spacing: 0) {
                topBar

                if isVerticalScroll {
                    verticalScrollCards(cardWidth: cardWidth, cardHeight: cardHeight)
                        .frame(maxHeight: .infinity)
                } else {
                    Spacer(minLength: 12)
                    cardStack
                        .frame(width: cardWidth, height: cardHeight)
                        .frame(maxWidth: .infinity)
                    Spacer(minLength: 12)
                }

                scrubberRow
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)

                bottomControls
            }
        }
        .background(Color(.systemGroupedBackground))
        .onChange(of: vm.isReviewMode) { handleReviewModeChange($0) }
        .onChange(of: vm.currentIndex) { _ in
            vm.clearInputs()
            if speech.isListening { speech.stopListening() }
            refocusIfNeeded()
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
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "xmark").topBarButton()
            }

            Spacer()

            VStack(spacing: 2) {
                Text(vm.packName)
                    .font(.system(size: 15, weight: .semibold))
                    .lineLimit(1)
                Text("\(vm.currentIndex + 1) of \(vm.verses.count)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }

            Spacer()

            HStack(spacing: 6) {
                if vm.canReset {
                    Button { vm.resetCurrentCard() } label: {
                        Image(systemName: "arrow.counterclockwise").topBarButton()
                    }
                }
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        isVerticalScroll.toggle()
                    }
                } label: {
                    Image(systemName: isVerticalScroll ? "rectangle.stack" : "list.bullet.rectangle")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(isVerticalScroll ? .white : .secondary)
                        .frame(width: 32, height: 32)
                        .background(isVerticalScroll ? Color.blue : Color(.tertiarySystemGroupedBackground))
                        .clipShape(Circle())
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
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
                makeCard(verse: verse, interactive: true)
                    .offset(x: goingBack ? 0 : dragOffset.width,
                            y: goingBack ? backwardDragProgress * 12 : dragOffset.height * 0.1)
                    .scaleEffect(goingBack ? 1.0 - backwardDragProgress * 0.05 : 1.0)
                    .rotationEffect(goingBack ? .zero : .degrees(Double(dragOffset.width) * 0.03))
                    .zIndex(2)
                    .gesture(swipeGesture)
            }
            if vm.currentIndex > 0 && dragOffset.width > 0 {
                makeCard(verse: vm.verses[vm.currentIndex - 1], interactive: false)
                    .offset(x: dragOffset.width - Swipe.prevCardOffset)
                    .rotationEffect(.degrees(Double(dragOffset.width - Swipe.prevCardOffset) * 0.02))
                    .zIndex(3)
            }
        }
    }

    // MARK: - Vertical Scroll Mode

    private func verticalScrollCards(cardWidth: CGFloat, cardHeight: CGFloat) -> some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 20) {
                    ForEach(Array(vm.verses.enumerated()), id: \.offset) { index, verse in
                        makeCard(verse: verse, interactive: index == vm.currentIndex)
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
            .onAppear { proxy.scrollTo(vm.currentIndex, anchor: .center) }
            .onChange(of: vm.currentIndex) { newIndex in
                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                    proxy.scrollTo(newIndex, anchor: .center)
                }
            }
        }
    }

    // MARK: - Card Builders

    @ViewBuilder
    private func backgroundCard(at index: Int) -> some View {
        if vm.verses.indices.contains(index) {
            makeCard(verse: vm.verses[index], interactive: false)
        }
    }

    @ViewBuilder
    private func makeCard(verse: Verse, interactive: Bool) -> some View {
        if studyMode == .submit && vm.isReviewMode {
            SubmitCardView(
                verse: verse,
                cardLabel: vm.cardLabel(for: verse),
                titleText: interactive ? $vm.titleInput : .constant(""),
                verseText: interactive ? $vm.verseInput : .constant(""),
                result: vm.submitResults[verse.id],
                focusedField: $submitFocus
            )
        } else {
            FlashcardView(
                verse: verse,
                cardLabel: vm.cardLabel(for: verse),
                isReviewMode: vm.isReviewMode,
                titleRevealedCount: vm.revealedCount(for: verse.id, section: .title),
                verseRevealedCount: vm.revealedCount(for: verse.id, section: .verse),
                activeSection: vm.activeSection,
                onSectionTap: interactive ? { section in
                    withAnimation(.easeOut(duration: 0.2)) { vm.activeSection = section }
                } : nil
            )
        }
    }

    // MARK: - Scrubber

    private var scrubberRow: some View {
        HStack(spacing: 10) {
            Button {
                vm.goBackward(); HapticEngine.light()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(vm.currentIndex > 0 ? .primary.opacity(0.7) : .secondary.opacity(0.25))
                    .frame(width: 28, height: 28)
            }
            .disabled(vm.currentIndex == 0)

            scrubber

            Button {
                vm.goForward(); HapticEngine.light()
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(vm.currentIndex < vm.verses.count - 1 ? .primary.opacity(0.7) : .secondary.opacity(0.25))
                    .frame(width: 28, height: 28)
            }
            .disabled(vm.currentIndex == vm.verses.count - 1)
        }
    }

    private var scrubber: some View {
        GeometryReader { geo in
            let w     = geo.size.width
            let h     = geo.size.height
            let knobX = vm.verses.count > 1
                ? CGFloat(vm.currentIndex) / CGFloat(vm.verses.count - 1) * (w - 14) + 7
                : w / 2
            let fillW = max(4, w * CGFloat(vm.currentIndex + 1) / CGFloat(max(1, vm.verses.count)))

            Capsule().fill(Color(.systemGray5)).frame(height: 4).position(x: w / 2, y: h / 2)
            Capsule().fill(Color.primary.opacity(0.3)).frame(width: fillW, height: 4)
                .position(x: fillW / 2, y: h / 2)
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: vm.currentIndex)
            Circle().fill(Color.primary.opacity(0.55)).frame(width: 14, height: 14)
                .position(x: knobX, y: h / 2)
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: vm.currentIndex)
        }
        .frame(height: 20)
        .overlay {
            GeometryReader { geo in
                Color.clear.contentShape(Rectangle())
                    .gesture(DragGesture(minimumDistance: 0).onChanged { value in
                        let fraction = max(0, min(1, value.location.x / geo.size.width))
                        let newIndex = Int(round(fraction * CGFloat(vm.verses.count - 1)))
                        if newIndex != vm.currentIndex && vm.verses.indices.contains(newIndex) {
                            vm.currentIndex = newIndex
                            HapticEngine.light()
                        }
                    })
            }
        }
    }

    // MARK: - Bottom Controls

    private var bottomControls: some View {
        VStack(spacing: 12) {
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

            Picker("Mode", selection: $vm.isReviewMode) {
                Text("Read").tag(false)
                Text("Review").tag(true)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 24)
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
                    Button {
                        if speech.isListening { speech.stopListening() }
                        let result = vm.handleSubmit()
                        submitFocus = nil
                        result?.isAllCorrect == true ? HapticEngine.success() : HapticEngine.error()
                    } label: {
                        let empty = vm.titleInput.trimmingCharacters(in: .whitespaces).isEmpty
                            && vm.verseInput.trimmingCharacters(in: .whitespaces).isEmpty
                        Text("Submit")
                            .font(.system(size: 16, weight: .semibold)).foregroundColor(.white)
                            .frame(maxWidth: .infinity).padding(.vertical, 12)
                            .background(empty ? Color(.systemGray3) : Color.blue)
                            .cornerRadius(12)
                    }
                    .disabled(vm.titleInput.trimmingCharacters(in: .whitespaces).isEmpty
                        && vm.verseInput.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .padding(.horizontal, 24)
    }

    /// First-letter and full-word modes share this single text field.
    private var inputField: some View {
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
        .padding(.horizontal, 24)
    }

    // MARK: - Swipe Gesture

    private var forwardDragProgress: CGFloat {
        guard dragOffset.width < 0 else { return 0 }
        return min(abs(dragOffset.width) / 150, 1.0)
    }

    private var backwardDragProgress: CGFloat {
        guard dragOffset.width > 0 else { return 0 }
        return min(dragOffset.width / 200, 1.0)
    }

    private var swipeGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                if isCardFlying { commitSwipe() }
                let tx      = value.translation.width
                let canNext = vm.currentIndex < vm.verses.count - 1
                let canPrev = vm.currentIndex > 0
                if (tx < 0 && canNext) || (tx > 0 && canPrev) {
                    dragOffset = value.translation
                } else {
                    dragOffset = CGSize(width: tx * 0.15, height: value.translation.height * 0.15)
                }
            }
            .onEnded { value in
                if isCardFlying { commitSwipe() }
                let vx = value.predictedEndTranslation.width
                if (dragOffset.width < -Swipe.threshold || vx < -Swipe.velocityThreshold),
                   vm.currentIndex < vm.verses.count - 1 {
                    swipeForward()
                } else if (dragOffset.width > Swipe.threshold || vx > Swipe.velocityThreshold),
                          vm.currentIndex > 0 {
                    swipeBackward()
                } else {
                    withAnimation(.spring(response: 0.3, dampingFraction: 1.0)) { dragOffset = .zero }
                }
            }
    }

    private func swipeForward() {
        isCardFlying = true; flyDirection = -1; HapticEngine.light()
        withAnimation(.easeOut(duration: 0.2)) {
            dragOffset = CGSize(width: -Swipe.flyWidth, height: dragOffset.height)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { commitSwipe() }
    }

    private func swipeBackward() {
        isCardFlying = true; flyDirection = 1; HapticEngine.light()
        withAnimation(.easeOut(duration: 0.2)) {
            dragOffset = CGSize(width: Swipe.prevCardOffset, height: 0)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { commitSwipe() }
    }

    private func commitSwipe() {
        guard isCardFlying else { return }
        var t = Transaction(); t.disablesAnimations = true
        withTransaction(t) {
            if flyDirection < 0, vm.currentIndex < vm.verses.count - 1 { vm.currentIndex += 1 }
            else if flyDirection > 0, vm.currentIndex > 0             { vm.currentIndex -= 1 }
            dragOffset = .zero; isCardFlying = false; flyDirection = 0
        }
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

// MARK: - View Helpers

private extension Image {
    /// Standard 32pt circular button for top-bar actions.
    func topBarButton() -> some View {
        self
            .font(.system(size: 14, weight: .bold))
            .foregroundColor(.secondary)
            .frame(width: 32, height: 32)
            .background(Color(.tertiarySystemGroupedBackground))
            .clipShape(Circle())
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
