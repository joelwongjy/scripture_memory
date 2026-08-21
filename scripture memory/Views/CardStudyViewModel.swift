import SwiftUI

/// The pack study screen's state: `RecallCardViewModel` plus the pack itself,
/// read-vs-review mode, shuffle, the favourites filter, and hopping to the
/// neighbouring pack.
///
/// The paired `CardStudyView` is responsible only for layout, gesture handling,
/// focus state, and animation triggers.
@MainActor
final class CardStudyViewModel: RecallCardViewModel {

    // MARK: - Pack

    @Published var packName: String
    @Published var isReviewMode = false
    @Published private(set) var isShuffled = false
    @Published private(set) var isFavoritesFiltered = false

    private var originalVerses: [Verse]

    /// The shuffled permutation, held so that turning the favourites filter on
    /// and off doesn't silently reshuffle the pack underneath the user.
    private var shuffledVerses: [Verse] = []

    /// `verses` (inherited) is `originalVerses` after shuffle and the
    /// favourites filter — the deck actually on screen.
    init(packName: String, verses: [Verse], initialIndex: Int = 0, initialReviewMode: Bool = false) {
        self.packName       = packName
        self.originalVerses = verses
        self.isReviewMode   = initialReviewMode
        super.init(verses: verses, initialIndex: initialIndex)
    }

    // MARK: - Navigation

    /// Swap to a different pack's verses in place — used by "Continue Learning"
    /// to roll into the next/previous pack when the user steps past a boundary.
    func loadPack(name: String, verses newVerses: [Verse], startAt index: Int) {
        var t = Transaction(); t.disablesAnimations = true
        withTransaction(t) {
            packName            = name
            verses              = newVerses
            originalVerses      = newVerses
            shuffledVerses      = []
            isShuffled          = false
            isFavoritesFiltered = false
            currentIndex        = min(max(index, 0), max(newVerses.count - 1, 0))
            titleRevealedCounts = [:]
            verseRevealedCounts = [:]
            submitResults       = [:]
            inputText  = ""
            titleInput = ""
            verseInput = ""
        }
    }

    /// Flips between the pack's own order and a random one.
    ///
    /// Reordering is purely presentational: every bit of progress (revealed word
    /// counts, submitted answers) is keyed by verse **id**, not by position, so
    /// shuffling can't invalidate any of it. Wiping those dictionaries here meant
    /// toggling shuffle off — the natural "put it back how it was" gesture — threw
    /// away the whole session. Keep the progress.
    ///
    /// `restartFromTop` picks where the reorder leaves you. A single card is a
    /// place you're standing, so it stays parked on the verse you were looking at.
    /// A list is a thing you read top-down, and following the old verse to wherever
    /// it landed just drops you mid-list with no sense of the new order — so the
    /// list restarts at the first card.
    func toggleShuffle(restartFromTop: Bool = false) {
        isShuffled.toggle()
        if isShuffled { shuffledVerses = originalVerses.shuffled() }
        rebuild(anchorId: restartFromTop ? nil : currentVerse?.id)
    }

    /// Narrow the session to starred verses (or widen it back).
    ///
    /// Applied on top of the current order rather than replacing it, so a
    /// shuffled pack stays shuffled — and, more importantly, the filtered list is
    /// what Review then tests, which is the whole point of being able to filter.
    ///
    /// The caller is responsible for not filtering a pack down to nothing; see
    /// `favoriteCount`.
    func setFavoritesFilter(_ on: Bool) {
        guard isFavoritesFiltered != on else { return }
        isFavoritesFiltered = on
        rebuild(anchorId: currentVerse?.id)
    }

    /// How many of this pack's verses are starred — gates the filter control, and
    /// lets the view drop the filter if the last one is un-starred while it's on.
    var favoriteCount: Int {
        let keys = FavoritesStore.shared.keys
        return originalVerses.reduce(0) { $0 + (keys.contains($1.srsKey) ? 1 : 0) }
    }

    /// Recompute `verses` from the pack plus the current order/filter, keeping the
    /// user parked on `anchorId` if it survived the rebuild.
    ///
    /// Reordering and filtering are purely presentational: every bit of progress
    /// (revealed word counts, submitted answers) is keyed by verse **id**, not by
    /// position, so neither can invalidate any of it — which is why nothing is
    /// cleared here beyond the in-flight text inputs.
    private func rebuild(anchorId: Int?) {
        var next = isShuffled ? shuffledVerses : originalVerses
        if isFavoritesFiltered {
            let keys = FavoritesStore.shared.keys
            next = next.filter { keys.contains($0.srsKey) }
        }
        var t = Transaction(); t.disablesAnimations = true
        withTransaction(t) {
            verses       = next
            currentIndex = anchorId.flatMap { id in next.firstIndex { $0.id == id } } ?? 0
            inputText  = ""
            titleInput = ""
            verseInput = ""
        }
        // `currentIndex`'s didSet only re-points the highlight when the index
        // actually changed — the anchor verse may well land on the same index.
        syncActiveSection()
    }

    // MARK: - Card Label

    /// Returns the footer label for a card, e.g. `"A-12 · Live the New Life"`.
    /// Keyed off the verse's own pack (not the session's) so cross-pack "Continue
    /// Learning" sessions still label each verse correctly.
    func cardLabel(for verse: Verse) -> String {
        CardFooter.label(for: verse, fallbackPack: packName)
    }

    // MARK: - Reset

    /// Wipes the current card's progress so it can be tried again from scratch.
    func resetCurrentCard() {
        guard let verse = currentVerse else { return }
        withAnimation(AppMotion.control) {
            switch studyMode {
            case .submit:
                submitResults.removeValue(forKey: verse.id)
                titleInput = ""
                verseInput = ""
            default:
                titleRevealedCounts[verse.id] = 0
                verseRevealedCounts[verse.id] = 0
                activeSection = .title
            }
        }
    }
}
