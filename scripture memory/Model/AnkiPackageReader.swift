import Foundation
import Compression
import SQLite3
import libzstd

extension AnkiImport {
    static func read(url: URL, timeZone: TimeZone = .current) throws -> AnkiImport {
        let isScoped = url.startAccessingSecurityScopedResource()
        defer { if isScoped { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url, options: .mappedIfSafe) else {
            throw AnkiImportError.unreadable
        }
        switch url.pathExtension.lowercased() {
        case "apkg", "colpkg":
            return try AnkiPackageReader.read(data, timeZone: timeZone)
        case "txt", "tsv", "csv":
            return try readText(data)
        default:
            if data.starts(with: AnkiZipArchive.localHeaderSignature) {
                return try AnkiPackageReader.read(data, timeZone: timeZone)
            }
            return try readText(data)
        }
    }

    private static func readText(_ data: Data) throws -> AnkiImport {
        guard let text = String(data: data, encoding: .utf8) else { throw AnkiImportError.unreadable }
        return try AnkiTextExport.parse(text)
    }
}

enum AnkiPackageReader {
    private static let collectionNames = ["collection.anki21b", "collection.anki21", "collection.anki2"]

    static func read(_ data: Data, timeZone: TimeZone) throws -> AnkiImport {
        let archive = try AnkiZipArchive(data)
        guard let name = collectionNames.first(where: archive.contains) else {
            throw AnkiImportError.unsupported("This package has no Anki collection in it.")
        }
        var collection = try archive.extract(name)
        if name.hasSuffix("b") {
            collection = try AnkiZstd.decompress(collection)
        }
        let file = FileManager.default.temporaryDirectory
            .appendingPathComponent("anki-\(UUID().uuidString).sqlite")
        defer { try? FileManager.default.removeItem(at: file) }
        try writeDatabase(collection, to: file)
        let database = try AnkiDatabase(path: file.path)
        return try AnkiCollectionReader(database: database, timeZone: timeZone).read()
    }

    private static func writeDatabase(_ data: Data, to file: URL) throws {
        let header = Data("SQLite format 3\u{0}".utf8)
        guard data.count >= 100, data.prefix(header.count) == header else { throw AnkiImportError.unreadable }
        var bytes = data
        let versionOffsets = [bytes.startIndex + 18, bytes.startIndex + 19]
        for offset in versionOffsets where bytes[offset] == 2 {
            bytes[offset] = 1
        }
        do {
            try bytes.write(to: file)
        } catch {
            throw AnkiImportError.unreadable
        }
    }
}

private struct AnkiCollectionReader {
    let database: AnkiDatabase
    let timeZone: TimeZone

    private struct NoteType {
        let name: String
        let fieldNames: [String]
    }

    func read() throws -> AnkiImport {
        let isModern = try !database.rows("select name from sqlite_master where type = 'table' and name = 'notetypes'").isEmpty
        let config = try isModern ? modernConfig() : legacyConfig()
        guard let creation = try database.rows("select crt from col").first?.first?.integer else {
            throw AnkiImportError.unreadable
        }
        let timing = AnkiCollectionTiming(
            creation: creation,
            schedulerVersion: Self.integer(config["schedVer"]),
            rollover: Self.integer(config["rollover"]),
            creationOffset: Self.integer(config["creationOffset"]),
            deviceMinutesWest: -timeZone.secondsFromGMT() / 60
        )
        let noteTypes = try isModern ? modernNoteTypes() : legacyNoteTypes()
        let decks = try isModern ? modernDecks() : legacyDecks()

        var lastReviews: [Int64: Int64] = [:]
        for row in try database.rows("select cid, max(id) from revlog where ease > 0 group by cid") {
            if let card = row[0].integer, let stamp = row[1].integer { lastReviews[card] = stamp }
        }

        var cardsByNote: [Int64: [(deck: Int64, schedule: AnkiCardSchedule)]] = [:]
        let cardRows = try database.rows(
            "select nid, did, type, queue, due, ivl, factor, reps, lapses, odue, odid, id from cards order by nid, ord, id"
        )
        for row in cardRows {
            let values = row.map { $0.integer ?? 0 }
            let cardRow = AnkiCardRow(
                type: Int(values[2]), queue: Int(values[3]), due: values[4], interval: values[5],
                factor: values[6], reps: Int(values[7]), lapses: Int(values[8]),
                originalDue: values[9], originalDeckID: values[10],
                lastReviewMilliseconds: lastReviews[values[11]]
            )
            let deck = values[10] != 0 ? values[10] : values[1]
            cardsByNote[values[0], default: []].append((deck, AnkiCardSchedule(row: cardRow, timing: timing)))
        }

        var notes: [AnkiNote] = []
        for row in try database.rows("select id, mid, tags, flds from notes order by id") {
            guard let id = row[0].integer, let typeID = row[1].integer else { continue }
            let noteType = noteTypes[typeID]
            var fieldNames = noteType?.fieldNames ?? []
            var fields = (row[3].text ?? "")
                .split(separator: "\u{1F}", omittingEmptySubsequences: false)
                .map { AnkiFieldCleaner.clean(String($0)) }
            while fieldNames.count < fields.count { fieldNames.append("Field \(fieldNames.count + 1)") }
            while fields.count < fieldNames.count { fields.append("") }
            let cards = cardsByNote[id] ?? []
            notes.append(AnkiNote(
                deck: cards.first.flatMap { decks[$0.deck] } ?? "",
                noteType: noteType?.name ?? "",
                fieldNames: fieldNames,
                fields: fields,
                tags: (row[2].text ?? "").split(whereSeparator: { $0.isWhitespace }).map(String.init),
                cards: cards.map(\.schedule)
            ))
        }
        guard !notes.isEmpty else { throw AnkiImportError.empty }
        return AnkiImport(notes: notes)
    }

    private static func integer(_ value: Any?) -> Int? {
        switch value {
        case let number as NSNumber where CFGetTypeID(number) != CFBooleanGetTypeID():
            return number.intValue
        default:
            return nil
        }
    }

    private static func object(_ text: String?) -> [String: Any] {
        guard let data = text?.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [:] }
        return object
    }

    private func legacyColumn(_ name: String) throws -> [String: Any] {
        Self.object(try database.rows("select \(name) from col").first?.first?.text)
    }

    private func legacyConfig() throws -> [String: Any] {
        try legacyColumn("conf")
    }

    private func modernConfig() throws -> [String: Any] {
        var config: [String: Any] = [:]
        for row in try database.rows("select key, val from config") {
            guard let key = row[0].text, let data = row[1].bytes,
                  let value = try? JSONSerialization.jsonObject(with: data, options: .fragmentsAllowed) else { continue }
            config[key] = value
        }
        return config
    }

    private func legacyNoteTypes() throws -> [Int64: NoteType] {
        var types: [Int64: NoteType] = [:]
        for (key, value) in try legacyColumn("models") {
            guard let id = Int64(key), let model = value as? [String: Any] else { continue }
            let fields = (model["flds"] as? [[String: Any]] ?? [])
                .sorted { Self.integer($0["ord"]) ?? 0 < Self.integer($1["ord"]) ?? 0 }
                .map { $0["name"] as? String ?? "" }
            types[id] = NoteType(name: model["name"] as? String ?? "", fieldNames: fields)
        }
        return types
    }

    private func modernNoteTypes() throws -> [Int64: NoteType] {
        var fieldNames: [Int64: [String]] = [:]
        for row in try database.rows("select ntid, name from fields order by ntid, ord") {
            guard let id = row[0].integer else { continue }
            fieldNames[id, default: []].append(row[1].text ?? "")
        }
        var types: [Int64: NoteType] = [:]
        for row in try database.rows("select id, name from notetypes") {
            guard let id = row[0].integer else { continue }
            types[id] = NoteType(name: row[1].text ?? "", fieldNames: fieldNames[id] ?? [])
        }
        return types
    }

    private func legacyDecks() throws -> [Int64: String] {
        var decks: [Int64: String] = [:]
        for (key, value) in try legacyColumn("decks") {
            guard let id = Int64(key), let deck = value as? [String: Any] else { continue }
            decks[id] = deck["name"] as? String ?? ""
        }
        return decks
    }

    private func modernDecks() throws -> [Int64: String] {
        var decks: [Int64: String] = [:]
        for row in try database.rows("select id, name from decks") {
            guard let id = row[0].integer else { continue }
            decks[id] = (row[1].text ?? "").replacingOccurrences(of: "\u{1F}", with: "::")
        }
        return decks
    }
}

enum AnkiDatabaseValue {
    case integer(Int64)
    case real(Double)
    case text(String)
    case blob(Data)
    case null

    var integer: Int64? {
        switch self {
        case .integer(let value): return value
        case .real(let value): return Int64(value)
        case .text(let value): return Int64(value)
        default: return nil
        }
    }

    var text: String? {
        switch self {
        case .text(let value): return value
        case .blob(let value): return String(data: value, encoding: .utf8)
        case .integer(let value): return String(value)
        default: return nil
        }
    }

    var bytes: Data? {
        switch self {
        case .blob(let value): return value
        case .text(let value): return Data(value.utf8)
        default: return nil
        }
    }
}

final class AnkiDatabase {
    private var handle: OpaquePointer?

    init(path: String) throws {
        guard sqlite3_open_v2(path, &handle, SQLITE_OPEN_READONLY, nil) == SQLITE_OK,
              sqlite3_create_collation_v2(handle, "unicase", SQLITE_UTF8, nil, Self.compareCaseInsensitive, nil) == SQLITE_OK
        else {
            sqlite3_close(handle)
            throw AnkiImportError.unreadable
        }
    }

    private static let compareCaseInsensitive: @convention(c) (
        UnsafeMutableRawPointer?, Int32, UnsafeRawPointer?, Int32, UnsafeRawPointer?
    ) -> Int32 = { _, leftCount, left, rightCount, right in
        let lhs = String(decoding: UnsafeRawBufferPointer(start: left, count: Int(leftCount)), as: UTF8.self).lowercased()
        let rhs = String(decoding: UnsafeRawBufferPointer(start: right, count: Int(rightCount)), as: UTF8.self).lowercased()
        return lhs == rhs ? 0 : (lhs < rhs ? -1 : 1)
    }

    deinit {
        sqlite3_close(handle)
    }

    func rows(_ sql: String) throws -> [[AnkiDatabaseValue]] {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(handle, sql, -1, &statement, nil) == SQLITE_OK else {
            sqlite3_finalize(statement)
            throw AnkiImportError.unreadable
        }
        defer { sqlite3_finalize(statement) }
        var rows: [[AnkiDatabaseValue]] = []
        while true {
            let step = sqlite3_step(statement)
            if step == SQLITE_DONE { break }
            guard step == SQLITE_ROW else { throw AnkiImportError.unreadable }
            rows.append((0..<sqlite3_column_count(statement)).map { value(statement, $0) })
        }
        return rows
    }

    private func value(_ statement: OpaquePointer?, _ column: Int32) -> AnkiDatabaseValue {
        switch sqlite3_column_type(statement, column) {
        case SQLITE_INTEGER:
            return .integer(sqlite3_column_int64(statement, column))
        case SQLITE_FLOAT:
            return .real(sqlite3_column_double(statement, column))
        case SQLITE_TEXT:
            guard let text = sqlite3_column_text(statement, column) else { return .null }
            let count = Int(sqlite3_column_bytes(statement, column))
            return .text(String(decoding: UnsafeBufferPointer(start: text, count: count), as: UTF8.self))
        case SQLITE_BLOB:
            let count = Int(sqlite3_column_bytes(statement, column))
            guard count > 0, let blob = sqlite3_column_blob(statement, column) else { return .blob(Data()) }
            return .blob(Data(bytes: blob, count: count))
        default:
            return .null
        }
    }
}

struct AnkiZipArchive {
    static let localHeaderSignature = Data([0x50, 0x4B, 0x03, 0x04])

    private struct Entry {
        let method: UInt16
        let flags: UInt16
        let compressedSize: Int
        let uncompressedSize: Int
        let localHeaderOffset: Int
    }

    private let data: Data
    private var entries: [String: Entry] = [:]

    init(_ data: Data) throws {
        self.data = data
        guard let end = Self.endOfCentralDirectory(in: data) else { throw AnkiImportError.unreadable }
        var count = Int(try Self.uint16(data, end + 10))
        var directorySize = Int(try Self.uint32(data, end + 12))
        var offset = Int(try Self.uint32(data, end + 16))
        if count == 0xFFFF || directorySize == 0xFFFF_FFFF || offset == 0xFFFF_FFFF,
           end >= 20, try Self.uint32(data, end - 20) == 0x0706_4B50 {
            let record = Int(try Self.uint64(data, end - 12))
            guard try Self.uint32(data, record) == 0x0606_4B50 else { throw AnkiImportError.unreadable }
            count = Int(try Self.uint64(data, record + 32))
            directorySize = Int(try Self.uint64(data, record + 40))
            offset = Int(try Self.uint64(data, record + 48))
        }
        guard offset + directorySize <= data.count else { throw AnkiImportError.unreadable }
        for _ in 0..<count {
            guard try Self.uint32(data, offset) == 0x0201_4B50 else { throw AnkiImportError.unreadable }
            let flags = try Self.uint16(data, offset + 8)
            let method = try Self.uint16(data, offset + 10)
            var compressedSize = Int(try Self.uint32(data, offset + 20))
            var uncompressedSize = Int(try Self.uint32(data, offset + 24))
            let nameLength = Int(try Self.uint16(data, offset + 28))
            let extraLength = Int(try Self.uint16(data, offset + 30))
            let commentLength = Int(try Self.uint16(data, offset + 32))
            var localHeaderOffset = Int(try Self.uint32(data, offset + 42))
            let name = String(decoding: try Self.slice(data, offset + 46, nameLength), as: UTF8.self)
            var extra = offset + 46 + nameLength
            let extraEnd = extra + extraLength
            while extra + 4 <= extraEnd {
                let id = try Self.uint16(data, extra)
                let size = Int(try Self.uint16(data, extra + 2))
                if id == 0x0001 {
                    var field = extra + 4
                    if uncompressedSize == 0xFFFF_FFFF { uncompressedSize = Int(try Self.uint64(data, field)); field += 8 }
                    if compressedSize == 0xFFFF_FFFF { compressedSize = Int(try Self.uint64(data, field)); field += 8 }
                    if localHeaderOffset == 0xFFFF_FFFF { localHeaderOffset = Int(try Self.uint64(data, field)) }
                }
                extra += 4 + size
            }
            entries[name] = Entry(method: method, flags: flags, compressedSize: compressedSize,
                                  uncompressedSize: uncompressedSize, localHeaderOffset: localHeaderOffset)
            offset = extraEnd + commentLength
        }
    }

    func contains(_ name: String) -> Bool {
        entries[name] != nil
    }

    func extract(_ name: String) throws -> Data {
        guard let entry = entries[name] else { throw AnkiImportError.unreadable }
        guard entry.flags & 1 == 0 else { throw AnkiImportError.unreadable }
        let header = entry.localHeaderOffset
        guard try Self.uint32(data, header) == 0x0403_4B50 else { throw AnkiImportError.unreadable }
        let start = header + 30 + Int(try Self.uint16(data, header + 26)) + Int(try Self.uint16(data, header + 28))
        let compressed = try Self.slice(data, start, entry.compressedSize)
        switch entry.method {
        case 0:
            return compressed
        case 8:
            return try Self.inflate(compressed, size: entry.uncompressedSize)
        default:
            throw AnkiImportError.unreadable
        }
    }

    private static func inflate(_ compressed: Data, size: Int) throws -> Data {
        guard size > 0 else { return Data() }
        var output = Data(count: size)
        let written = output.withUnsafeMutableBytes { destination in
            compressed.withUnsafeBytes { source in
                compression_decode_buffer(
                    destination.bindMemory(to: UInt8.self).baseAddress!, size,
                    source.bindMemory(to: UInt8.self).baseAddress!, compressed.count,
                    nil, COMPRESSION_ZLIB
                )
            }
        }
        guard written == size else { throw AnkiImportError.unreadable }
        return output
    }

    private static func endOfCentralDirectory(in data: Data) -> Int? {
        guard data.count >= 22 else { return nil }
        let lowest = max(0, data.count - 22 - 0xFFFF)
        var offset = data.count - 22
        while offset >= lowest {
            if (try? uint32(data, offset)) == 0x0605_4B50 { return offset }
            offset -= 1
        }
        return nil
    }

    private static func slice(_ data: Data, _ offset: Int, _ count: Int) throws -> Data {
        guard offset >= 0, count >= 0, offset + count <= data.count else { throw AnkiImportError.unreadable }
        let start = data.startIndex + offset
        return data.subdata(in: start..<(start + count))
    }

    private static func littleEndian(_ data: Data, _ offset: Int, _ width: Int) throws -> UInt64 {
        guard offset >= 0, offset + width <= data.count else { throw AnkiImportError.unreadable }
        var value: UInt64 = 0
        for index in (0..<width).reversed() {
            value = value << 8 | UInt64(data[data.startIndex + offset + index])
        }
        return value
    }

    private static func uint16(_ data: Data, _ offset: Int) throws -> UInt16 {
        UInt16(try littleEndian(data, offset, 2))
    }

    private static func uint32(_ data: Data, _ offset: Int) throws -> UInt32 {
        UInt32(try littleEndian(data, offset, 4))
    }

    private static func uint64(_ data: Data, _ offset: Int) throws -> UInt64 {
        try littleEndian(data, offset, 8)
    }
}

enum AnkiZstd {
    static func decompress(_ input: Data) throws -> Data {
        guard let stream = ZSTD_createDStream() else { throw AnkiImportError.unreadable }
        defer { ZSTD_freeDStream(stream) }
        guard ZSTD_isError(ZSTD_initDStream(stream)) == 0 else { throw AnkiImportError.unreadable }
        var output = Data()
        var chunk = [UInt8](repeating: 0, count: ZSTD_DStreamOutSize())
        try input.withUnsafeBytes { source in
            var inBuffer = ZSTD_inBuffer(src: source.baseAddress, size: source.count, pos: 0)
            var remaining = 1
            var filledChunk = false
            repeat {
                try chunk.withUnsafeMutableBytes { destination in
                    var outBuffer = ZSTD_outBuffer(dst: destination.baseAddress, size: destination.count, pos: 0)
                    remaining = ZSTD_decompressStream(stream, &outBuffer, &inBuffer)
                    guard ZSTD_isError(remaining) == 0 else { throw AnkiImportError.unreadable }
                    output.append(destination.bindMemory(to: UInt8.self).baseAddress!, count: outBuffer.pos)
                    filledChunk = outBuffer.pos == outBuffer.size
                }
            } while inBuffer.pos < inBuffer.size || filledChunk
            guard remaining == 0 else { throw AnkiImportError.unreadable }
        }
        return output
    }
}
