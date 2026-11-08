import Foundation
import CommonCrypto
import SQLite3

struct AnkiExportCard: Equatable {
    var id: String
    var reference: String
    var title: String
    var text: String
    var version: String?
    var state: SRSCardState?
    var isLearnt: Bool
}

struct AnkiExportDeck: Equatable {
    var name: String
    var cards: [AnkiExportCard]
}

enum AnkiPackageWriter {

    static let rootDeck = AnkiVerseImport.exportRoot
    static let noteTypeName = "Scripture Memory"
    static let fieldNames = ["Reference", "Title", "Verse", "Version"]
    private static let noteTypeID: Int64 = 1_731_000_000_000
    private static let rolloverHour = 4

    static func write(_ decks: [AnkiExportDeck], now: Date = Date(), timeZone: TimeZone = .current) throws -> Data {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("anki-export-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("collection.anki2")
        try writeCollection(decks, to: file.path, now: now, timeZone: timeZone)
        let collection = try Data(contentsOf: file)
        return AnkiZipWriter.archive([("collection.anki2", collection), ("media", Data("{}".utf8))])
    }

    static func creation(now: Date, timeZone: TimeZone) -> Int64 {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let shifted = now.addingTimeInterval(-Double(rolloverHour) * 3_600)
        let day = calendar.startOfDay(for: shifted)
        return Int64(day.addingTimeInterval(Double(rolloverHour) * 3_600).timeIntervalSince1970)
    }

    private static func writeCollection(_ decks: [AnkiExportDeck], to path: String, now: Date, timeZone: TimeZone) throws {
        let database = try AnkiWritableDatabase(path: path)
        let nowSeconds = Int64(now.timeIntervalSince1970)
        let crt = creation(now: now, timeZone: timeZone)
        let minutesWest = -timeZone.secondsFromGMT(for: now) / 60

        try database.execute(schema)
        try database.execute("begin")

        var deckJSON: [String: Any] = ["1": deck(id: 1, name: "Default", now: nowSeconds)]
        deckJSON["\(noteTypeID + 1)"] = deck(id: noteTypeID + 1, name: rootDeck, now: nowSeconds)

        var noteID = nowSeconds * 1_000
        var cardID = nowSeconds * 1_000
        var reviewID = nowSeconds * 1_000
        var usedReviewIDs = Set<Int64>()
        var position: Int64 = 0

        for (index, exportDeck) in decks.enumerated() {
            let deckID = noteTypeID + 2 + Int64(index)
            deckJSON["\(deckID)"] = deck(id: deckID, name: "\(rootDeck)::\(exportDeck.name)", now: nowSeconds)
            for card in exportDeck.cards {
                noteID += 1
                cardID += 1
                let fields = [card.reference, card.title, card.text, card.version ?? ""].map(html)
                try database.run(
                    "insert into notes values (?, ?, ?, ?, -1, ' scripture-memory ', ?, ?, ?, 0, '')",
                    [.integer(noteID), .text("sm-" + card.id), .integer(noteTypeID), .integer(nowSeconds),
                     .text(fields.joined(separator: "\u{1F}")), .text(fields[0]), .integer(checksum(fields[0]))])

                let row = schedule(card, crt: crt, now: now, position: &position)
                try database.run(
                    "insert into cards values (?, ?, ?, 0, ?, -1, ?, ?, ?, ?, ?, ?, ?, ?, 0, 0, 0, '')",
                    [.integer(cardID), .integer(noteID), .integer(deckID), .integer(nowSeconds),
                     .integer(row.type), .integer(row.queue), .integer(row.due), .integer(row.interval),
                     .integer(row.factor), .integer(row.reps), .integer(row.lapses), .integer(row.left)])

                if let reviewed = card.state?.lastReviewed {
                    var id = Int64(reviewed.timeIntervalSince1970 * 1_000)
                    while !usedReviewIDs.insert(id).inserted { id += 1 }
                    reviewID = max(reviewID, id)
                    try database.run(
                        "insert into revlog values (?, ?, -1, 3, ?, 0, ?, 0, ?)",
                        [.integer(id), .integer(cardID), .integer(row.interval), .integer(row.factor),
                         .integer(row.type == 2 ? 1 : 0)])
                }
            }
        }

        let config: [String: Any] = [
            "schedVer": 2, "rollover": rolloverHour, "creationOffset": minutesWest,
            "nextPos": position + 1, "curDeck": 1, "activeDecks": [1],
        ]
        try database.run(
            "insert into col values (1, ?, ?, ?, 11, 0, 0, 0, ?, ?, ?, '{}', '{}')",
            [.integer(crt), .integer(nowSeconds * 1_000), .integer(nowSeconds * 1_000),
             .text(json(config)), .text(json(["\(noteTypeID)": noteType(now: nowSeconds)])), .text(json(deckJSON))])
        try database.execute("commit")
    }

    struct CardRow: Equatable {
        var type: Int64
        var queue: Int64
        var due: Int64
        var interval: Int64
        var factor: Int64
        var reps: Int64
        var lapses: Int64
        var left: Int64
    }

    static func schedule(_ card: AnkiExportCard, crt: Int64, now: Date, position: inout Int64) -> CardRow {
        func day(_ date: Date) -> Int64 {
            Int64(((date.timeIntervalSince1970 - Double(crt)) / 86_400).rounded(.down))
        }
        guard let state = card.state else {
            if card.isLearnt {
                return CardRow(type: 2, queue: 2, due: day(now), interval: 1, factor: 2_500, reps: 1, lapses: 0, left: 0)
            }
            position += 1
            return CardRow(type: 0, queue: 0, due: position, interval: 0, factor: 0, reps: 0, lapses: 0, left: 0)
        }
        let factor = Int64((state.ease * 1_000).rounded())
        let reps = Int64(state.reps)
        let lapses = Int64(state.lapses)
        switch state.phase {
        case .review:
            return CardRow(type: 2, queue: 2, due: day(state.due), interval: max(1, Int64(state.interval.rounded())),
                           factor: factor, reps: reps, lapses: lapses, left: 0)
        case .learning:
            let due = Int64(state.due.timeIntervalSince1970)
            if state.interval > 0 {
                return CardRow(type: 3, queue: 1, due: due, interval: max(1, Int64(state.interval.rounded())),
                               factor: factor, reps: reps, lapses: lapses, left: 1_001)
            }
            return CardRow(type: 1, queue: 1, due: due, interval: 0, factor: factor, reps: reps, lapses: lapses, left: 1_001)
        }
    }

    static func html(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\n", with: "<br>")
    }

    static func checksum(_ field: String) -> Int64 {
        var digest = [UInt8](repeating: 0, count: Int(CC_SHA1_DIGEST_LENGTH))
        let bytes = Array(field.utf8)
        _ = CC_SHA1(bytes, CC_LONG(bytes.count), &digest)
        return digest.prefix(4).reduce(Int64(0)) { $0 << 8 | Int64($1) }
    }

    private static func json(_ object: Any) -> String {
        let data = (try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])) ?? Data("{}".utf8)
        return String(decoding: data, as: UTF8.self)
    }

    private static func deck(id: Int64, name: String, now: Int64) -> [String: Any] {
        [
            "id": id, "name": name, "mod": now, "usn": -1, "lrnToday": [0, 0], "revToday": [0, 0],
            "newToday": [0, 0], "timeToday": [0, 0], "collapsed": false, "browserCollapsed": false,
            "desc": "", "dyn": 0, "conf": 1, "extendNew": 0, "extendRev": 0,
        ]
    }

    private static func noteType(now: Int64) -> [String: Any] {
        [
            "id": noteTypeID, "name": noteTypeName, "type": 0, "mod": now, "usn": -1, "sortf": 0, "did": 1,
            "tmpls": [[
                "name": "Card 1", "ord": 0,
                "qfmt": "<div class=title>{{Title}}</div><div class=reference>{{Reference}}</div>",
                "afmt": "{{FrontSide}}<hr id=answer><div class=verse>{{Verse}}</div>",
                "bqfmt": "", "bafmt": "", "did": NSNull(),
            ]],
            "flds": fieldNames.enumerated().map { index, name in
                ["name": name, "ord": index, "sticky": false, "rtl": false, "font": "Arial", "size": 20] as [String: Any]
            },
            "css": ".card { font-family: Georgia, serif; font-size: 22px; text-align: center; color: black; background: white; }\n.title { font-weight: bold; }\n.reference { margin-top: 8px; }\n.verse { text-align: left; line-height: 1.4; }",
            "latexPre": "\\documentclass[12pt]{article}\n\\special{papersize=3in,5in}\n\\usepackage[utf8]{inputenc}\n\\usepackage{amssymb,amsmath}\n\\pagestyle{empty}\n\\setlength{\\parindent}{0in}\n\\begin{document}\n",
            "latexPost": "\\end{document}", "latexsvg": false,
            "req": [[0, "any", [0, 1]]], "tags": [], "vers": [],
        ]
    }

    private static let schema = """
        create table col (id integer primary key, crt integer not null, mod integer not null, scm integer not null, ver integer not null, dty integer not null, usn integer not null, ls integer not null, conf text not null, models text not null, decks text not null, dconf text not null, tags text not null);
        create table notes (id integer primary key, guid text not null, mid integer not null, mod integer not null, usn integer not null, tags text not null, flds text not null, sfld integer not null, csum integer not null, flags integer not null, data text not null);
        create table cards (id integer primary key, nid integer not null, did integer not null, ord integer not null, mod integer not null, usn integer not null, type integer not null, queue integer not null, due integer not null, ivl integer not null, factor integer not null, reps integer not null, lapses integer not null, left integer not null, odue integer not null, odid integer not null, flags integer not null, data text not null);
        create table revlog (id integer primary key, cid integer not null, usn integer not null, ease integer not null, ivl integer not null, lastIvl integer not null, factor integer not null, time integer not null, type integer not null);
        create table graves (usn integer not null, oid integer not null, type integer not null);
        create index ix_notes_usn on notes (usn);
        create index ix_cards_usn on cards (usn);
        create index ix_revlog_usn on revlog (usn);
        create index ix_cards_nid on cards (nid);
        create index ix_cards_sched on cards (did, queue, due);
        create index ix_revlog_cid on revlog (cid);
        create index ix_notes_csum on notes (csum);
        """
}

private final class AnkiWritableDatabase {
    enum Value {
        case integer(Int64)
        case text(String)
    }

    private var handle: OpaquePointer?
    private static let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    init(path: String) throws {
        guard sqlite3_open(path, &handle) == SQLITE_OK else {
            sqlite3_close(handle)
            throw AnkiImportError.unreadable
        }
    }

    deinit { sqlite3_close(handle) }

    func execute(_ sql: String) throws {
        guard sqlite3_exec(handle, sql, nil, nil, nil) == SQLITE_OK else { throw AnkiImportError.unreadable }
    }

    func run(_ sql: String, _ values: [Value]) throws {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(handle, sql, -1, &statement, nil) == SQLITE_OK else { throw AnkiImportError.unreadable }
        defer { sqlite3_finalize(statement) }
        for (index, value) in values.enumerated() {
            let position = Int32(index + 1)
            switch value {
            case .integer(let number): sqlite3_bind_int64(statement, position, number)
            case .text(let text): sqlite3_bind_text(statement, position, text, -1, Self.transient)
            }
        }
        guard sqlite3_step(statement) == SQLITE_DONE else { throw AnkiImportError.unreadable }
    }
}

enum AnkiZipWriter {
    static func archive(_ entries: [(name: String, data: Data)]) -> Data {
        var output = Data()
        var directory = Data()
        for entry in entries {
            let name = Data(entry.name.utf8)
            let crc = crc32(entry.data)
            let offset = UInt32(output.count)
            output.append(le32(0x0403_4B50))
            output.append(le16(20)); output.append(le16(0x0800)); output.append(le16(0))
            output.append(le16(0)); output.append(le16(0x21))
            output.append(le32(crc)); output.append(le32(UInt32(entry.data.count))); output.append(le32(UInt32(entry.data.count)))
            output.append(le16(UInt16(name.count))); output.append(le16(0))
            output.append(name); output.append(entry.data)

            directory.append(le32(0x0201_4B50))
            directory.append(le16(20)); directory.append(le16(20)); directory.append(le16(0x0800)); directory.append(le16(0))
            directory.append(le16(0)); directory.append(le16(0x21))
            directory.append(le32(crc)); directory.append(le32(UInt32(entry.data.count))); directory.append(le32(UInt32(entry.data.count)))
            directory.append(le16(UInt16(name.count))); directory.append(le16(0)); directory.append(le16(0))
            directory.append(le16(0)); directory.append(le16(0)); directory.append(le32(0))
            directory.append(le32(offset)); directory.append(name)
        }
        let directoryOffset = UInt32(output.count)
        output.append(directory)
        output.append(le32(0x0605_4B50))
        output.append(le16(0)); output.append(le16(0))
        output.append(le16(UInt16(entries.count))); output.append(le16(UInt16(entries.count)))
        output.append(le32(UInt32(directory.count))); output.append(le32(directoryOffset)); output.append(le16(0))
        return output
    }

    private static let table: [UInt32] = (0..<256).map { n in
        (0..<8).reduce(UInt32(n)) { c, _ in c & 1 == 1 ? 0xEDB8_8320 ^ (c >> 1) : c >> 1 }
    }

    static func crc32(_ data: Data) -> UInt32 {
        ~data.reduce(UInt32.max) { table[Int(($0 ^ UInt32($1)) & 0xFF)] ^ ($0 >> 8) }
    }

    private static func le16(_ value: UInt16) -> Data { withUnsafeBytes(of: value.littleEndian) { Data($0) } }
    private static func le32(_ value: UInt32) -> Data { withUnsafeBytes(of: value.littleEndian) { Data($0) } }
}
