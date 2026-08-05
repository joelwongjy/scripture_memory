import Foundation

/// The caption in a flashcard's bottom-left corner.
///
/// For packs published as numbered series — TMS 60's five lettered sections, and
/// the five assurances of *Beginning with Christ* — the caption is the card's own
/// printed number plus the series it belongs to (`"A-12 · Live the New Life"`).
/// Every other pack keeps the plain pack name it has always shown, since there's
/// no published series naming to put there.
enum CardFooter {

    /// Series names for packs whose cards are organised into lettered sections,
    /// keyed pack → section letter.
    private static let sectionTitles: [String: [String: String]] = [
        "TMS 60": [
            "A": "Live the New Life",
            "B": "Proclaim Christ",
            "C": "Rely on God's Resources",
            "D": "Be Christ's Disciple",
            "E": "Grow in Christ Likeness",
        ],
    ]

    /// Series names for packs that are one straight numbered run with no letters.
    private static let wholePackTitles: [String: String] = [
        "5 Assurances": "Beginning with Christ",
    ]

    /// Each verse's 1-based position within its series, keyed by `srsKey` so the
    /// numbering survives a translation switch.
    ///
    /// Taken from the pack's published order rather than the list on screen. The
    /// session's own order is reordered by shuffle and by picking a subset for a
    /// quiz, which would renumber a card whose number is fixed in the booklet —
    /// A-12 has to stay A-12 wherever it turns up.
    private static let positions: [String: Int] = {
        var map: [String: Int] = [:]
        for packs in [packsNIV84, packsNIV11] {
            for pack in packs {
                var countsBySection: [String: Int] = [:]
                for verse in pack.verses {
                    let position = (countsBySection[verse.subpack] ?? 0) + 1
                    countsBySection[verse.subpack] = position
                    map[verse.srsKey] = position
                }
            }
        }
        return map
    }()

    /// `fallbackPack` covers verses built outside the JSON (previews, ad-hoc
    /// construction) whose `packName` was never back-filled.
    static func label(for verse: Verse, fallbackPack: String = "") -> String {
        let pack = verse.packName.isEmpty ? fallbackPack : verse.packName
        guard let title = seriesTitle(pack: pack, section: verse.subpack),
              let position = positions[verse.srsKey] else { return pack }
        let number = verse.subpack.isEmpty ? "\(position)" : "\(verse.subpack)-\(position)"
        return "\(number) · \(title)"
    }

    private static func seriesTitle(pack: String, section: String) -> String? {
        section.isEmpty ? wholePackTitles[pack] : sectionTitles[pack]?[section]
    }
}
