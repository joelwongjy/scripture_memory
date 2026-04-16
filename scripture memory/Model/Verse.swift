import Foundation

struct Pack: Hashable, Codable, Identifiable {
    var id: String { name }
    let name:       String
    let color:      String
    let accentText: String
    let verses:     [Verse]
}

struct Verse: Hashable, Codable, Identifiable {
    let id:        Int
    let title:     String
    let verse:     String
    let book:      String
    let reference: String
    let subpack:   String

    /// Owning pack's name. Not present in JSON — injected by `ModelData`
    /// after decode so the cross-version SRS key can be built.
    var packName: String = ""

    private enum CodingKeys: String, CodingKey {
        case id, title, verse, book, reference, subpack
    }

    /// The title split into individual words.
    var titleWords: [String] { title.wordTokens }

    /// The verse body split into individual words.
    var verseWords: [String] { verse.wordTokens }

    /// Stable cross-version SRS key: pack + canonical book + normalized reference.
    /// Empty `packName` (e.g. ad-hoc Verse construction) yields a usable but
    /// pack-less key — fine for non-SRS code paths.
    var srsKey: String {
        SRSKey.make(packName: packName, book: book, reference: reference)
    }
}
