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

    @Environment(\.dismiss) private var dismiss

    // MARK: - Swipe Constants

    private enum Swipe {
        static let threshold:         CGFloat = 80
        static let velocityThreshold: CGFloat = 400
        static let flyWidth:          CGFloat = 600
        static let prevCardOffset:    CGFloat = 420
    }

    let onSessionEnded: (() -> Void)?

    // MARK: - Init

    init(session: TestSession, onSessionEnded: (() -> Void)? = nil) {
        _vm = StateObject(wrappedValue: TestSessionViewModel(verses: session.verses))
        self.onSessionEnded = onSessionEnded
    }

    // MARK: - Body

    var body: some View {
        GeometryReader { geo in
            let cardWidth  = geo.size.width - 40
            let cardHeight = cardWidth * 3.0 / 5.0

            VStack(spacing: 0) {
                topBar

                // Mistake dots — only in Entire Verse mode
                if studyMode == .submit {
                    mistakeDots
                        .padding(.top, 8)
                        .padding(.bottom, 4)
                }

                Spacer(minLength: 12)
                cardStack
                    .frame(width: cardWidth, height: cardHeight)
                    .frame(maxWidth: .infinity)
                Spacer(minLength: 12)

                scrubberRow
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)

                bottomControls
            }
        }
        .background(Color(.systemGroupedBackground))
        .onChange(of: vm.currentIndex) { _ in
            vm.clearInputs()
            if speech.isListening { speech.stopListening() }
            if !isScrubbing { refocusIfNeeded() }
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
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { focusInput() }
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        ZStack {
            VStack(spacing: 2) {
                Text("Review Session")
                    .font(.system(size: 15, weight: .semibold))
                    .lineLimit(1)
                let done = vm.completedCount
                Text(done > 0
                     ? "\(done) of \(vm.verses.count) done"
                     : "\(vm.verses.count) cards")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                    .animation(.spring(response: 0.3), value: done)
            }

            HStack {
                Button {
                    if speech.isListening { speech.stopListening() }
                    dismiss()
                } label: {
                    Image(systemName: "xmark").topBarButtonStyle()
                }

                Spacer()

                // Score display — only in Entire Verse mode
                if studyMode == .submit { scoreDisplay }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 12)
    }

    private var scoreDisplay: some View {
        Group {
            if vm.isSessionComplete && vm.sessionScore == 0 {
                Text("✓")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.green)
                    .frame(width: 36, height: 36)
                    .background(.ultraThinMaterial, in: Circle())
            } else if vm.sessionScore < 0 {
                Text("\(vm.sessionScore)")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundColor(.red)
                    .frame(width: 36, height: 36)
                    .background(.ultraThinMaterial, in: Circle())
            } else {
                Text("0")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundColor(.secondary)
                    .frame(width: 36, height: 36)
                    .background(.ultraThinMaterial, in: Circle())
            }
        }
        .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 2)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: vm.sessionScore)
    }

    // MARK: - Mistake Dots

    private var mistakeDots: some View {
        let currentMistakes = vm.currentVerse.map { vm.mistakes(for: $0.id) } ?? 0
        return HStack(spacing: 6) {
            ForEach(0..<5) { i in
                Circle()
                    .fill(i < currentMistakes ? Color.red : Color.clear)
                    .overlay(Circle().strokeBorder(i < currentMistakes ? Color.red : Color.secondary.opacity(0.3), lineWidth: 1.5))
                    .frame(width: 8, height: 8)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: currentMistakes)
            }
        }
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

    @ViewBuilder
    private func backgroundCard(at index: Int) -> some View {
        if vm.verses.indices.contains(index) {
            makeCard(verse: vm.verses[index], interactive: false)
        }
    }

    @ViewBuilder
    private func makeCard(verse: Verse, interactive: Bool) -> some View {
        let hasResult = vm.submitResults[verse.id] != nil
        if studyMode == .submit && (interactive || hasResult) {
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
                isReviewMode: true,
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
        VStack(spacing: 6) {
            HStack(spacing: 10) {
                let canPrev = vm.currentIndex > 0
                let canNext = vm.currentIndex < vm.verses.count - 1

                Button {
                    isInputFocused = false
                    submitFocus    = nil
                    isScrubbing    = true
                    vm.goBackward()
                    HapticEngine.light()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { isScrubbing = false }
                } label: {
                    Image(systemName: "chevron.left").scrubberButtonStyle()
                }
                .disabled(!canPrev)
                .opacity(canPrev ? 1 : 0.3)

                scrubber

                Button {
                    isInputFocused = false
                    submitFocus    = nil
                    isScrubbing    = true
                    vm.goForward()
                    HapticEngine.light()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { isScrubbing = false }
                } label: {
                    Image(systemName: "chevron.right").scrubberButtonStyle()
                }
                .disabled(!canNext)
                .opacity(canNext ? 1 : 0.3)
            }

            // Position indicator
            Text("\(vm.currentIndex + 1) / \(vm.verses.count)")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(.secondary)
        }
    }

    private var scrubber: some View {
        GeometryReader { geo in
            let w     = geo.size.width
            let knobW: CGFloat = 30
            let knobX = vm.verses.count > 1
                ? CGFloat(vm.currentIndex) / CGFloat(vm.verses.count - 1) * (w - knobW)
                : (w - knobW) / 2
            let progress = vm.verses.count > 1 ? CGFloat(vm.currentIndex) / CGFloat(vm.verses.count - 1) : 0
            let fillW = knobW / 2 + progress * (w - knobW)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.ultraThinMaterial)
                    .frame(height: 6)
                Capsule()
                    .fill(Color.primary.opacity(0.2))
                    .frame(width: fillW, height: 6)
                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: vm.currentIndex)
                Circle()
                    .fill(.ultraThinMaterial)
                    .overlay(Circle().strokeBorder(.white.opacity(0.4), lineWidth: 0.5))
                    .shadow(color: .black.opacity(0.18), radius: 6, x: 0, y: 3)
                    .frame(width: knobW, height: knobW)
                    .offset(x: knobX)
                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: vm.currentIndex)
            }
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { value in
                    isScrubbing = true
                    isInputFocused = false
                    submitFocus = nil
                    let fraction = max(0, min(1, value.location.x / w))
                    let newIndex = Int(round(fraction * CGFloat(vm.verses.count - 1)))
                    if newIndex != vm.currentIndex && vm.verses.indices.contains(newIndex) {
                        vm.currentIndex = newIndex
                        HapticEngine.light()
                    }
                }
                .onEnded { _ in
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { isScrubbing = false }
                }
            )
        }
        .frame(height: 44)
    }

    // MARK: - Bottom Controls

    private var bottomControls: some View {
        VStack(spacing: 12) {
            if vm.isSessionComplete {
                sessionCompletePanel
            } else if vm.isCardComplete {
                // Next button
                Button {
                    vm.goForward()
                    HapticEngine.light()
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
                    .padding(.vertical, 12)
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(12)
                }
                .padding(.horizontal, 24)
                .disabled(vm.currentIndex >= vm.verses.count - 1)
                .opacity(vm.currentIndex >= vm.verses.count - 1 ? 0.5 : 1)
            } else if studyMode == .submit {
                submitControls
            } else {
                inputField
            }

            if (isInputFocused || submitFocus != nil) && !vm.isSessionComplete {
                Button {
                    isInputFocused = false
                    submitFocus    = nil
                } label: {
                    Text("Done")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.blue)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color(.secondarySystemGroupedBackground))
                        .cornerRadius(12)
                }
                .padding(.horizontal, 24)
            }
        }
        .padding(.bottom, 24)
        .padding(.top, 12)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: vm.isCardComplete)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: vm.isSessionComplete)
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

    // MARK: - Input Field

    private var inputField: some View {
        HStack(spacing: 10) {
            Image(systemName: "character.cursor.ibeam")
                .foregroundColor(.secondary).font(.system(size: 16))

            TextField(studyMode.testInputPlaceholder, text: $vm.inputText)
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

// MARK: - Image Helpers (local to this file)

private extension Image {
    func topBarButtonStyle() -> some View {
        self
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.secondary)
            .frame(width: 36, height: 36)
            .background(.ultraThinMaterial, in: Circle())
            .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 2)
    }

    func scrubberButtonStyle() -> some View {
        self
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.primary.opacity(0.7))
            .frame(width: 36, height: 36)
            .background(.ultraThinMaterial, in: Circle())
            .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 2)
    }
}

// MARK: - StudyMode Extension

private extension StudyMode {
    var testInputPlaceholder: String {
        self == .fullWord
            ? "Type each word, press space to check..."
            : "Type first letter of each word..."
    }
}
