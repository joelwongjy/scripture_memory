import SwiftUI

// MARK: - Persisted Progress

/// Codable snapshot of a session — written to UserDefaults on every key mutation.
/// JSON requires string dictionary keys, so Int IDs are stringified.
private struct SessionProgress: Codable {
    var currentIndex:        Int
    var mistakeCounts:       [String: Int]
    var titleRevealedCounts: [String: Int]
    var verseRevealedCounts: [String: Int]
    /// IDs of verses correctly submitted in submit mode (all correct).
    var completedVerseIds:   [String]
    /// Full Entire Verse diff state per verse (wrong + correct attempts). Nil on older saves.
    var submitResultsSnapshot: [String: SubmitResultPersistence.StoredResult]?
}

// MARK: - Test Session View Model

/// A scored quiz or review session: `RecallCardViewModel` plus mistake counts,
/// completion, and persistence — progress is written to UserDefaults on every
/// change so a session survives dismissal and app restarts.
@MainActor
final class TestSessionViewModel: RecallCardViewModel {

    // MARK: - Initialisation

    init(verses: [Verse]) {
        super.init(verses: verses)
        restoreProgress()
    }

    // MARK: - Published State

    @Published private(set) var mistakeCounts:       [Int: Int]          = [:]
    /// Verse IDs correctly submitted — persisted so submit-mode progress survives dismissal.
    @Published private(set) var completedVerseIds:   Set<Int>            = []

    // MARK: - Derived State

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

    /// Every progress mutation in the base class lands here — persist it.
    override func progressDidChange() { saveProgress() }

    // MARK: - Card Label

    func cardLabel(for verse: Verse) -> String { CardFooter.label(for: verse) }

    // MARK: - Mistake Tracking

    /// Only Entire Verse mode scores. The two typing modes reveal the text a word at
    /// a time against a phone keyboard, so a fat-fingered neighbouring key reads as a
    /// recall miss — the count measures typing accuracy far more than memory, and it
    /// handed people a negative for slips they never made. Nothing is tracked in
    /// those modes: no score, and no input to the SRS grade suggestion (which
    /// declines to suggest anything there — see `suggestedGradeFor`).
    func recordMistake() {
        guard studyMode == .submit else { return }
        guard let verse = currentVerse else { return }
        let current = mistakeCounts[verse.id, default: 0]
        guard current < 5 else { return }
        mistakeCounts[verse.id] = current + 1
        saveProgress()
    }

    // MARK: - Input Processing

    /// On top of the shared scoring: count the mistakes and remember a perfect
    /// submission, which is what the session's score and completion read.
    @discardableResult
    override func handleSubmit() -> SubmitResult? {
        guard let verse = currentVerse, let result = super.handleSubmit() else { return nil }

        // Count mistakes from wrong/missing/extra diffs
        let totalMistakes = result.titleDiffs.filter { $0.kind != .correct }.count
                          + result.verseDiffs.filter { $0.kind != .correct }.count
        for _ in 0..<totalMistakes { recordMistake() }

        if result.isAllCorrect { completedVerseIds.insert(verse.id) }
        saveProgress()
        return result
    }

    override func retrySubmit() {
        guard let verse = currentVerse else { return }
        super.retrySubmit()
        // Reset this card's mistakes so the score reflects the new attempt
        mistakeCounts.removeValue(forKey: verse.id)
        completedVerseIds.remove(verse.id)
        saveProgress()
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

    /// Persists session state (e.g. after scrubber drag). Navigation helpers call `saveProgress` internally.
    func persistSession() {
        saveProgress()
    }

    private func saveProgress() {
        let snapshot = submitResults.isEmpty
            ? nil
            : SubmitResultPersistence.encodeToMap(submitResults)
        let sp = SessionProgress(
            currentIndex:        currentIndex,
            mistakeCounts:       toStringKeys(mistakeCounts),
            titleRevealedCounts: toStringKeys(titleRevealedCounts),
            verseRevealedCounts: toStringKeys(verseRevealedCounts),
            completedVerseIds:   completedVerseIds.map { String($0) },
            submitResultsSnapshot: snapshot
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

        let validIds = Set(verses.map(\.id))
        var restored = SubmitResultPersistence.decodeFromMap(sp.submitResultsSnapshot, validVerseIds: validIds)

        // Older sessions only stored perfect completions — rebuild all-green diffs for those.
        for verseId in completedVerseIds where restored[verseId] == nil {
            if let verse = verses.first(where: { $0.id == verseId }) {
                restored[verseId] = SubmitResult(
                    titleDiffs: verse.titleWords.map { DiffWord(text: $0, kind: .correct) },
                    verseDiffs: verse.verseWords.map { DiffWord(text: $0, kind: .correct) }
                )
            }
        }
        submitResults = restored

        // Jump to the first incomplete card so the user picks up where they left off
        if let firstIncomplete = verses.indices.first(where: { !isComplete(verses[$0]) }) {
            currentIndex = firstIncomplete
        }
        // Counts were restored after currentIndex was set — re-point the highlight.
        syncActiveSection()
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

    private func toStringKeys(_ d: [Int: Int]) -> [String: Int] {
        Dictionary(uniqueKeysWithValues: d.map { (String($0.key), $0.value) })
    }

    private func toIntKeys(_ d: [String: Int]) -> [Int: Int] {
        Dictionary(uniqueKeysWithValues: d.compactMap { k, v in Int(k).map { ($0, v) } })
    }
}
