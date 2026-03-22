import SwiftUI

// MARK: - Test Session View Model

/// Owns all non-visual state and business logic for a scored test session.
@MainActor
final class TestSessionViewModel: ObservableObject {

    // MARK: - Initialisation

    let verses: [Verse]

    init(verses: [Verse]) {
        self.verses = verses
    }

    // MARK: - Published State

    @Published var currentIndex = 0
    @Published var activeSection: CardSection = .title

    @Published private(set) var titleRevealedCounts: [Int: Int]    = [:]
    @Published private(set) var verseRevealedCounts: [Int: Int]    = [:]
    @Published private(set) var submitResults:       [Int: SubmitResult] = [:]
    @Published private(set) var mistakeCounts:       [Int: Int]    = [:]

    @Published var inputText  = ""
    @Published var titleInput = ""
    @Published var verseInput = ""

    // MARK: - Derived State

    var currentVerse: Verse? {
        verses.indices.contains(currentIndex) ? verses[currentIndex] : nil
    }

    var isCardComplete: Bool {
        guard let verse = currentVerse else { return false }
        switch studyMode {
        case .submit:
            return submitResults[verse.id]?.isAllCorrect == true
        default:
            return titleRevealedCounts[verse.id, default: 0] >= verse.titleWords.count
                && verseRevealedCounts[verse.id, default: 0] >= verse.verseWords.count
        }
    }

    var isSessionComplete: Bool {
        guard !verses.isEmpty else { return false }
        return verses.allSatisfy { verse in
            switch studyMode {
            case .submit:
                return submitResults[verse.id]?.isAllCorrect == true
            default:
                return titleRevealedCounts[verse.id, default: 0] >= verse.titleWords.count
                    && verseRevealedCounts[verse.id, default: 0] >= verse.verseWords.count
            }
        }
    }

    func mistakes(for verseId: Int) -> Int {
        min(mistakeCounts[verseId, default: 0], 5)
    }

    func score(for verseId: Int) -> Int {
        -mistakes(for: verseId)
    }

    var sessionScore: Int {
        verses.reduce(0) { $0 + score(for: $1.id) }
    }

    var perfectCount: Int {
        verses.filter { verse in
            let complete: Bool
            switch studyMode {
            case .submit:
                complete = submitResults[verse.id]?.isAllCorrect == true
            default:
                complete = titleRevealedCounts[verse.id, default: 0] >= verse.titleWords.count
                    && verseRevealedCounts[verse.id, default: 0] >= verse.verseWords.count
            }
            return complete && mistakes(for: verse.id) == 0
        }.count
    }

    // Reads the current study mode from UserDefaults to stay in sync with @AppStorage in views.
    var studyMode: StudyMode {
        StudyMode(rawValue: UserDefaults.standard.string(forKey: "studyMode") ?? "") ?? .firstLetter
    }

    // MARK: - Navigation

    func goForward()  { if currentIndex < verses.count - 1 { currentIndex += 1 } }
    func goBackward() { if currentIndex > 0                { currentIndex -= 1 } }

    func clearInputs() {
        inputText  = ""
        titleInput = ""
        verseInput = ""
    }

    // MARK: - Card Label

    func cardLabel(for verse: Verse) -> String {
        "Review"
    }

    // MARK: - Reveal State

    func revealedCount(for verseId: Int, section: CardSection) -> Int {
        section == .title
            ? titleRevealedCounts[verseId, default: 0]
            : verseRevealedCounts[verseId, default: 0]
    }

    // MARK: - Mistake Tracking

    func recordMistake() {
        guard let verse = currentVerse else { return }
        let current = mistakeCounts[verse.id, default: 0]
        if current < 5 {
            mistakeCounts[verse.id] = current + 1
        }
    }

    // MARK: - Input Processing

    @discardableResult
    func processFirstLetterInput(_ text: String) -> Bool {
        guard let typed = text.last, let verse = currentVerse else { return false }
        let words    = sectionWords(activeSection, in: verse)
        let revealed = revealedCount(for: verse.id, section: activeSection)
        guard revealed < words.count else { return false }
        let target = words[revealed]
        guard let expected = target.first(where: { $0.isLetter || $0.isNumber }) else {
            advance(verse: verse, sectionWords: words, revealed: revealed)
            return true
        }
        if typed.lowercased() == String(expected).lowercased() {
            advance(verse: verse, sectionWords: words, revealed: revealed)
            return true
        }
        return false
    }

    @discardableResult
    func processFullWordInput(_ text: String) -> Bool {
        guard text.hasSuffix(" "), let verse = currentVerse else { return false }
        let typed    = String(text.dropLast()).trimmingCharacters(in: .whitespaces)
        guard !typed.isEmpty else { inputText = ""; return false }
        let words    = sectionWords(activeSection, in: verse)
        let revealed = revealedCount(for: verse.id, section: activeSection)
        guard revealed < words.count else { return false }
        if DiffEngine.normalizedMatch(typed, words[revealed]) {
            advance(verse: verse, sectionWords: words, revealed: revealed)
            inputText = ""
            return true
        }
        inputText = ""
        return false
    }

    @discardableResult
    func handleSubmit() -> SubmitResult? {
        guard let verse = currentVerse else { return nil }
        let typedTitle = titleInput.trimmingCharacters(in: .whitespacesAndNewlines).wordTokens
        let typedVerse = verseInput.trimmingCharacters(in: .whitespacesAndNewlines).wordTokens
        guard !typedTitle.isEmpty || !typedVerse.isEmpty else { return nil }

        let result = SubmitResult(
            titleDiffs: DiffEngine.buildDiffs(typed: typedTitle, target: verse.titleWords),
            verseDiffs: DiffEngine.buildDiffs(typed: typedVerse, target: verse.verseWords)
        )
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            submitResults[verse.id] = result
        }

        // Count mistakes from diffs
        let wrongCount   = result.titleDiffs.filter { $0.kind == .wrong   }.count
                         + result.verseDiffs.filter { $0.kind == .wrong   }.count
        let missingCount = result.titleDiffs.filter { $0.kind == .missing }.count
                         + result.verseDiffs.filter { $0.kind == .missing }.count
        let extraCount   = result.titleDiffs.filter { $0.kind == .extra   }.count
                         + result.verseDiffs.filter { $0.kind == .extra   }.count
        let totalMistakes = wrongCount + missingCount + extraCount
        for _ in 0..<totalMistakes { recordMistake() }

        if result.isAllCorrect { ReviewProgress.shared.markComplete(verse.id) }
        titleInput = ""
        verseInput = ""
        return result
    }

    func retrySubmit() {
        guard let verse = currentVerse else { return }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            submitResults.removeValue(forKey: verse.id)
        }
        titleInput = ""
        verseInput = ""
        // Note: mistakes are NOT reset — they are permanent
    }

    // MARK: - Private Helpers

    private func sectionWords(_ section: CardSection, in verse: Verse) -> [String] {
        section == .title ? verse.titleWords : verse.verseWords
    }

    private func setRevealed(_ count: Int, for verseId: Int, section: CardSection) {
        switch section {
        case .title: titleRevealedCounts[verseId] = count
        case .verse: verseRevealedCounts[verseId] = count
        }
    }

    private func advance(verse: Verse, sectionWords: [String], revealed: Int) {
        let newCount = revealed + 1
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            setRevealed(newCount, for: verse.id, section: activeSection)
        }
        if newCount >= sectionWords.count {
            switchSectionIfNeeded(verse: verse)
            if isCardComplete { ReviewProgress.shared.markComplete(verse.id) }
        }
    }

    private func switchSectionIfNeeded(verse: Verse) {
        let other         = activeSection == .title ? CardSection.verse : .title
        let otherWords    = sectionWords(other, in: verse)
        let otherRevealed = revealedCount(for: verse.id, section: other)
        if otherRevealed < otherWords.count {
            withAnimation(.easeOut(duration: 0.2)) { activeSection = other }
        }
    }
}
