import Foundation

/// The caption in a flashcard's bottom-left corner.
///
/// TMS 60 shows the card's number in its lettered section and the section's
/// title (`"A-12 · Live the New Life"`). The DEP booklets and the TMS 180
/// series show the numbered part the card sits in (`"2. What is Quiet Time?"`).
/// *Beginning with Christ* is one numbered run under a single title. Every
/// other pack shows its name.
enum CardFooter {

    private static let wholePackTitles: [String: String] = [
        "5 Assurances": "Beginning with Christ",
    ]

    static func label(for verse: Verse, fallbackPack: String = "") -> String {
        let pack = verse.packName.isEmpty ? fallbackPack : verse.packName
        if !verse.part.isEmpty {
            guard !verse.subpack.isEmpty, let position = VerseNumbering.position(of: verse),
                  let dot = verse.part.range(of: ". ") else { return verse.part }
            return "\(verse.subpack)-\(position) · \(verse.part[dot.upperBound...])"
        }
        guard let title = wholePackTitles[pack], verse.subpack.isEmpty,
              let position = VerseNumbering.position(of: verse) else { return pack }
        return "\(position) · \(title)"
    }

    /// Heading for the group a verse sits in, for lists of a pack's cards.
    static func groupHeading(for verse: Verse) -> String? {
        verse.part.isEmpty ? nil : verse.part
    }
}
