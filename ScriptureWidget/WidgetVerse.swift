import Foundation

/// A verse the widget can render. Decoded from the bundled `verseData.json`
/// (for the specific-verse picker) and also reconstructed from the shared App
/// Group (for the live "current learning verse"). `packName` is injected after
/// decode, mirroring how the app builds its own `Verse`.
struct WidgetVerse: Decodable, Hashable, Identifiable {
    let title:     String
    let verse:     String
    let book:      String
    let reference: String
    var packName:  String = ""

    private enum CodingKeys: String, CodingKey { case title, verse, book, reference }

    /// Stable identity across the catalogue: pack + canonical reference.
    var id: String { "\(packName)|\(book) \(reference)" }

    /// Full human reference, e.g. "John 3:16".
    var fullReference: String { "\(book) \(reference)" }

    /// Deep link back into the app — open this verse in Read mode, in its pack.
    var deepLinkURL: URL? {
        var c = URLComponents()
        c.scheme = "scripturememory"
        c.host   = "read"
        c.queryItems = [
            URLQueryItem(name: "pack", value: packName),
            URLQueryItem(name: "book", value: book),
            URLQueryItem(name: "ref",  value: reference),
        ]
        return c.url
    }
}

private struct WidgetPack: Decodable {
    let name:   String
    let verses: [WidgetVerse]
}

/// The bundled verse catalogue (pack names injected) — used by the configuration
/// picker and as a fallback when no current learning verse is available yet.
enum VerseLibrary {
    static let allVerses: [WidgetVerse] = {
        guard let url   = Bundle.main.url(forResource: "verseData", withExtension: "json"),
              let data  = try? Data(contentsOf: url),
              let packs = try? JSONDecoder().decode([WidgetPack].self, from: data)
        else { return [] }
        return packs.flatMap { pack in
            pack.verses.map { var v = $0; v.packName = pack.name; return v }
        }
    }()

    static func verse(id: String) -> WidgetVerse? {
        allVerses.first { $0.id == id }
    }
}

/// Reads the live snapshot the app writes into the shared App Group: current
/// learning verse + streak + cards due today (see `WidgetBridge` on the app side).
enum SharedStore {
    static let appGroup    = "group.joel.scripture-memory"
    static let snapshotKey = "widget.snapshot.v1"

    struct SharedVerse: Codable {
        var title, verse, book, reference, packName: String
    }
    struct WeekDay: Codable {
        var letter: String
        var done:   Bool
        var today:  Bool
    }
    struct Snapshot: Codable {
        var verse:    SharedVerse?
        var streak:   Int
        var dueToday: Int
        var learned:  Int
        var week:     [WeekDay]
    }

    static func snapshot() -> Snapshot? {
        guard let data = UserDefaults(suiteName: appGroup)?.data(forKey: snapshotKey),
              let s = try? JSONDecoder().decode(Snapshot.self, from: data) else { return nil }
        return s
    }

    static func currentLearningVerse() -> WidgetVerse? {
        guard let s = snapshot()?.verse else { return nil }
        var v = WidgetVerse(title: s.title, verse: s.verse, book: s.book, reference: s.reference)
        v.packName = s.packName
        return v
    }
}
