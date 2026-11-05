import Foundation

struct UserVerse: Codable, Identifiable, Equatable {
    var id: String
    var title: String
    var text: String
    var book: String
    var reference: String
    var version: String?

    static func newID() -> String {
        "u" + UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(15).lowercased()
    }

    var numericID: Int {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in id.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001b3
        }
        return 1_000_000 + Int(hash % 1_000_000_000)
    }
}

struct UserPack: Codable, Identifiable, Equatable {
    var id: String
    var name: String
    var color: String
    var verses: [UserVerse]

    static let defaultName = "OYO"
    static let subtitle = "On Your Own"

    static let colors: [String] = [
        "#C8252C",
        "#0F8A4B",
        "#1F5FA8",
        "#E08A1E",
        "#5E3A87",
        "#3C3C43",
    ]

    var pack: Pack {
        Pack(name: name, color: color, accentText: "",
             verses: verses.map { v in
                 Verse(id: v.numericID, title: v.title, verse: v.text, book: v.book,
                       reference: v.reference, subpack: "",
                       version: v.version.flatMap { $0.uppercased() == "NIV" ? nil : $0 },
                       cardUid: v.id, packName: name)
             },
             userPackID: id)
    }
}
