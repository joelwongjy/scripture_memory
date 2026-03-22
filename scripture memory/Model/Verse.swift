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

    /// The title split into individual words.
    var titleWords: [String] { title.wordTokens }

    /// The verse body split into individual words.
    var verseWords: [String] { verse.wordTokens }
}
