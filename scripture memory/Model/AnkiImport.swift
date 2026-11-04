import Foundation

struct AnkiImport: Equatable {
    let deckNames: [String]
    let notes: [AnkiNote]

    init(deckNames: [String], notes: [AnkiNote]) {
        self.deckNames = deckNames
        self.notes = notes
    }

    init(notes: [AnkiNote]) {
        var names: [String] = []
        for note in notes where !note.deck.isEmpty && !names.contains(note.deck) {
            names.append(note.deck)
        }
        self.init(deckNames: names, notes: notes)
    }
}

struct AnkiNote: Equatable {
    let deck: String
    let noteType: String
    let fieldNames: [String]
    let fields: [String]
    let tags: [String]
    let cards: [AnkiCardSchedule]
}

struct AnkiCardSchedule: Equatable {
    enum Kind: String, Equatable {
        case new, learning, review, relearning
    }

    let kind: Kind
    let isSuspended: Bool
    let intervalDays: Double
    let ease: Double
    let due: Date?
    let reps: Int
    let lapses: Int
    let lastReviewed: Date?
}

enum AnkiImportError: Error, Equatable {
    case unreadable
    case unsupported(String)
    case empty
}

struct AnkiCardRow: Equatable {
    let type: Int
    let queue: Int
    let due: Int64
    let interval: Int64
    let factor: Int64
    let reps: Int
    let lapses: Int
    let originalDue: Int64
    let originalDeckID: Int64
    let lastReviewMilliseconds: Int64?
}

struct AnkiCollectionTiming: Equatable {
    let creation: Int64
    let creationMinutesWest: Int?
    let currentMinutesWest: Int
    let rolloverHour: Int?

    init(creation: Int64, creationMinutesWest: Int?, currentMinutesWest: Int, rolloverHour: Int?) {
        self.creation = creation
        self.creationMinutesWest = creationMinutesWest
        self.currentMinutesWest = currentMinutesWest
        self.rolloverHour = rolloverHour
    }

    init(creation: Int64, schedulerVersion: Int?, rollover: Int?, creationOffset: Int?, deviceMinutesWest: Int) {
        let isV1 = (schedulerVersion ?? 1) < 2
        self.init(
            creation: creation,
            creationMinutesWest: isV1 ? nil : creationOffset,
            currentMinutesWest: deviceMinutesWest,
            rolloverHour: isV1 ? nil : min(max(rollover ?? 4, 0), 23)
        )
    }

    func dayStart(_ day: Int64) -> Date {
        Date(timeIntervalSince1970: TimeInterval(dayStartSeconds(day)))
    }

    private func dayStartSeconds(_ day: Int64) -> Int64 {
        guard let rolloverHour else { return creation + day * 86_400 }
        let rolloverSeconds = Int64(rolloverHour) * 3_600 + Int64(currentMinutesWest) * 60
        guard let creationMinutesWest else {
            return Self.localEpochDay(creation, minutesWest: currentMinutesWest) * 86_400 + rolloverSeconds + day * 86_400
        }
        return (Self.localEpochDay(creation, minutesWest: creationMinutesWest) + day) * 86_400 + rolloverSeconds
    }

    private static func localEpochDay(_ seconds: Int64, minutesWest: Int) -> Int64 {
        let local = seconds - Int64(minutesWest) * 60
        return local >= 0 ? local / 86_400 : (local - 86_399) / 86_400
    }
}

extension AnkiCardSchedule {
    private static let epochTimestampFloor: Int64 = 1_000_000_000

    init(row: AnkiCardRow, timing: AnkiCollectionTiming) {
        let kind: Kind
        switch row.type {
        case 1: kind = .learning
        case 2: kind = .review
        case 3: kind = .relearning
        default: kind = .new
        }
        let dueNumber = row.originalDeckID != 0 && row.originalDue != 0 ? row.originalDue : row.due
        let due: Date?
        if kind == .new {
            due = nil
        } else if row.queue == 2 || row.queue == 3 || row.type == 2 || dueNumber <= Self.epochTimestampFloor {
            due = timing.dayStart(dueNumber)
        } else {
            due = Date(timeIntervalSince1970: TimeInterval(dueNumber))
        }
        let intervalDays: Double
        if row.interval > 0 {
            intervalDays = Double(row.interval)
        } else if row.interval < 0 {
            intervalDays = Double(-row.interval) / 86_400
        } else {
            intervalDays = 0
        }
        self.init(
            kind: kind,
            isSuspended: row.queue == -1,
            intervalDays: intervalDays,
            ease: Double(row.factor) / 1_000,
            due: due,
            reps: row.reps,
            lapses: row.lapses,
            lastReviewed: row.lastReviewMilliseconds.map { Date(timeIntervalSince1970: TimeInterval($0) / 1_000) }
        )
    }
}

enum AnkiFieldCleaner {
    private typealias Scalars = [Unicode.Scalar]

    private static let lineBreakTags: Set<String> = ["br"]
    private static let blockTags: Set<String> = [
        "div", "p", "li", "ul", "ol", "tr", "table", "blockquote", "pre", "hr",
        "h1", "h2", "h3", "h4", "h5", "h6", "section", "article", "header", "footer",
    ]
    private static let entities: [String: String] = [
        "nbsp": "\u{00A0}", "amp": "&", "lt": "<", "gt": ">", "quot": "\"", "apos": "'",
        "ndash": "\u{2013}", "mdash": "\u{2014}", "hellip": "\u{2026}",
        "lsquo": "\u{2018}", "rsquo": "\u{2019}", "ldquo": "\u{201C}", "rdquo": "\u{201D}",
        "laquo": "\u{00AB}", "raquo": "\u{00BB}", "middot": "\u{00B7}", "bull": "\u{2022}",
        "copy": "\u{00A9}", "reg": "\u{00AE}", "deg": "\u{00B0}", "times": "\u{00D7}", "shy": "",
    ]

    static func clean(_ field: String, isHTML: Bool = true) -> String {
        var scalars = unwrapClozes(Array(field.unicodeScalars))
        scalars = removeSounds(scalars)
        if isHTML {
            scalars = decodeEntities(stripTags(scalars))
        }
        return normalizeWhitespace(scalars)
    }

    static func containsHTML(_ text: String) -> Bool {
        let scalars = Array(text.unicodeScalars)
        var index = 0
        while index < scalars.count {
            if scalars[index] == "<", tagEnd(scalars, from: index) != nil {
                return true
            }
            index += 1
        }
        return false
    }

    private static func matches(_ scalars: Scalars, _ index: Int, _ literal: String, ignoringCase: Bool = false) -> Bool {
        var position = index
        for expected in literal.unicodeScalars {
            guard position < scalars.count else { return false }
            let actual = scalars[position]
            if ignoringCase ? lowercased(actual) != lowercased(expected) : actual != expected {
                return false
            }
            position += 1
        }
        return true
    }

    private static func lowercased(_ scalar: Unicode.Scalar) -> Unicode.Scalar {
        ("A"..."Z").contains(scalar) ? Unicode.Scalar(scalar.value + 32)! : scalar
    }

    private static func isASCIILetter(_ scalar: Unicode.Scalar) -> Bool {
        ("a"..."z").contains(scalar) || ("A"..."Z").contains(scalar)
    }

    private static func isASCIIDigit(_ scalar: Unicode.Scalar) -> Bool {
        ("0"..."9").contains(scalar)
    }

    private static func find(_ literal: String, in scalars: Scalars, from start: Int, ignoringCase: Bool = false) -> Int? {
        var index = start
        while index < scalars.count {
            if matches(scalars, index, literal, ignoringCase: ignoringCase) { return index }
            index += 1
        }
        return nil
    }

    private static func clozeContentStart(_ scalars: Scalars, _ index: Int) -> Int? {
        guard matches(scalars, index, "{{c") else { return nil }
        var position = index + 3
        let digitsStart = position
        while position < scalars.count, isASCIIDigit(scalars[position]) { position += 1 }
        guard position > digitsStart, matches(scalars, position, "::") else { return nil }
        return position + 2
    }

    private static func unwrapClozes(_ scalars: Scalars) -> Scalars {
        var output: Scalars = []
        var index = 0
        while index < scalars.count {
            if let contentStart = clozeContentStart(scalars, index),
               let (contentEnd, answerEnd) = clozeBounds(scalars, from: contentStart) {
                output += unwrapClozes(Array(scalars[contentStart..<answerEnd]))
                index = contentEnd + 2
                continue
            }
            output.append(scalars[index])
            index += 1
        }
        return output
    }

    private static func clozeBounds(_ scalars: Scalars, from start: Int) -> (end: Int, answerEnd: Int)? {
        var depth = 1
        var answerEnd: Int?
        var index = start
        while index < scalars.count {
            if matches(scalars, index, "{{") {
                depth += 1
                index += 2
            } else if matches(scalars, index, "}}") {
                depth -= 1
                if depth == 0 { return (index, answerEnd ?? index) }
                index += 2
            } else if depth == 1, answerEnd == nil, matches(scalars, index, "::") {
                answerEnd = index
                index += 2
            } else {
                index += 1
            }
        }
        return nil
    }

    private static func removeSounds(_ scalars: Scalars) -> Scalars {
        var output: Scalars = []
        var index = 0
        while index < scalars.count {
            if matches(scalars, index, "[sound:"), let close = find("]", in: scalars, from: index + 7) {
                index = close + 1
                continue
            }
            output.append(scalars[index])
            index += 1
        }
        return output
    }

    private static func tagEnd(_ scalars: Scalars, from index: Int) -> Int? {
        guard index + 1 < scalars.count else { return nil }
        let next = scalars[index + 1]
        guard isASCIILetter(next) || next == "/" || next == "!" else { return nil }
        if matches(scalars, index, "<!--") {
            return find("-->", in: scalars, from: index + 4).map { $0 + 2 }
        }
        return find(">", in: scalars, from: index + 1)
    }

    private static func tagName(_ scalars: Scalars, from index: Int) -> String {
        var position = index + 1
        if position < scalars.count, scalars[position] == "/" { position += 1 }
        var name = ""
        while position < scalars.count, isASCIILetter(scalars[position]) || isASCIIDigit(scalars[position]) {
            name.unicodeScalars.append(lowercased(scalars[position]))
            position += 1
        }
        return name
    }

    private static func stripTags(_ scalars: Scalars) -> Scalars {
        var output: Scalars = []
        var index = 0
        while index < scalars.count {
            guard scalars[index] == "<", let end = tagEnd(scalars, from: index) else {
                output.append(scalars[index])
                index += 1
                continue
            }
            let isClosing = scalars[index + 1] == "/"
            let name = tagName(scalars, from: index)
            if !isClosing, name == "style" || name == "script",
               let close = find("</\(name)", in: scalars, from: end + 1, ignoringCase: true),
               let closeEnd = find(">", in: scalars, from: close) {
                index = closeEnd + 1
                continue
            }
            if lineBreakTags.contains(name) {
                output.append("\n")
            } else if blockTags.contains(name), let last = output.last, last != "\n" {
                output.append("\n")
            }
            index = end + 1
        }
        return output
    }

    private static func decodeEntities(_ scalars: Scalars) -> Scalars {
        var output: Scalars = []
        var index = 0
        while index < scalars.count {
            if scalars[index] == "&", let (decoded, end) = entity(scalars, at: index) {
                output += decoded
                index = end + 1
                continue
            }
            output.append(scalars[index])
            index += 1
        }
        return output
    }

    private static func entity(_ scalars: Scalars, at index: Int) -> (Scalars, Int)? {
        var end = index + 1
        while end < scalars.count, end - index <= 10, scalars[end] != ";" {
            guard isASCIILetter(scalars[end]) || isASCIIDigit(scalars[end]) || scalars[end] == "#" else { return nil }
            end += 1
        }
        guard end < scalars.count, scalars[end] == ";", end > index + 1 else { return nil }
        var name = ""
        name.unicodeScalars.append(contentsOf: scalars[(index + 1)..<end])
        if let named = entities[name] {
            return (Array(named.unicodeScalars), end)
        }
        guard name.hasPrefix("#") else { return nil }
        let digits = name.dropFirst()
        let value: UInt32?
        if digits.hasPrefix("x") || digits.hasPrefix("X") {
            value = UInt32(digits.dropFirst(), radix: 16)
        } else {
            value = UInt32(digits, radix: 10)
        }
        guard let value, value > 0, let scalar = Unicode.Scalar(value) else { return nil }
        return ([scalar], end)
    }

    private static func isHorizontalSpace(_ scalar: Unicode.Scalar) -> Bool {
        scalar == " " || scalar == "\t" || scalar == "\u{00A0}"
    }

    private static func normalizeWhitespace(_ scalars: Scalars) -> String {
        var lines: [String] = []
        var current = ""
        var pendingSpace = false
        var index = 0
        func finishLine() {
            lines.append(current)
            current = ""
            pendingSpace = false
        }
        while index < scalars.count {
            let scalar = scalars[index]
            if scalar == "\r" || scalar == "\n" {
                if scalar == "\r", index + 1 < scalars.count, scalars[index + 1] == "\n" { index += 1 }
                finishLine()
            } else if isHorizontalSpace(scalar) {
                pendingSpace = !current.isEmpty
            } else {
                if pendingSpace { current.unicodeScalars.append(" ") }
                pendingSpace = false
                current.unicodeScalars.append(scalar)
            }
            index += 1
        }
        finishLine()

        var kept: [String] = []
        for line in lines {
            if line.isEmpty, kept.last?.isEmpty ?? true { continue }
            kept.append(line)
        }
        while kept.last?.isEmpty == true { kept.removeLast() }
        return kept.joined(separator: "\n")
    }
}

enum AnkiTextExport {
    private typealias Scalars = [Unicode.Scalar]

    private struct Header {
        var delimiter: Unicode.Scalar?
        var isHTML: Bool?
        var deck = ""
        var noteType = ""
        var tags: [String] = []
        var columns: String?
        var guidColumn = 0
        var deckColumn = 0
        var noteTypeColumn = 0
        var tagsColumn = 0
    }

    private static let namedDelimiters: [String: Unicode.Scalar] = [
        "tab": "\t", "pipe": "|", "semicolon": ";", "colon": ":", "comma": ",", "space": " ",
    ]

    static func parse(_ text: String) throws -> AnkiImport {
        var scalars = Array(text.unicodeScalars)
        if scalars.first == "\u{FEFF}" { scalars.removeFirst() }
        var header = Header()
        var index = 0
        var isFirstLine = true
        while index < scalars.count {
            let lineEnd = scalars[index...].firstIndex(of: "\n") ?? scalars.count
            var line = String(String.UnicodeScalarView(scalars[index..<lineEnd]))
            if line.hasSuffix("\r") { line.removeLast() }
            if isFirstLine, line.hasPrefix("tags:") {
                header.tags = splitTags(String(line.dropFirst(5)))
            } else if line.hasPrefix("#") {
                applyHeaderLine(String(line.dropFirst()), to: &header)
            } else {
                break
            }
            isFirstLine = false
            index = min(lineEnd + 1, scalars.count)
        }
        let body = Array(scalars[index...])
        let delimiter = header.delimiter ?? sniffDelimiter(body)
        let records = parseRecords(body, delimiter: delimiter)
        let isHTML = header.isHTML ?? records.contains { $0.contains(where: AnkiFieldCleaner.containsHTML) }
        let labels = header.columns.map { parseRecords(Array($0.unicodeScalars), delimiter: delimiter).first ?? [] } ?? []
        let metaColumns: Set<Int> = Set([header.guidColumn, header.deckColumn, header.noteTypeColumn, header.tagsColumn].filter { $0 > 0 })

        var notes: [AnkiNote] = []
        for record in records {
            var fieldNames: [String] = []
            var fields: [String] = []
            for (offset, value) in record.enumerated() where !metaColumns.contains(offset + 1) {
                let label = offset < labels.count ? labels[offset].trimmingCharacters(in: .whitespaces) : ""
                fieldNames.append(label.isEmpty ? "Field \(fieldNames.count + 1)" : label)
                fields.append(AnkiFieldCleaner.clean(value, isHTML: isHTML))
            }
            while let last = fields.last, last.isEmpty {
                fields.removeLast()
                fieldNames.removeLast()
            }
            guard !fields.isEmpty else { continue }
            var tags = header.tags
            for tag in splitTags(column(header.tagsColumn, of: record)) where !tags.contains(tag) {
                tags.append(tag)
            }
            notes.append(AnkiNote(
                deck: header.deckColumn > 0 ? column(header.deckColumn, of: record).trimmingCharacters(in: .whitespaces) : header.deck,
                noteType: header.noteTypeColumn > 0 ? column(header.noteTypeColumn, of: record).trimmingCharacters(in: .whitespaces) : header.noteType,
                fieldNames: fieldNames,
                fields: fields,
                tags: tags,
                cards: []
            ))
        }
        guard !notes.isEmpty else { throw AnkiImportError.empty }
        return AnkiImport(notes: notes)
    }

    private static func column(_ number: Int, of record: [String]) -> String {
        number > 0 && number <= record.count ? record[number - 1] : ""
    }

    private static func splitTags(_ text: String) -> [String] {
        var tags: [String] = []
        for tag in text.split(whereSeparator: { $0.isWhitespace }).map(String.init) where !tags.contains(tag) {
            tags.append(tag)
        }
        return tags
    }

    private static func trimmedValue(_ value: String) -> String {
        let scalars = Array(value.unicodeScalars)
        guard scalars.count > 1 else { return value }
        var end = 1
        while end < scalars.count, ("a"..."z").contains(scalars[end]) || ("A"..."Z").contains(scalars[end]) || ("0"..."9").contains(scalars[end]) {
            end += 1
        }
        return String(String.UnicodeScalarView(scalars[0..<end]))
    }

    private static func applyHeaderLine(_ line: String, to header: inout Header) {
        guard let colon = line.firstIndex(of: ":") else { return }
        let key = line[..<colon].trimmingCharacters(in: .whitespaces).lowercased()
        let value = String(line[line.index(after: colon)...])
        let trimmed = trimmedValue(value)
        switch key {
        case "separator":
            if let named = namedDelimiters[trimmed.trimmingCharacters(in: .whitespaces).lowercased()] {
                header.delimiter = named
            } else if value.unicodeScalars.count == 1 {
                header.delimiter = value.unicodeScalars.first
            }
        case "html":
            switch trimmed.lowercased() {
            case "true": header.isHTML = true
            case "false": header.isHTML = false
            default: break
            }
        case "tags": header.tags = splitTags(value)
        case "columns": header.columns = value
        case "deck": header.deck = value.trimmingCharacters(in: .whitespaces)
        case "notetype": header.noteType = value.trimmingCharacters(in: .whitespaces)
        case "guid column": header.guidColumn = Int(trimmed.trimmingCharacters(in: .whitespaces)) ?? header.guidColumn
        case "deck column": header.deckColumn = Int(trimmed.trimmingCharacters(in: .whitespaces)) ?? header.deckColumn
        case "notetype column": header.noteTypeColumn = Int(trimmed.trimmingCharacters(in: .whitespaces)) ?? header.noteTypeColumn
        case "tags column": header.tagsColumn = Int(trimmed.trimmingCharacters(in: .whitespaces)) ?? header.tagsColumn
        default: break
        }
    }

    private static func sniffDelimiter(_ body: Scalars) -> Unicode.Scalar {
        var lines: [[Unicode.Scalar: Int]] = []
        var counts: [Unicode.Scalar: Int] = [:]
        var lineHasContent = false
        var inQuotes = false
        for scalar in body {
            if lines.count == 20 { break }
            if scalar == "\"" {
                inQuotes.toggle()
            } else if !inQuotes, scalar == "\n" || scalar == "\r" {
                if lineHasContent { lines.append(counts) }
                counts = [:]
                lineHasContent = false
                continue
            } else if !inQuotes, scalar == "\t" || scalar == "," || scalar == ";" {
                counts[scalar, default: 0] += 1
            }
            lineHasContent = true
        }
        if lineHasContent, lines.count < 20 { lines.append(counts) }

        if lines.contains(where: { ($0["\t"] ?? 0) > 0 }) { return "\t" }
        let candidates: [Unicode.Scalar] = [",", ";"]
        func isConsistent(_ delimiter: Unicode.Scalar) -> Bool {
            guard let first = lines.first?[delimiter], first > 0 else { return false }
            return lines.allSatisfy { $0[delimiter] == first }
        }
        func total(_ delimiter: Unicode.Scalar) -> Int {
            lines.reduce(0) { $0 + ($1[delimiter] ?? 0) }
        }
        let consistent = candidates.filter(isConsistent)
        let pool = consistent.isEmpty ? candidates : consistent
        let score: (Unicode.Scalar) -> Int = consistent.isEmpty ? total : { lines.first?[$0] ?? 0 }
        var best: Unicode.Scalar = "\t"
        var bestScore = 0
        for candidate in pool where score(candidate) > bestScore {
            best = candidate
            bestScore = score(candidate)
        }
        return best
    }

    private static func parseRecords(_ scalars: Scalars, delimiter: Unicode.Scalar) -> [[String]] {
        var records: [[String]] = []
        var record: [String] = []
        var field = String.UnicodeScalarView()
        var inQuotes = false
        var wasQuoted = false
        var index = 0
        func finishField() {
            record.append(String(field))
            field = String.UnicodeScalarView()
            wasQuoted = false
        }
        func finishRecord() {
            finishField()
            if !(record.count == 1 && record[0].isEmpty) { records.append(record) }
            record = []
        }
        while index < scalars.count {
            let scalar = scalars[index]
            if inQuotes {
                if scalar == "\"" {
                    if index + 1 < scalars.count, scalars[index + 1] == "\"" {
                        field.append("\"")
                        index += 1
                    } else {
                        inQuotes = false
                    }
                } else {
                    field.append(scalar)
                }
            } else if scalar == "\"", field.isEmpty, !wasQuoted {
                inQuotes = true
                wasQuoted = true
            } else if scalar == delimiter {
                finishField()
            } else if scalar == "\n" || scalar == "\r" {
                if scalar == "\r", index + 1 < scalars.count, scalars[index + 1] == "\n" { index += 1 }
                finishRecord()
            } else {
                field.append(scalar)
            }
            index += 1
        }
        if !field.isEmpty || !record.isEmpty || wasQuoted { finishRecord() }
        return records
    }
}
