import SwiftUI

/// Everything a card-recall screen needs that doesn't depend on *which* screen
/// it is: the deck and position, per-card reveal progress, the three text
/// inputs, and the typing / dictation / hint / submit logic that drives them.
///
/// `CardStudyViewModel` (reading and reviewing a pack) and
/// `TestSessionViewModel` (a scored quiz or SRS session) used to be two copies
/// of all of this, differing only in what else they tracked. They now subclass
/// it: the pack screen adds shuffle, the favourites filter and pack hopping;
/// the session adds mistakes, completion and persistence. `progressDidChange()`
/// is the one hook — the session overrides it to save.
@MainActor
class RecallCardViewModel: ObservableObject {

    // MARK: - Deck

    /// The verses on screen. Everything else indexes into this.
    @Published var verses: [Verse]

    @Published var currentIndex = 0 {
        didSet { if currentIndex != oldValue { syncActiveSection() } }
    }
    @Published var activeSection: CardSection = .title

    init(verses: [Verse], initialIndex: Int = 0) {
        self.verses       = verses
        self.currentIndex = initialIndex
    }

    // MARK: - Progress

    @Published var titleRevealedCounts: [Int: Int]          = [:]
    @Published var verseRevealedCounts: [Int: Int]          = [:]
    @Published var submitResults:       [Int: SubmitResult] = [:]

    @Published var inputText  = ""
    @Published var titleInput = ""
    @Published var verseInput = ""

    /// Called after any change to progress that's worth keeping. No-op here.
    func progressDidChange() {}

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

    /// Reads the current study mode from UserDefaults to stay in sync with
    /// `@AppStorage` in views.
    var studyMode: StudyMode {
        StudyMode(rawValue: UserDefaults.standard.string(forKey: "studyMode") ?? "") ?? .firstLetter
    }

    // MARK: - Navigation

    func goForward() {
        guard currentIndex < verses.count - 1 else { return }
        currentIndex += 1
        progressDidChange()
    }

    func goBackward() {
        guard currentIndex > 0 else { return }
        currentIndex -= 1
        progressDidChange()
    }

    /// Clears all text inputs. Call when the user navigates to a new card.
    func clearInputs() {
        inputText  = ""
        titleInput = ""
        verseInput = ""
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

    /// Scores the current inputs, stores the result, and returns it (or `nil` if
    /// inputs were empty).
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
        withAnimation(AppMotion.content) {
            submitResults[verse.id] = result
        }
        StreakStore.shared.recordToday()   // submitting a verse counts toward the streak
        progressDidChange()
        titleInput = ""
        verseInput = ""
        return result
    }

    func retrySubmit() {
        guard let verse = currentVerse else { return }
        withAnimation(AppMotion.content) {
            submitResults.removeValue(forKey: verse.id)
        }
        progressDidChange()
        titleInput = ""
        verseInput = ""
    }

    // MARK: - Dictation

    /// How many words of the running transcript have already been matched. The
    /// recognizer re-emits the *whole* transcript on every partial result, so
    /// without this each update would replay the verse from the beginning.
    private var spokenWordsConsumed = 0

    /// Drops dictation bookkeeping — call when a listening session starts or the
    /// card changes, both of which restart the transcript.
    func resetDictation() { spokenWordsConsumed = 0 }

    /// Feeds a dictation transcript through the same reveal path typing uses: each
    /// newly spoken word that matches the next hidden word reveals it, crossing from
    /// title to verse exactly as typing does.
    ///
    /// Only words past the ones already handled are considered, and the count never
    /// rewinds. Speech arrives as a growing and occasionally *revised* transcript,
    /// and revealing is one-way — re-matching a revised prefix would double-advance
    /// the verse. A spoken word that doesn't match is consumed rather than retried,
    /// so one misheard word can't wedge the card.
    func processDictation(_ transcript: String) {
        let spoken = transcript.split(whereSeparator: { $0 == " " || $0.isNewline }).map(String.init)
        guard spoken.count > spokenWordsConsumed else { return }
        for word in spoken[spokenWordsConsumed...] {
            guard let verse = currentVerse else { break }
            let words    = sectionWords(activeSection, in: verse)
            let revealed = revealedCount(for: verse.id, section: activeSection)
            guard revealed < words.count else { break }
            if DiffEngine.normalizedMatch(word, words[revealed]) {
                advance(verse: verse, sectionWords: words, revealed: revealed)
            }
        }
        spokenWordsConsumed = spoken.count
    }

    // MARK: - Hints

    /// Reveals the next hidden word as a hint — in the section the user is
    /// currently on (active), falling back to the other section once the
    /// active one is fully revealed.
    func revealHint() {
        guard let verse = currentVerse else { return }
        let other: CardSection = activeSection == .title ? .verse : .title
        let hinted: CardSection
        if revealedCount(for: verse.id, section: activeSection) < sectionWords(activeSection, in: verse).count {
            hinted = activeSection
        } else if revealedCount(for: verse.id, section: other) < sectionWords(other, in: verse).count {
            hinted = other
        } else {
            return
        }
        withAnimation(AppMotion.content) {
            switch hinted {
            case .verse: verseRevealedCounts[verse.id] = verseRevealedCounts[verse.id, default: 0] + 1
            case .title: titleRevealedCounts[verse.id] = titleRevealedCounts[verse.id, default: 0] + 1
            }
        }
        progressDidChange()
        // If the hint just finished the section the user was typing in,
        // move the highlight to the other section (if it still has words).
        if hinted == activeSection,
           revealedCount(for: verse.id, section: hinted) >= sectionWords(hinted, in: verse).count {
            switchSectionIfNeeded(verse: verse)
        }
    }

    /// Entire Verse's hint: extends whichever answer box the user is in by one
    /// word, falling through to the other once that one is complete — so
    /// repeated taps walk the whole card without moving focus by hand.
    func fillNextHintWord(startingWithVerse: Bool) {
        guard let verse = currentVerse else { return }
        let sections: [(target: String, isTitle: Bool)] = startingWithVerse
            ? [(verse.verse, false), (verse.title, true)]
            : [(verse.title, true), (verse.verse, false)]

        for section in sections {
            let typed = section.isTitle ? titleInput : verseInput
            guard let filled = HintFill.next(target: section.target, typed: typed) else { continue }
            if section.isTitle { titleInput = filled } else { verseInput = filled }
            return
        }
    }

    // MARK: - Sections

    /// Points the highlight at the first incomplete section of the current card.
    func syncActiveSection() {
        guard let verse = currentVerse else { return }
        let titleDone = titleRevealedCounts[verse.id, default: 0] >= verse.titleWords.count
        let target: CardSection = titleDone ? .verse : .title
        if activeSection != target { activeSection = target }
    }

    func sectionWords(_ section: CardSection, in verse: Verse) -> [String] {
        section == .title ? verse.titleWords : verse.verseWords
    }

    private func setRevealed(_ count: Int, for verseId: Int, section: CardSection) {
        switch section {
        case .title: titleRevealedCounts[verseId] = count
        case .verse: verseRevealedCounts[verseId] = count
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
        withAnimation(AppMotion.content) {
            setRevealed(newCount, for: verse.id, section: activeSection)
        }
        progressDidChange()
        if newCount >= sectionWords.count {
            switchSectionIfNeeded(verse: verse)
            if isCardComplete {
                StreakStore.shared.recordToday()   // finishing a verse counts toward the streak
            }
        }
    }

    private func switchSectionIfNeeded(verse: Verse) {
        let other         = activeSection == .title ? CardSection.verse : .title
        let otherWords    = sectionWords(other, in: verse)
        let otherRevealed = revealedCount(for: verse.id, section: other)
        if otherRevealed < otherWords.count {
            withAnimation(AppMotion.control) { activeSection = other }
        }
    }
}
