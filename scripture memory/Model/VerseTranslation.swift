import Foundation

enum VerseTranslation {

    static let niv = "NIV"
    static let niv84 = "NIV84"

    static let choices: [String] = [niv, niv84, "ESV", "NKJV", "KJV", "NLT", "NASB", "CSB"]

    static func displayName(_ code: String) -> String {
        switch code {
        case niv:   return "NIV (2011)"
        case niv84: return "NIV (1984)"
        default:    return code
        }
    }

    private static let youVersionIDs: [String: (id: Int, code: String)] = [
        niv: (111, "NIV"), niv84: (111, "NIV"), "ESV": (59, "ESV"), "NKJV": (114, "NKJV"),
        "KJV": (1, "KJV"), "NLT": (116, "NLT"), "NASB": (2692, "NASB2020"), "CSB": (1713, "CSB"),
    ]

    static func bibleAppURL(for reference: BibleReference, translation: String) -> URL? {
        let version = youVersionIDs[translation.uppercased()] ?? youVersionIDs[niv]!
        var passage = "\(reference.book.usfm).\(reference.chapter)"
        let first = reference.verses.split(separator: ",").first.map(String.init) ?? ""
        let bounds = first.split(separator: "-").map(String.init)
        if let start = bounds.first, !start.isEmpty {
            passage += ".\(start)"
            if bounds.count == 2, !bounds[1].contains(":") { passage += "-\(bounds[1])" }
        }
        return URL(string: "https://www.bible.com/bible/\(version.id)/\(passage).\(version.code)")
    }
}
