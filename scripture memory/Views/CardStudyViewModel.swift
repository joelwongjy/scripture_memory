import SwiftUI

// MARK: - Card Section

/// Identifies which part of a flashcard — title or verse — is currently being studied.
enum CardSection: Hashable {
    case title
    case verse
}

// MARK: - Card Study View Model

/// Owns all non-visual state and business logic for a card study session.
///
/// The paired `CardStudyView` is responsible only for layout, gesture handling,
/// focus state, and animation triggers.
@MainActor
final class CardStudyViewModel: ObservableObject {

    // MARK: - Initialisation

    @Published var packName: String
    @Published var verses: [Verse]
    @Published private(set) var isShuffled = false

    private var originalVerses: [Verse]

    init(packName: String, verses: [Verse], initialIndex: Int = 0, initialReviewMode: Bool = false) {
        self.packName       = packName
        self.verses         = verses
        self.originalVerses = verses
        self.currentIndex   = initialIndex
        self.isReviewMode   = initialReviewMode
    }

    // MARK: - Published State

    @Published var currentIndex  = 0
    @Published var isReviewMode  = false
    @Published var activeSection: CardSection = .title

    @Published private(set) var titleRevealedCounts: [Int: Int]    = [:]
    @Published private(set) var verseRevealedCounts: [Int: Int]    = [:]
    @Published private(set) var submitResults:       [Int: SubmitResult] = [:]

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

    /// True once the current card has been answered — submitted in entire-verse
    /// mode (right *or* wrong) or fully revealed in first-letter / full-word mode.
    /// Unlike `isCardComplete` (perfect-only in submit mode), a submitted-but-
    /// imperfect card counts as answered, so peek can hide once the answer is shown.
    var isCardAnswered: Bool {
        guard let verse = currentVerse else { return false }
        if studyMode == .submit { return submitResults[verse.id] != nil }
        return isCardComplete
    }

    var canReset: Bool {
        guard isReviewMode, let verse = currentVerse else { return false }
        switch studyMode {
        case .submit:
            return submitResults[verse.id] != nil
        default:
            return titleRevealedCounts[verse.id, default: 0] > 0
                || verseRevealedCounts[verse.id, default: 0] > 0
        }
    }

    // Reads the current study mode from UserDefaults to stay in sync with @AppStorage in views.
    private var studyMode: StudyMode {
        StudyMode(rawValue: UserDefaults.standard.string(forKey: "studyMode") ?? "") ?? .firstLetter
    }

    // MARK: - Navigation

    func goForward()  { if currentIndex < verses.count - 1 { currentIndex += 1 } }
    func goBackward() { if currentIndex > 0                { currentIndex -= 1 } }

    /// Swap to a different pack's verses in place — used by "Continue Learning"
    /// to roll into the next/previous pack when the user steps past a boundary.
    func loadPack(name: String, verses newVerses: [Verse], startAt index: Int) {
        var t = Transaction(); t.disablesAnimations = true
        withTransaction(t) {
            packName            = name
            verses              = newVerses
            originalVerses      = newVerses
            isShuffled          = false
            currentIndex        = min(max(index, 0), max(newVerses.count - 1, 0))
            titleRevealedCounts = [:]
            verseRevealedCounts = [:]
            submitResults       = [:]
            inputText  = ""
            titleInput = ""
            verseInput = ""
        }
    }

    func toggleShuffle() {
        var t = Transaction(); t.disablesAnimations = true
        withTransaction(t) {
            isShuffled            = !isShuffled
            verses                = isShuffled ? originalVerses.shuffled() : originalVerses
            currentIndex          = 0
            titleRevealedCounts   = [:]
            verseRevealedCounts   = [:]
            submitResults         = [:]
            inputText  = ""
            titleInput = ""
            verseInput = ""
        }
    }

    /// Clears all text inputs. Call when the user navigates to a new card.
    func clearInputs() {
        inputText  = ""
        titleInput = ""
        verseInput = ""
    }

    // MARK: - Card Label

    /// Returns the footer label for a card, e.g. `"A-1 · TMS 60"`. Uses the
    /// verse's own pack (not the session's) so cross-pack "Continue Learning"
    /// sessions still show which pack each verse belongs to.
    func cardLabel(for verse: Verse) -> String {
        let pack = verse.packName.isEmpty ? packName : verse.packName
        guard !verse.subpack.isEmpty else { return pack }
        let subpackVerses = verses.filter { $0.subpack == verse.subpack && $0.packName == verse.packName }
        let position = (subpackVerses.firstIndex(where: { $0.id == verse.id }) ?? 0) + 1
        return "\(verse.subpack)-\(position) · \(pack)"
    }

    // MARK: - Reveal State

    func revealedCount(for verseId: Int, section: CardSection) -> Int {
        section == .title
            ? titleRevealedCounts[verseId, default: 0]
            : verseRevealedCounts[verseId, default: 0]
    }

    // MARK: - Input Processing

    /// Returns `true` if the typed character matches the next word's first letter.
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

    /// Returns `true` if a space-terminated word matched the next target word.
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

    /// Scores the current inputs, stores the result, and returns it (or `nil` if inputs were empty).
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
        if result.isAllCorrect { ReviewProgress.shared.markComplete(verse.id) }
        StreakStore.shared.recordToday()   // submitting a verse counts toward the streak
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
    }

    func resetCurrentCard() {
        guard let verse = currentVerse else { return }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            switch studyMode {
            case .submit:
                submitResults.removeValue(forKey: verse.id)
                titleInput = ""
                verseInput = ""
            default:
                titleRevealedCounts[verse.id] = 0
                verseRevealedCounts[verse.id] = 0
            }
        }
    }

    // MARK: - Private Helpers

    private func sectionWords(_ section: CardSection, in verse: Verse) -> [String] {
        section == .title ? verse.titleWords : verse.verseWords
    }

    private func setRevealed(_ count: Int, for verseId: Int, section: CardSection) {
        switch section {
        case .title: titleRevealedCounts[verseId] = count
        case .verse:  verseRevealedCounts[verseId] = count
        }
    }

    private func advance(verse: Verse, sectionWords: [String], revealed: Int) {
        var newCount = revealed + 1
        // Auto-skip pure-punctuation tokens (e.g. a standalone "-" with spaces around
        // it) — they have no first letter to type, so they must not swallow the
        // keystroke meant for the next real word.
        while newCount < sectionWords.count,
              !sectionWords[newCount].contains(where: { $0.isLetter || $0.isNumber }) {
            newCount += 1
        }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            setRevealed(newCount, for: verse.id, section: activeSection)
        }
        if newCount >= sectionWords.count {
            switchSectionIfNeeded(verse: verse)
            if isCardComplete {
                ReviewProgress.shared.markComplete(verse.id)
                StreakStore.shared.recordToday()   // finishing a verse counts toward the streak
            }
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
