import Foundation

/// The caption in a flashcard's bottom-left corner.
///
/// TMS 60 shows the card's number in its lettered section and the section's
/// title (`"A-12 · Live the New Life"`). DEP cards show their booklet and, when
/// it has parts, the part (`"II. Quiet Time · 2. What is Quiet Time?"`). The
/// TMS 180 series shows its part (`"2. Holy Spirit"`).
/// *Beginning with Christ* is one numbered run under a single title. Every
/// other pack shows its name.
enum CardFooter {

    private static let wholePackTitles: [String: String] = [
        "5 Assurances": "Beginning with Christ",
    ]

    static func label(for verse: Verse, fallbackPack: String = "") -> String {
        let pack = verse.packName.isEmpty ? fallbackPack : verse.packName
        if let booklet = booklet(of: pack) {
            return verse.part.isEmpty ? booklet : "\(booklet) · \(verse.part)"
        }
        if !verse.part.isEmpty {
            guard !verse.subpack.isEmpty, let position = VerseNumbering.position(of: verse),
                  let dot = verse.part.range(of: ". ") else { return verse.part }
            return "\(verse.subpack)-\(position) · \(verse.part[dot.upperBound...])"
        }
        guard let title = wholePackTitles[pack], verse.subpack.isEmpty,
              let position = VerseNumbering.position(of: verse) else { return pack }
        return "\(position) · \(title)"
    }

    private static let romanNumerals = ["I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X"]

    private static func booklet(of pack: String) -> String? {
        guard pack.hasPrefix("DEP ") else { return nil }
        let halves = pack.dropFirst(4).split(separator: ":", maxSplits: 1)
        guard halves.count == 2, let number = Int(halves[0]),
              romanNumerals.indices.contains(number - 1) else { return nil }
        return "\(romanNumerals[number - 1]). \(halves[1].trimmingCharacters(in: .whitespaces))"
    }

    /// Heading for the group a verse sits in, for lists of a pack's cards.
    static func groupHeading(for verse: Verse) -> String? {
        verse.part.isEmpty ? nil : verse.part
    }
}
