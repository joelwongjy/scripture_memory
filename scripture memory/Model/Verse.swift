import Foundation

struct Pack: Hashable, Codable, Identifiable {
    var id: String { name }
    var name: String
    var color: String
    var accentText: String
    var verses: [Verse]
}

struct Verse: Hashable, Codable, Identifiable {
    var id: Int
    var title: String
    var verse: String
    var book: String
    var reference: String
    var subpack: String
}
