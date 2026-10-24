import Foundation

/// Where you were in each pack, so reopening a pack lands on the card you left
/// instead of card 1. Kept on this device only: it's a convenience, not progress.
enum PackPositions {
    private static let key = "packPositions.v1"

    /// Remember `verse` as the place to reopen `packName`.
    static func save(_ verse: Verse, inPack packName: String, defaults: UserDefaults = .standard) {
        var all = defaults.dictionary(forKey: key) as? [String: String] ?? [:]
        all[packName] = verse.srsKey
        defaults.set(all, forKey: key)
    }

    /// The card to open `pack` on: where you left it, else the verse you're
    /// learning if it's in this pack, else the first card.
    static func startIndex(for pack: Pack, currentKey: String?, defaults: UserDefaults = .standard) -> Int {
        let saved = (defaults.dictionary(forKey: key) as? [String: String])?[pack.name]
        for target in [saved, currentKey].compactMap({ $0 }) {
            if let i = pack.verses.firstIndex(where: { $0.srsKey == target }) { return i }
        }
        return 0
    }
}
