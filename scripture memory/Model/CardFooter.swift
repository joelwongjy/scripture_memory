import Foundation

/// The caption in a flashcard's bottom-left corner.
///
/// For packs published in numbered groups (TMS 60's lettered sections, the DEP
/// booklets' numbered parts, the three groups in each TMS 180 series) the
/// caption is the card's number in its group plus the group's title
/// (`"A-12 · Live the New Life"`). *Beginning with Christ* is one numbered run
/// under a single title. Every other pack shows its name.
enum CardFooter {

    /// Group titles keyed pack → the verse's `subpack`.
    private static let sectionTitles: [String: [String: String]] = [
        "TMS 60": [
            "A": "Live the New Life",
            "B": "Proclaim Christ",
            "C": "Rely on God's Resources",
            "D": "Be Christ's Disciple",
            "E": "Grow in Christlikeness",
        ],
        "DEP 2: Quiet Time": [
            "1": "Why do we have Quiet Time?",
            "2": "What is Quiet Time?",
            "3": "Examples of Quiet Time",
        ],
        "DEP 3: The Word": [
            "1": "Authority of the Word",
            "2": "Value of the Word",
            "3": "Attitude of the Word",
            "4": "How to take in the Word (Word Hand Illustration)",
        ],
        "DEP 4: Prayer": [
            "1": "Command of prayer",
            "2": "Promises and blessings of prayer",
            "3": "Conditions for answered prayer",
            "4": "Examples of prayer",
            "5": "Prayer Hand Illustration",
        ],
        "DEP 5: Fellowship": [
            "1": "Foundation of Christian Fellowship",
            "2": "Importance of Fellowship",
            "3": "Essentials of Fellowship",
            "4": "Attitude of Fellowship",
            "5": "Problem solving in Fellowship",
        ],
        "DEP 6: Witnessing": [
            "1": "Who is responsible for witnessing?",
            "2": "Why should we witness?",
            "3": "How do we witness?",
            "4": "Examples of witness",
            "5": "Bridge Illustration",
        ],
        "DEP 7: The Lordship of Christ": [
            "1": "We must believe in the Lordship of Christ",
            "2": "Blessings when surrendering to the Lordship",
            "3": "What to surrender in the Lordship",
            "4": "Paragons of surrendering to the Lordship",
        ],
        "TMS 180 · Getting to Know God": ["1": "Jesus Christ", "2": "Holy Spirit", "3": "God"],
        "TMS 180 · Growing in Love": ["1": "Love in Speech", "2": "Love in Response", "3": "Love in Action"],
        "TMS 180 · Growing in Faith": ["1": "Promises", "2": "Word", "3": "Faith"],
        "TMS 180 · Walking in Victory": ["1": "Victory", "2": "Purity", "3": "Prayer"],
        "TMS 180 · Sharing Christ with Others": [
            "1": "Evangelism", "2": "Excuses", "3": "Believer's Position in Christ",
        ],
    ]

    private static let wholePackTitles: [String: String] = [
        "5 Assurances": "Beginning with Christ",
    ]

    static func label(for verse: Verse, fallbackPack: String = "") -> String {
        let pack = verse.packName.isEmpty ? fallbackPack : verse.packName
        guard let title = seriesTitle(pack: pack, section: verse.subpack),
              let position = VerseNumbering.position(of: verse) else { return pack }
        let number = verse.subpack.isEmpty ? "\(position)" : "\(verse.subpack)-\(position)"
        return "\(number) · \(title)"
    }

    /// The group heading for a list of a pack's cards, e.g. `"2. What is Quiet Time?"`.
    static func sectionHeading(pack: String, section: String) -> String? {
        guard !section.isEmpty, let title = sectionTitles[pack]?[section] else { return nil }
        return "\(section). \(title)"
    }

    private static func seriesTitle(pack: String, section: String) -> String? {
        section.isEmpty ? wholePackTitles[pack] : sectionTitles[pack]?[section]
    }
}
