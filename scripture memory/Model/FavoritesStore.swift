import Foundation
import Combine

/// Verses the user has starred.
///
/// Keyed by `srsKey` (pack + book + reference) rather than `Verse.id`, for the
/// same reason SRS and learning progress are: the two translation bundles give
/// the same card different ids, and a favourite should survive switching
/// between them — you starred the verse, not the edition.
@MainActor
final class FavoritesStore: ObservableObject {

    static let shared = FavoritesStore()

    /// The name the favourites collection goes by wherever it's shown as a pack.
    static let packName = "Favourites"

    @Published private(set) var keys: Set<String>

    private let storage: ProgressStorage
    private static let storageKey = "favorites.verseKeys.v1"

    private init(storage: ProgressStorage = .shared) {
        self.storage = storage
        keys = Set(storage.stringArray(forKey: Self.storageKey) ?? [])
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(externalChange(_:)),
            name: ProgressStorage.didChangeExternally,
            object: nil
        )
    }

    @objc private func externalChange(_ note: Notification) {
        guard note.affectsAny(of: [Self.storageKey]) else { return }
        let incoming = Set(storage.stringArray(forKey: Self.storageKey) ?? [])
        guard incoming != keys else { return }
        keys = incoming
        cachedVerses = nil
    }

    func isFavorite(_ verse: Verse) -> Bool {
        !verse.srsKey.isEmpty && keys.contains(verse.srsKey)
    }

    @discardableResult
    func toggle(_ verse: Verse) -> Bool {
        guard !verse.srsKey.isEmpty else { return false }
        let nowFavorite: Bool
        if keys.contains(verse.srsKey) {
            keys.remove(verse.srsKey)
            nowFavorite = false
        } else {
            keys.insert(verse.srsKey)
            nowFavorite = true
        }
        persist()
        return nowFavorite
    }

    func remove(_ verse: Verse) {
        guard keys.remove(verse.srsKey) != nil else { return }
        persist()
    }

    /// Starred verses from `packs`, in catalogue order.
    ///
    /// Filtered from the live pack list rather than stored as verse copies, so a
    /// verse whose text is corrected — or whose pack the user has since hidden —
    /// is reflected here without any migration.
    ///
    /// Memoized: the Packs grid asks for this inside `body`, which runs on every
    /// frame of the search-bar animation, and scanning the catalogue that often
    /// costs visible frames. Invalidated by the star set changing or the pack set
    /// changing, which is everything it depends on.
    func verses(in packs: [Pack]) -> [Verse] {
        guard !keys.isEmpty else { return [] }
        let token = Catalogue.fingerprint(packs) ^ keys.hashValue
        if let cachedVerses, cachedVerses.token == token { return cachedVerses.verses }
        let matched = Catalogue.verses(in: packs).filter { keys.contains($0.srsKey) }
        cachedVerses = (token, matched)
        return matched
    }

    private var cachedVerses: (token: Int, verses: [Verse])?

    /// The favourites presented as a pack, so every surface that takes a `Pack`
    /// — the study screen, the grid, the quiz picker — can show it with no
    /// special-casing. `nil` when nothing is starred; there's nothing to open.
    func pack(in packs: [Pack]) -> Pack? {
        let verses = verses(in: packs)
        guard !verses.isEmpty else { return nil }
        return Pack(name: Self.packName, color: "#E5A50A",
                    accentText: "\u{2605}", verses: verses)
    }

    func clear() {
        guard !keys.isEmpty else { return }
        keys = []
        persist()
    }

    private func persist() {
        cachedVerses = nil
        storage.set(Array(keys), forKey: Self.storageKey)
    }
}
