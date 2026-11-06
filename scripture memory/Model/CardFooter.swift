import Foundation

/// The caption in a flashcard's bottom-left corner.
///
/// TMS 60 shows the card's number in its lettered section and the section's
/// title (`"A-12 · Live the New Life"`). The DEP booklets and the TMS 180
/// series show the numbered part the card sits in (`"2. What is Quiet Time?"`).
/// *Beginning with Christ* is one numbered run under a single title. Every
/// other pack shows its name.
enum CardFooter {

    private static let sectionTitles: [String: [String: String]] = [
        "TMS 60": [
            "A": "Live the New Life",
            "B": "Proclaim Christ",
            "C": "Rely on God's Resources",
            "D": "Be Christ's Disciple",
            "E": "Grow in Christlikeness",
        ],
    ]

    private static let wholePackTitles: [String: String] = [
        "5 Assurances": "Beginning with Christ",
    ]

    static func label(for verse: Verse, fallbackPack: String = "") -> String {
        let pack = verse.packName.isEmpty ? fallbackPack : verse.packName
        if let part = PackParts.heading(of: verse) { return part }
        guard let title = seriesTitle(pack: pack, section: verse.subpack),
              let position = VerseNumbering.position(of: verse) else { return pack }
        let number = verse.subpack.isEmpty ? "\(position)" : "\(verse.subpack)-\(position)"
        return "\(number) · \(title)"
    }

    /// Heading for the group a verse sits in, for lists of a pack's cards.
    static func groupHeading(for verse: Verse) -> String? {
        if let part = PackParts.heading(of: verse) { return part }
        guard !verse.subpack.isEmpty, let title = sectionTitles[verse.packName]?[verse.subpack] else { return nil }
        return "\(verse.subpack). \(title)"
    }

    private static func seriesTitle(pack: String, section: String) -> String? {
        section.isEmpty ? wholePackTitles[pack] : sectionTitles[pack]?[section]
    }
}

/// The numbered parts the DEP booklets and TMS 180 series are printed in, each
/// starting at the card named by its `cardUid`.
enum PackParts {

    private static let starts: [String: [(cardUid: String, title: String)]] = [
        "DEP 2: Quiet Time": [
            ("c8a38fe982d5b7f6", "Why do we have Quiet Time?"),
            ("e1b2445ad26a4e7a", "What is Quiet Time?"),
            ("6938e6832d16b354", "Examples of Quiet Time"),
        ],
        "DEP 3: The Word": [
            ("41e9f49d662c3fb0", "Authority of the Word"),
            ("77619ffd87cc4ba2", "Value of the Word"),
            ("89872cec45a5b4a9", "Attitude of the Word"),
            ("6ebeaffe80b2478b", "How to take in the Word (Word Hand Illustration)"),
        ],
        "DEP 4: Prayer": [
            ("9d12f07eadc1c641", "Command of prayer"),
            ("c8861483a5122975", "Promises and blessings of prayer"),
            ("ef7995099e124a44", "Conditions for answered prayer"),
            ("8f7c17711adcc2db", "Examples of prayer"),
            ("325f2fbdd4b36141", "Prayer Hand Illustration"),
        ],
        "DEP 5: Fellowship": [
            ("851be69006bec95c", "Foundation of Christian Fellowship"),
            ("9a03ddf552b9aca7", "Importance of Fellowship"),
            ("0c9b1f24e70a1d22", "Essentials of Fellowship"),
            ("05ffe60782e4a962", "Attitude of Fellowship"),
            ("70766a8c061484a1", "Problem solving in Fellowship"),
        ],
        "DEP 6: Witnessing": [
            ("42d32896a4d2dbc4", "Who is responsible for witnessing?"),
            ("8450d0c69ccff067", "Why should we witness?"),
            ("5a562c26b910f45c", "How do we witness?"),
            ("6caa572ca7098f83", "Examples of witness"),
            ("74ad102a507ac9de", "Bridge Illustration"),
        ],
        "DEP 7: The Lordship of Christ": [
            ("e3826d02963fa08f", "We must believe in the Lordship of Christ"),
            ("5fea29f2b0512d37", "Blessings when surrendering to the Lordship"),
            ("0871aa32bb0314d1", "What to surrender in the Lordship"),
            ("4910b66021ad4396", "Paragons of surrendering to the Lordship"),
        ],
        "TMS 180 · Getting to Know God": [
            ("ad0fd6a5607c6206", "Jesus Christ"),
            ("6c11e294ab00721e", "Holy Spirit"),
            ("63af1504260b6d44", "God"),
        ],
        "TMS 180 · Growing in Love": [
            ("11e78ee8c60ce5c3", "Love in Speech"),
            ("53a7b4e11dacac07", "Love in Response"),
            ("dc3a406c36c50e6e", "Love in Action"),
        ],
        "TMS 180 · Growing in Faith": [
            ("ef02d3aee1d50539", "Promises"),
            ("1abaf7aa796fed7a", "Word"),
            ("c371f333631da31e", "Faith"),
        ],
        "TMS 180 · Walking in Victory": [
            ("ef6c99115ef786a8", "Victory"),
            ("6c813d6dbaa848c7", "Purity"),
            ("d8e4fa462c36c12c", "Prayer"),
        ],
        "TMS 180 · Sharing Christ with Others": [
            ("2d8f6a42022b4fac", "Evangelism"),
            ("1af4487bab249a9c", "Excuses"),
            ("485db829f2e09ccc", "Believer's Position in Christ"),
        ],
    ]

    private static let parts: [String: Int] = {
        var map: [String: Int] = [:]
        for packs in [packsNIV84, packsNIV11] {
            for pack in packs {
                guard let list = starts[pack.name] else { continue }
                var part = 0
                for verse in pack.verses {
                    if let uid = verse.cardUid, part < list.count, list[part].cardUid == uid { part += 1 }
                    if part > 0 { map[verse.srsKey] = part }
                }
            }
        }
        return map
    }()

    /// 1-based part number, or `nil` for a pack that isn't printed in parts.
    static func part(of verse: Verse) -> Int? { parts[verse.srsKey] }

    static func heading(of verse: Verse) -> String? {
        guard let part = part(of: verse), let list = starts[verse.packName], part <= list.count else { return nil }
        return "\(part). \(list[part - 1].title)"
    }
}
