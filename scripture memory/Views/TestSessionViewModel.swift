import SwiftUI

// MARK: - Persisted Progress

/// Codable snapshot of a session — written to UserDefaults on every key mutation.
/// JSON requires string dictionary keys, so Int IDs are stringified.
private struct SessionProgress: Codable {
    var currentIndex:        Int
    var mistakeCounts:       [String: Int]
    var titleRevealedCounts: [String: Int]
    var verseRevealedCounts: [String: Int]
    /// IDs of verses correctly submitted in submit mode — lets us restore completion state.
    var completedVerseIds:   [String]
}

// MARK: - Test Session View Model

/// Owns all non-visual state and business logic for a scored test session.
/// Progress is automatically persisted to UserDefaults so sessions survive
/// dismissal and app restarts.
@MainActor
final class TestSessionViewModel: ObservableObject {

    // MARK: - Initialisation

    let verses: [Verse]

    init(verses: [Verse]) {
        self.verses = verses
        restoreProgress()
    }

    // MARK: - Published State

    @Published var currentIndex  = 0
    @Published var activeSection: CardSection = .title

    @Published private(set) var titleRevealedCounts: [Int: Int]          = [:]
    @Published private(set) var verseRevealedCounts: [Int: Int]          = [:]
    @Published private(set) var submitResults:       [Int: SubmitResult]  = [:]
    @Published private(set) var mistakeCounts:       [Int: Int]          = [:]
    /// Verse IDs correctly submitted — persisted so submit-mode progress survives dismissal.
    @Published private(set) var completedVerseIds:   Set<Int>            = []

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

    func mistakes(for verseId: Int) -> Int { min(mistakeCounts[verseId, default: 0], 5) }
    func score(for verseId: Int) -> Int    { -mistakes(for: verseId) }

    var sessionScore:    Int { verses.reduce(0) { $0 + score(for: $1.id) } }
    var perfectCount:   Int { verses.filter { mistakes(for: $0.id) == 0 && isComplete($0) }.count }
    var completedCount: Int { verses.filter { isComplete($0) }.count }

    /// Public accessor so views can colour per-verse progress dots.
    func isVerseComplete(_ verse: Verse) -> Bool { isComplete(verse) }

    /// True once the user has pressed Submit for this verse (even with mistakes).
    func hasSubmitted(_ verse: Verse) -> Bool { submitResults[verse.id] != nil }

    var studyMode: StudyMode {
        StudyMode(rawValue: UserDefaults.standard.string(forKey: "studyMode") ?? "") ?? .firstLetter
    }

    // MARK: - Navigation

    func goForward() {
        guard currentIndex < verses.count - 1 else { return }
        currentIndex += 1
        activeSection = .title
        saveProgress()
    }

    func goBackward() {
        guard currentIndex > 0 else { return }
        currentIndex -= 1
        activeSection = .title
        saveProgress()
    }

    func clearInputs() { inputText = ""; titleInput = ""; verseInput = "" }

    // MARK: - Card Label

    func cardLabel(for verse: Verse) -> String { "Review" }

    // MARK: - Reveal State

    func revealedCount(for verseId: Int, section: CardSection) -> Int {
        section == .title
            ? titleRevealedCounts[verseId, default: 0]
            : verseRevealedCounts[verseId, default: 0]
    }

    // MARK: - Mistake Tracking (submit mode only)

    func recordMistake() {
        guard let verse = currentVerse else { return }
        let current = mistakeCounts[verse.id, default: 0]
        guard current < 5 else { return }
        mistakeCounts[verse.id] = current + 1
        saveProgress()
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

        // Count mistakes from wrong/missing/extra diffs
        let totalMistakes = result.titleDiffs.filter { $0.kind != .correct }.count
                          + result.verseDiffs.filter { $0.kind != .correct }.count
        for _ in 0..<totalMistakes { recordMistake() }

        if result.isAllCorrect {
            completedVerseIds.insert(verse.id)
            ReviewProgress.shared.markComplete(verse.id)
        }
        saveProgress()
        titleInput = ""
        verseInput = ""
        return result
    }

    func retrySubmit() {
        guard let verse = currentVerse else { return }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            submitResults.removeValue(forKey: verse.id)
        }
        // Reset this card's mistakes so the score reflects the new attempt
        mistakeCounts.removeValue(forKey: verse.id)
        completedVerseIds.remove(verse.id)
        saveProgress()
        titleInput = ""
        verseInput = ""
    }

    // MARK: - Session Reset (Try Again)

    /// Resets all progress and mistake counts, then saves the clean state.
    func resetAllProgress() {
        var t = Transaction(); t.disablesAnimations = true
        withTransaction(t) {
            currentIndex        = 0
            activeSection       = .title
            mistakeCounts       = [:]
            titleRevealedCounts = [:]
            verseRevealedCounts = [:]
            submitResults       = [:]
            completedVerseIds   = []
            inputText  = ""
            titleInput = ""
            verseInput = ""
        }
        saveProgress()
    }

    // MARK: - Persistence

    private static let progressKey = "currentSessionProgress"

    /// Called when the user explicitly ends the session — wipes persisted state.
    func clearProgress() {
        UserDefaults.standard.removeObject(forKey: Self.progressKey)
    }

    /// Called before starting a brand-new session so stale progress is never restored.
    static func clearPersistedProgress() {
        UserDefaults.standard.removeObject(forKey: progressKey)
    }

    private func saveProgress() {
        let sp = SessionProgress(
            currentIndex:        currentIndex,
            mistakeCounts:       toStringKeys(mistakeCounts),
            titleRevealedCounts: toStringKeys(titleRevealedCounts),
            verseRevealedCounts: toStringKeys(verseRevealedCounts),
            completedVerseIds:   completedVerseIds.map { String($0) }
        )
        if let data = try? JSONEncoder().encode(sp) {
            UserDefaults.standard.set(data, forKey: Self.progressKey)
        }
    }

    private func restoreProgress() {
        guard let data = UserDefaults.standard.data(forKey: Self.progressKey),
              let sp   = try? JSONDecoder().decode(SessionProgress.self, from: data) else { return }
        currentIndex        = min(sp.currentIndex, max(0, verses.count - 1))
        mistakeCounts       = toIntKeys(sp.mistakeCounts)
        titleRevealedCounts = toIntKeys(sp.titleRevealedCounts)
        verseRevealedCounts = toIntKeys(sp.verseRevealedCounts)
        completedVerseIds   = Set(sp.completedVerseIds.compactMap { Int($0) })
        // Jump to the first incomplete card so the user picks up where they left off
        if let firstIncomplete = verses.indices.first(where: { !isComplete(verses[$0]) }) {
            currentIndex = firstIncomplete
        }
    }

    // MARK: - Private Helpers

    private func isComplete(_ verse: Verse) -> Bool {
        switch studyMode {
        case .submit: return submitResults[verse.id] != nil
        default:
            return titleRevealedCounts[verse.id, default: 0] >= verse.titleWords.count
                && verseRevealedCounts[verse.id, default: 0] >= verse.verseWords.count
        }
    }

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
        saveProgress()
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

    private func toStringKeys(_ d: [Int: Int]) -> [String: Int] {
        Dictionary(uniqueKeysWithValues: d.map { (String($0.key), $0.value) })
    }

    private func toIntKeys(_ d: [String: Int]) -> [Int: Int] {
        Dictionary(uniqueKeysWithValues: d.compactMap { k, v in Int(k).map { ($0, v) } })
    }
}
