import Foundation

/// Where a verse sits in its printed pack, and the short code that names it.
///
/// The published material numbers every card — TMS 60 by lettered section
/// (`C-7`), the DEP booklets and the 180 series as one straight run per pack.
/// That number is how people actually refer to a verse to each other and how
/// they find it in the booklet, so any list of verses needs to show it.
///
/// Numbering comes from each pack's published order, never from the list on
/// screen: shuffle reorders the session and a quiz uses a subset, and neither
/// may renumber a card whose number is fixed in print.
enum VerseNumbering {

    /// 1-based position of a verse within its section, keyed by `srsKey` so the
    /// number survives a translation switch.
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

    /// Short label for each pack, e.g. `DEP 2: Quiet Time` → `DEP 2`. Built from
    /// the catalogue so the five 180-series packs get their series number, which
    /// their names carry only as a subtitle (`… · Growing in Faith`).
    private static let packCodes: [String: String] = {
        var map: [String: String] = [:]
        var seriesNumber = 0
        for pack in packsNIV84 {
            if pack.name.hasPrefix("TMS 180") {
                seriesNumber += 1
                map[pack.name] = "TMS 180 S\(seriesNumber)"
            } else if pack.name.hasPrefix("DEP "),
                      let colon = pack.name.firstIndex(of: ":") {
                map[pack.name] = String(pack.name[..<colon])
            } else if pack.name == "5 Assurances" {
                map[pack.name] = "5A"
            } else {
                map[pack.name] = pack.name
            }
        }
        return map
    }()

    static func position(of verse: Verse) -> Int? { positions[verse.srsKey] }

    /// Short pack label on its own, e.g. `"DEP 2"`.
    static func packCode(for packName: String) -> String {
        packCodes[packName] ?? packName
    }

    /// The card's printed number, e.g. `"DEP 1-9"`, `"TMS 60 C-7"`, `"5A-3"`.
    /// `nil` for a verse built outside the catalogue (previews, ad-hoc
    /// construction), which has no printed card to name.
    static func code(for verse: Verse) -> String? {
        guard !verse.packName.isEmpty, let position = positions[verse.srsKey] else { return nil }
        let pack = packCode(for: verse.packName)
        return verse.subpack.isEmpty ? "\(pack)-\(position)"
                                     : "\(pack) \(verse.subpack)-\(position)"
    }
}
