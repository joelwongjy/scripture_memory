import SwiftUI

struct CardStudyView: View {
    let packName: String
    let verses: [Verse]

    @State private var currentIndex = 0
    @State private var isReviewMode = false
    @State private var titleRevealedCounts: [Int: Int] = [:]
    @State private var verseRevealedCounts: [Int: Int] = [:]
    @State private var activeSection: ReviewSection = .verse
    @State private var inputText = ""
    @State private var titleInput = ""
    @State private var verseInput = ""
    @State private var shakeOffset: CGFloat = 0
    @State private var dragOffset: CGSize = .zero
    @State private var isCardFlying = false
    @State private var flyDirection: Int = 0
    @State private var submitResults: [Int: SubmitResult] = [:]
    @State private var speechTarget: SubmitField = .title
    @StateObject private var speech = SpeechRecognizer()
    @FocusState private var isInputFocused: Bool
    @FocusState private var submitFocus: SubmitField?
    @Environment(\.dismiss) private var dismiss
    @AppStorage("studyMode") private var studyMode = "firstLetter"

    private var currentVerse: Verse? {
        guard !verses.isEmpty, verses.indices.contains(currentIndex) else { return nil }
        return verses[currentIndex]
    }

    private var currentWords: [String] {
        guard let v = currentVerse else { return [] }
        switch activeSection {
        case .title: return v.title.components(separatedBy: " ").filter { !$0.isEmpty }
        case .verse: return v.verse.components(separatedBy: " ").filter { !$0.isEmpty }
        }
    }

    private var currentRevealed: Int {
        guard let v = currentVerse else { return 0 }
        switch activeSection {
        case .title: return titleRevealedCounts[v.id, default: 0]
        case .verse: return verseRevealedCounts[v.id, default: 0]
        }
    }

    private var isCardComplete: Bool {
        guard let v = currentVerse else { return false }
        if studyMode == "submit" {
            guard let result = submitResults[v.id] else { return false }
            return result.isAllCorrect
        }
        let tWords = v.title.components(separatedBy: " ").filter { !$0.isEmpty }
        let vWords = v.verse.components(separatedBy: " ").filter { !$0.isEmpty }
        return titleRevealedCounts[v.id, default: 0] >= tWords.count
            && verseRevealedCounts[v.id, default: 0] >= vWords.count
    }

    private var forwardProgress: CGFloat {
        guard dragOffset.width < 0 else { return 0 }
        return min(abs(dragOffset.width) / 150, 1.0)
    }

    private var backwardProgress: CGFloat {
        guard dragOffset.width > 0 else { return 0 }
        return min(dragOffset.width / 200, 1.0)
    }

    var body: some View {
        GeometryReader { geo in
            let cardWidth = geo.size.width - 40
            let cardHeight = cardWidth * 3.0 / 5.0

            VStack(spacing: 0) {
                topBar

                Spacer(minLength: 12)

                cardStack
                    .frame(width: cardWidth, height: cardHeight)
                    .frame(maxWidth: .infinity)

                Spacer(minLength: 12)

                scrubber
                    .padding(.horizontal, 32)
                    .padding(.bottom, 20)

                bottomControls
            }
        }
        .background(Color(.systemGroupedBackground))
        .onChange(of: isReviewMode) { reviewing in
            if reviewing && !isCardComplete {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    if studyMode == "submit" {
                        submitFocus = .title
                    } else {
                        isInputFocused = true
                    }
                }
            } else {
                if speech.isListening { speech.stopListening() }
                isInputFocused = false
                submitFocus = nil
            }
        }
        .onChange(of: currentIndex) { _ in
            if speech.isListening { speech.stopListening() }
            inputText = ""
            titleInput = ""
            verseInput = ""
            if isReviewMode && !isCardComplete {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    if studyMode == "submit" {
                        submitFocus = .title
                    } else {
                        isInputFocused = true
                    }
                }
            }
        }
        .onChange(of: speech.transcript) { newValue in
            guard speech.isListening else { return }
            switch speechTarget {
            case .title: titleInput = newValue
            case .verse: verseInput = newValue
            }
        }
        .onChange(of: submitFocus) { newFocus in
            guard speech.isListening, let newFocus else { return }
            speech.stopListening()
            speechTarget = newFocus
            speech.startListening()
        }
    }

    // MARK: - Card Stack

    private var cardStack: some View {
        ZStack {
            if currentIndex + 2 < verses.count {
                backgroundCard(at: currentIndex + 2)
                    .scaleEffect(0.90).offset(y: 24).zIndex(0)
            }
            if currentIndex + 1 < verses.count {
                backgroundCard(at: currentIndex + 1)
                    .scaleEffect(0.95 + 0.05 * forwardProgress)
                    .offset(y: 12 * (1 - forwardProgress))
                    .zIndex(1)
            }

            if let verse = currentVerse {
                let goingBack = dragOffset.width > 0
                makeCard(verse: verse, interactive: true)
                    .offset(
                        x: goingBack ? 0 : dragOffset.width,
                        y: goingBack ? backwardProgress * 12 : dragOffset.height * 0.1
                    )
                    .scaleEffect(goingBack ? 1.0 - backwardProgress * 0.05 : 1.0)
                    .rotationEffect(goingBack ? .zero : .degrees(Double(dragOffset.width) * 0.03))
                    .zIndex(2)
                    .gesture(swipeGesture)
            }

            if currentIndex > 0 && dragOffset.width > 0 {
                let prevVerse = verses[currentIndex - 1]
                makeCard(verse: prevVerse, interactive: false)
                    .offset(x: dragOffset.width - 420)
                    .rotationEffect(.degrees(Double(dragOffset.width - 420) * 0.02))
                    .zIndex(3)
            }
        }
    }

    @ViewBuilder
    private func backgroundCard(at index: Int) -> some View {
        if verses.indices.contains(index) {
            makeCard(verse: verses[index], interactive: false)
        }
    }

    @ViewBuilder
    private func makeCard(verse: Verse, interactive: Bool) -> some View {
        if studyMode == "submit" && isReviewMode {
            SubmitCardView(
                verse: verse,
                cardLabel: cardLabel(for: verse),
                titleText: interactive ? $titleInput : .constant(""),
                verseText: interactive ? $verseInput : .constant(""),
                result: submitResults[verse.id],
                focusedField: $submitFocus
            )
        } else {
            FlashcardView(
                verse: verse,
                cardLabel: cardLabel(for: verse),
                isReviewMode: isReviewMode,
                titleRevealedCount: titleRevealedCounts[verse.id, default: 0],
                verseRevealedCount: verseRevealedCounts[verse.id, default: 0],
                activeSection: activeSection,
                onSectionTap: interactive ? { section in
                    withAnimation(.easeOut(duration: 0.2)) { activeSection = section }
                } : nil
            )
        }
    }

    private var swipeGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                if isCardFlying { commitSwipe() }
                let tx = value.translation.width
                let canGoNext = currentIndex < verses.count - 1
                let canGoPrev = currentIndex > 0
                if (tx < 0 && canGoNext) || (tx > 0 && canGoPrev) {
                    dragOffset = value.translation
                } else {
                    dragOffset = CGSize(width: tx * 0.15, height: value.translation.height * 0.15)
                }
            }
            .onEnded { value in
                if isCardFlying { commitSwipe() }
                let threshold: CGFloat = 80
                let vx = value.predictedEndTranslation.width
                if (dragOffset.width < -threshold || vx < -400) && currentIndex < verses.count - 1 {
                    swipeForward()
                } else if (dragOffset.width > threshold || vx > 400) && currentIndex > 0 {
                    swipeBackward()
                } else {
                    withAnimation(.spring(response: 0.3, dampingFraction: 1.0)) {
                        dragOffset = .zero
                    }
                }
            }
    }

    private func swipeForward() {
        isCardFlying = true; flyDirection = -1; haptic(.light)
        withAnimation(.easeOut(duration: 0.2)) {
            dragOffset = CGSize(width: -600, height: dragOffset.height)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { commitSwipe() }
    }

    private func swipeBackward() {
        isCardFlying = true; flyDirection = 1; haptic(.light)
        withAnimation(.easeOut(duration: 0.2)) {
            dragOffset = CGSize(width: 420, height: 0)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { commitSwipe() }
    }

    private func commitSwipe() {
        guard isCardFlying else { return }
        var t = Transaction(); t.disablesAnimations = true
        withTransaction(t) {
            if flyDirection < 0, currentIndex < verses.count - 1 { currentIndex += 1 }
            else if flyDirection > 0, currentIndex > 0 { currentIndex -= 1 }
            dragOffset = .zero; isCardFlying = false; flyDirection = 0
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.secondary)
                    .frame(width: 32, height: 32)
                    .background(Color(.tertiarySystemGroupedBackground))
                    .clipShape(Circle())
            }

            Spacer()

            VStack(spacing: 2) {
                Text(packName)
                    .font(.system(size: 15, weight: .semibold))
                    .lineLimit(1)
                Text("\(currentIndex + 1) of \(verses.count)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }

            Spacer()

            let canReset = isReviewMode && (
                studyMode == "submit"
                    ? submitResults[currentVerse?.id ?? -1] != nil
                    : (titleRevealedCounts[currentVerse?.id ?? -1, default: 0] > 0
                       || verseRevealedCounts[currentVerse?.id ?? -1, default: 0] > 0)
            )

            if canReset, let verse = currentVerse {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        if studyMode == "submit" {
                            submitResults.removeValue(forKey: verse.id)
                            titleInput = ""
                            verseInput = ""
                        } else {
                            titleRevealedCounts[verse.id] = 0
                            verseRevealedCounts[verse.id] = 0
                        }
                    }
                    haptic(.light)
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.secondary)
                        .frame(width: 32, height: 32)
                        .background(Color(.tertiarySystemGroupedBackground))
                        .clipShape(Circle())
                }
            } else {
                Color.clear.frame(width: 32, height: 32)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }

    // MARK: - Scrubber

    private var scrubber: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let knobX: CGFloat = verses.count > 1
                ? CGFloat(currentIndex) / CGFloat(verses.count - 1) * (w - 14) + 7
                : w / 2
            let fillW: CGFloat = max(4, w * CGFloat(currentIndex + 1) / CGFloat(max(1, verses.count)))

            Capsule().fill(Color(.systemGray5)).frame(height: 4).position(x: w / 2, y: h / 2)
            Capsule().fill(Color.primary.opacity(0.3)).frame(width: fillW, height: 4)
                .position(x: fillW / 2, y: h / 2)
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: currentIndex)
            Circle().fill(Color.primary.opacity(0.55)).frame(width: 14, height: 14)
                .position(x: knobX, y: h / 2)
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: currentIndex)
        }
        .frame(height: 20)
        .overlay {
            GeometryReader { geo in
                Color.clear.contentShape(Rectangle())
                    .gesture(DragGesture(minimumDistance: 0).onChanged { value in
                        let fraction = max(0, min(1, value.location.x / geo.size.width))
                        let newIndex = Int(round(fraction * CGFloat(verses.count - 1)))
                        if newIndex != currentIndex && verses.indices.contains(newIndex) {
                            currentIndex = newIndex; haptic(.light)
                        }
                    })
            }
        }
    }

    // MARK: - Bottom Controls

    private var bottomControls: some View {
        VStack(spacing: 12) {
            if isReviewMode {
                if isCardComplete {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green).font(.system(size: 22))
                        Text("Complete!")
                            .font(.system(size: 17, weight: .semibold)).foregroundColor(.green)
                    }
                    .transition(.scale.combined(with: .opacity))
                    .padding(.bottom, 2)
                } else if studyMode == "submit" {
                    submitControls
                } else {
                    immediateInputField
                }
            }

            Picker("Mode", selection: $isReviewMode) {
                Text("Read").tag(false)
                Text("Review").tag(true)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 24)
        }
        .padding(.bottom, 24)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isReviewMode)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isCardComplete)
    }

    private var submitControls: some View {
        let hasSubmitted = currentVerse.flatMap { submitResults[$0.id] } != nil
        return Group {
            if hasSubmitted {
                Button { retrySubmit() } label: {
                    Label("Try Again", systemImage: "arrow.counterclockwise")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
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

                    Button(action: handleSubmit) {
                        let isEmpty = titleInput.trimmingCharacters(in: .whitespaces).isEmpty
                            && verseInput.trimmingCharacters(in: .whitespaces).isEmpty
                        Text("Submit")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(isEmpty ? Color(.systemGray3) : Color.blue)
                            .cornerRadius(12)
                    }
                    .disabled(titleInput.trimmingCharacters(in: .whitespaces).isEmpty
                        && verseInput.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .padding(.horizontal, 24)
    }

    private var immediateInputField: some View {
        let placeholder = studyMode == "fullWord"
            ? "Type each word, press space to check..."
            : "Type first letter of each word..."

        return HStack(spacing: 10) {
            Image(systemName: "character.cursor.ibeam")
                .foregroundColor(.secondary).font(.system(size: 16))

            TextField(placeholder, text: $inputText)
                .font(.system(size: 17))
                .focused($isInputFocused)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .onChange(of: inputText) { newValue in
                    guard !newValue.isEmpty else { return }
                    if studyMode == "firstLetter" {
                        processFirstLetterInput(newValue)
                        DispatchQueue.main.async { self.inputText = "" }
                    } else {
                        processFullWordInput(newValue)
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

    // MARK: - Input Processing (immediate modes)

    private func processFirstLetterInput(_ text: String) {
        guard let typed = text.last, let verse = currentVerse else { return }
        let words = currentWords
        let revealed = currentRevealed
        guard revealed < words.count else { return }
        let targetWord = words[revealed]
        guard let expected = firstLetter(of: targetWord) else {
            setRevealed(verse.id, revealed + 1); return
        }
        if typed.lowercased() == String(expected).lowercased() {
            let newCount = revealed + 1
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { setRevealed(verse.id, newCount) }
            completeSectionIfNeeded(verse: verse, newCount: newCount, words: words)
        } else {
            haptic(.error); shakeAnimation()
        }
    }

    private func processFullWordInput(_ text: String) {
        guard text.hasSuffix(" "), let verse = currentVerse else { return }
        let typedWord = String(text.dropLast()).trimmingCharacters(in: .whitespaces)
        guard !typedWord.isEmpty else {
            DispatchQueue.main.async { self.inputText = "" }; return
        }
        let words = currentWords
        let revealed = currentRevealed
        guard revealed < words.count else { return }
        if normalizedMatch(typedWord, words[revealed]) {
            let newCount = revealed + 1
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { setRevealed(verse.id, newCount) }
            DispatchQueue.main.async { self.inputText = "" }
            completeSectionIfNeeded(verse: verse, newCount: newCount, words: words)
        } else {
            haptic(.error); shakeAnimation()
            DispatchQueue.main.async { self.inputText = "" }
        }
    }

    // MARK: - Submit Mode

    private func handleSubmit() {
        if speech.isListening { speech.stopListening() }
        guard let verse = currentVerse else { return }
        let titleRaw = titleInput.trimmingCharacters(in: .whitespacesAndNewlines)
        let verseRaw = verseInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !titleRaw.isEmpty || !verseRaw.isEmpty else { return }

        let typedTitleWords = titleRaw.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        let typedVerseWords = verseRaw.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        let targetTitleWords = verse.title.components(separatedBy: " ").filter { !$0.isEmpty }
        let targetVerseWords = verse.verse.components(separatedBy: " ").filter { !$0.isEmpty }

        let titleDiffs = buildDiffs(typed: typedTitleWords, target: targetTitleWords)
        let verseDiffs = buildDiffs(typed: typedVerseWords, target: targetVerseWords)
        let result = SubmitResult(titleDiffs: titleDiffs, verseDiffs: verseDiffs)

        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            submitResults[verse.id] = result
        }
        titleInput = ""
        verseInput = ""
        submitFocus = nil

        if result.isAllCorrect {
            haptic(.success)
        } else {
            haptic(.error)
        }
    }

    private func toggleSpeech() {
        if speech.isListening {
            speech.stopListening()
        } else {
            speechTarget = submitFocus ?? .title
            speech.startListening()
        }
    }

    private func buildDiffs(typed: [String], target: [String]) -> [DiffWord] {
        let m = typed.count, n = target.count
        if m == 0 { return target.map { DiffWord(text: $0, kind: .missing) } }
        if n == 0 { return typed.map { DiffWord(text: $0, kind: .extra) } }

        var dp = Array(repeating: Array(repeating: 0, count: n + 1), count: m + 1)
        for i in 0...m { dp[i][0] = i }
        for j in 0...n { dp[0][j] = j }

        for i in 1...m {
            for j in 1...n {
                if normalizedMatch(typed[i - 1], target[j - 1]) {
                    dp[i][j] = dp[i - 1][j - 1]
                } else {
                    dp[i][j] = 1 + min(dp[i - 1][j - 1], dp[i - 1][j], dp[i][j - 1])
                }
            }
        }

        var diffs: [DiffWord] = []
        var i = m, j = n
        while i > 0 || j > 0 {
            if i > 0 && j > 0 && normalizedMatch(typed[i - 1], target[j - 1]) {
                diffs.append(DiffWord(text: target[j - 1], kind: .correct))
                i -= 1; j -= 1
            } else if i > 0 && j > 0 && dp[i][j] == dp[i - 1][j - 1] + 1 {
                diffs.append(DiffWord(text: typed[i - 1], kind: .wrong, correction: target[j - 1]))
                i -= 1; j -= 1
            } else if j > 0 && (i == 0 || dp[i][j - 1] <= dp[i - 1][j]) {
                diffs.append(DiffWord(text: target[j - 1], kind: .missing))
                j -= 1
            } else {
                diffs.append(DiffWord(text: typed[i - 1], kind: .extra))
                i -= 1
            }
        }

        return diffs.reversed()
    }

    private func retrySubmit() {
        guard let verse = currentVerse else { return }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            submitResults.removeValue(forKey: verse.id)
        }
        titleInput = ""
        verseInput = ""
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            submitFocus = .title
        }
    }

    // MARK: - Helpers

    private func completeSectionIfNeeded(verse: Verse, newCount: Int, words: [String]) {
        guard newCount >= words.count else { haptic(.light); return }
        let otherSection: ReviewSection = activeSection == .title ? .verse : .title
        let otherWords: [String]
        let otherRevealed: Int
        switch otherSection {
        case .title:
            otherWords = verse.title.components(separatedBy: " ").filter { !$0.isEmpty }
            otherRevealed = titleRevealedCounts[verse.id, default: 0]
        case .verse:
            otherWords = verse.verse.components(separatedBy: " ").filter { !$0.isEmpty }
            otherRevealed = verseRevealedCounts[verse.id, default: 0]
        }
        haptic(.success)
        if otherRevealed < otherWords.count {
            withAnimation(.easeOut(duration: 0.2)) { activeSection = otherSection }
        }
    }

    private func normalizedMatch(_ typed: String, _ target: String) -> Bool {
        normalize(typed) == normalize(target)
    }

    private func normalize(_ s: String) -> String {
        s.lowercased()
         .components(separatedBy: CharacterSet.punctuationCharacters.union(.symbols))
         .joined()
         .trimmingCharacters(in: .whitespaces)
    }

    private func setRevealed(_ verseId: Int, _ count: Int) {
        switch activeSection {
        case .title: titleRevealedCounts[verseId] = count
        case .verse: verseRevealedCounts[verseId] = count
        }
    }

    private func firstLetter(of word: String) -> Character? {
        word.first { $0.isLetter || $0.isNumber }
    }

    private func cardLabel(for verse: Verse) -> String {
        if verse.subpack.isEmpty { return packName }
        let sub = verses.filter { $0.subpack == verse.subpack }
        let pos = (sub.firstIndex(where: { $0.id == verse.id }) ?? 0) + 1
        return "\(verse.subpack)-\(pos) · \(packName)"
    }

    // MARK: - Haptics

    private enum HapticType { case light, success, error }

    private func haptic(_ type: HapticType) {
        switch type {
        case .light:   UIImpactFeedbackGenerator(style: .light).impactOccurred()
        case .success: UINotificationFeedbackGenerator().notificationOccurred(.success)
        case .error:   UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }

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

#Preview {
    CardStudyView(packName: "5 Assurances", verses: Array(packs.first?.verses.prefix(5) ?? []))
}
