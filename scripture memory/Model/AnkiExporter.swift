import Foundation

@MainActor
enum AnkiExporter {

    static let filename = "Scripture Memory.apkg"

    static func decks(for edition: BibleVersion) -> [AnkiExportDeck] {
        let srs = SRSStore.shared
        let learning = LearningStore.shared
        func card(_ verse: Verse, version: String?) -> AnkiExportCard {
            AnkiExportCard(id: verse.srsKey, reference: "\(verse.book) \(verse.reference)", title: verse.title,
                           text: verse.verse, version: version, state: srs.state(for: verse),
                           isLearnt: learning.isLearnt(verse))
        }

        var decks: [AnkiExportDeck] = edition.bundledPacks.compactMap { pack in
            let printed = edition == .niv11 && BibleVersion.niv11PackNames.contains(pack.name) ? "NIV" : "NIV84"
            let cards = pack.verses.map { card($0, version: $0.pinnedVersion ?? printed) }
            guard cards.contains(where: { $0.state != nil || $0.isLearnt }) else { return nil }
            return AnkiExportDeck(name: pack.name, cards: cards)
        }
        for userPack in UserPackStore.shared.userPacks where !userPack.verses.isEmpty {
            let cards = zip(userPack.pack.verses, userPack.verses).map { card($0, version: $1.version) }
            decks.append(AnkiExportDeck(name: userPack.name, cards: cards))
        }
        return decks
    }

    static func exportFile(for edition: BibleVersion, now: Date = Date()) throws -> URL? {
        let decks = decks(for: edition)
        guard !decks.isEmpty else { return nil }
        let data = try AnkiPackageWriter.write(decks, now: now)
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("export", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent(filename)
        try data.write(to: url, options: .atomic)
        return url
    }
}
