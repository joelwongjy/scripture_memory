import Foundation

var packsNIV84: [Pack] = loadPacks("verseData.json")
var packsNIV11: [Pack] = loadPacks("verseDataNIV11.json")

/// Loads a packs JSON and back-fills `Verse.packName` so `Verse.srsKey` is valid.
func loadPacks(_ filename: String) -> [Pack] {
    let raw: [Pack] = load(filename)
    return raw.map { pack in
        let withPack: [Verse] = pack.verses.map { v in
            var w = v
            w.packName = pack.name
            return w
        }
        return Pack(name: pack.name,
                    color: pack.color,
                    accentText: pack.accentText,
                    verses: withPack)
    }
}

func load<T: Decodable>(_ filename: String) -> T {
    let data: Data

    guard let file = Bundle.main.url(forResource: filename, withExtension: nil)
        else {
            fatalError("Couldn't find \(filename) in main bundle.")
    }

    do {
        data = try Data(contentsOf: file)
    } catch {
        fatalError("Couldn't load \(filename) from main bundle:\n\(error)")
    }

    do {
        let decoder = JSONDecoder()
        return try decoder.decode(T.self, from: data)
    } catch {
        fatalError("Couldn't parse \(filename) as \(T.self):\n\(error)")
    }
}
