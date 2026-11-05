import Foundation

struct BibleBook: Equatable {
    let name: String
    let usfm: String
    let chapters: Int
    let aliases: [String]
}

enum BibleBooks {

    static let all: [BibleBook] = [
        BibleBook(name: "Genesis", usfm: "GEN", chapters: 50, aliases: ["Gen", "Ge", "Gn"]),
        BibleBook(name: "Exodus", usfm: "EXO", chapters: 40, aliases: ["Exod", "Exo", "Ex"]),
        BibleBook(name: "Leviticus", usfm: "LEV", chapters: 27, aliases: ["Lev", "Lv"]),
        BibleBook(name: "Numbers", usfm: "NUM", chapters: 36, aliases: ["Num", "Nm", "Nb"]),
        BibleBook(name: "Deuteronomy", usfm: "DEU", chapters: 34, aliases: ["Deut", "Deu", "Dt"]),
        BibleBook(name: "Joshua", usfm: "JOS", chapters: 24, aliases: ["Josh", "Jos", "Jsh"]),
        BibleBook(name: "Judges", usfm: "JDG", chapters: 21, aliases: ["Judg", "Jdg", "Jg"]),
        BibleBook(name: "Ruth", usfm: "RUT", chapters: 4, aliases: ["Rth", "Ru"]),
        BibleBook(name: "1 Samuel", usfm: "1SA", chapters: 31, aliases: ["1 Sam", "1 Sa", "1 Sm"]),
        BibleBook(name: "2 Samuel", usfm: "2SA", chapters: 24, aliases: ["2 Sam", "2 Sa", "2 Sm"]),
        BibleBook(name: "1 Kings", usfm: "1KI", chapters: 22, aliases: ["1 Kgs", "1 Ki", "1 Kin"]),
        BibleBook(name: "2 Kings", usfm: "2KI", chapters: 25, aliases: ["2 Kgs", "2 Ki", "2 Kin"]),
        BibleBook(name: "1 Chronicles", usfm: "1CH", chapters: 29, aliases: ["1 Chr", "1 Chron", "1 Ch"]),
        BibleBook(name: "2 Chronicles", usfm: "2CH", chapters: 36, aliases: ["2 Chr", "2 Chron", "2 Ch"]),
        BibleBook(name: "Ezra", usfm: "EZR", chapters: 10, aliases: ["Ezr"]),
        BibleBook(name: "Nehemiah", usfm: "NEH", chapters: 13, aliases: ["Neh", "Ne"]),
        BibleBook(name: "Esther", usfm: "EST", chapters: 10, aliases: ["Est", "Esth"]),
        BibleBook(name: "Job", usfm: "JOB", chapters: 42, aliases: ["Jb"]),
        BibleBook(name: "Psalm", usfm: "PSA", chapters: 150, aliases: ["Psalms", "Pslm", "Psa", "Ps", "Pss"]),
        BibleBook(name: "Proverbs", usfm: "PRO", chapters: 31, aliases: ["Prov", "Prv", "Pro", "Pr"]),
        BibleBook(name: "Ecclesiastes", usfm: "ECC", chapters: 12, aliases: ["Eccles", "Eccl", "Ecc", "Qoh"]),
        BibleBook(name: "Song of Songs", usfm: "SNG", chapters: 8, aliases: ["Song of Solomon", "Song", "SOS", "Canticles"]),
        BibleBook(name: "Isaiah", usfm: "ISA", chapters: 66, aliases: ["Isa", "Is"]),
        BibleBook(name: "Jeremiah", usfm: "JER", chapters: 52, aliases: ["Jer", "Je"]),
        BibleBook(name: "Lamentations", usfm: "LAM", chapters: 5, aliases: ["Lam", "La"]),
        BibleBook(name: "Ezekiel", usfm: "EZK", chapters: 48, aliases: ["Ezek", "Eze", "Ezk"]),
        BibleBook(name: "Daniel", usfm: "DAN", chapters: 12, aliases: ["Dan", "Dn"]),
        BibleBook(name: "Hosea", usfm: "HOS", chapters: 14, aliases: ["Hos", "Ho"]),
        BibleBook(name: "Joel", usfm: "JOL", chapters: 3, aliases: ["Joe", "Jl"]),
        BibleBook(name: "Amos", usfm: "AMO", chapters: 9, aliases: ["Am"]),
        BibleBook(name: "Obadiah", usfm: "OBA", chapters: 1, aliases: ["Obad", "Oba", "Ob"]),
        BibleBook(name: "Jonah", usfm: "JON", chapters: 4, aliases: ["Jon", "Jnh"]),
        BibleBook(name: "Micah", usfm: "MIC", chapters: 7, aliases: ["Mic", "Mc"]),
        BibleBook(name: "Nahum", usfm: "NAM", chapters: 3, aliases: ["Nah", "Na"]),
        BibleBook(name: "Habakkuk", usfm: "HAB", chapters: 3, aliases: ["Hab", "Hb"]),
        BibleBook(name: "Zephaniah", usfm: "ZEP", chapters: 3, aliases: ["Zeph", "Zep", "Zp"]),
        BibleBook(name: "Haggai", usfm: "HAG", chapters: 2, aliases: ["Hag", "Hg"]),
        BibleBook(name: "Zechariah", usfm: "ZEC", chapters: 14, aliases: ["Zech", "Zec", "Zc"]),
        BibleBook(name: "Malachi", usfm: "MAL", chapters: 4, aliases: ["Mal", "Ml"]),
        BibleBook(name: "Matthew", usfm: "MAT", chapters: 28, aliases: ["Matt", "Mat", "Mt"]),
        BibleBook(name: "Mark", usfm: "MRK", chapters: 16, aliases: ["Mrk", "Mar", "Mk"]),
        BibleBook(name: "Luke", usfm: "LUK", chapters: 24, aliases: ["Luk", "Lk"]),
        BibleBook(name: "John", usfm: "JHN", chapters: 21, aliases: ["Jhn", "Jn"]),
        BibleBook(name: "Acts", usfm: "ACT", chapters: 28, aliases: ["Act", "Ac"]),
        BibleBook(name: "Romans", usfm: "ROM", chapters: 16, aliases: ["Rom", "Ro", "Rm"]),
        BibleBook(name: "1 Corinthians", usfm: "1CO", chapters: 16, aliases: ["1 Cor", "1 Co"]),
        BibleBook(name: "2 Corinthians", usfm: "2CO", chapters: 13, aliases: ["2 Cor", "2 Co"]),
        BibleBook(name: "Galatians", usfm: "GAL", chapters: 6, aliases: ["Gal", "Ga"]),
        BibleBook(name: "Ephesians", usfm: "EPH", chapters: 6, aliases: ["Eph", "Ephes"]),
        BibleBook(name: "Philippians", usfm: "PHP", chapters: 4, aliases: ["Phil", "Php", "Pp"]),
        BibleBook(name: "Colossians", usfm: "COL", chapters: 4, aliases: ["Col"]),
        BibleBook(name: "1 Thessalonians", usfm: "1TH", chapters: 5, aliases: ["1 Thess", "1 Thes", "1 Th"]),
        BibleBook(name: "2 Thessalonians", usfm: "2TH", chapters: 3, aliases: ["2 Thess", "2 Thes", "2 Th"]),
        BibleBook(name: "1 Timothy", usfm: "1TI", chapters: 6, aliases: ["1 Tim", "1 Ti"]),
        BibleBook(name: "2 Timothy", usfm: "2TI", chapters: 4, aliases: ["2 Tim", "2 Ti"]),
        BibleBook(name: "Titus", usfm: "TIT", chapters: 3, aliases: ["Tit"]),
        BibleBook(name: "Philemon", usfm: "PHM", chapters: 1, aliases: ["Philem", "Phlm", "Phm"]),
        BibleBook(name: "Hebrews", usfm: "HEB", chapters: 13, aliases: ["Heb"]),
        BibleBook(name: "James", usfm: "JAS", chapters: 5, aliases: ["Jas", "Jm"]),
        BibleBook(name: "1 Peter", usfm: "1PE", chapters: 5, aliases: ["1 Pet", "1 Pe", "1 Pt"]),
        BibleBook(name: "2 Peter", usfm: "2PE", chapters: 3, aliases: ["2 Pet", "2 Pe", "2 Pt"]),
        BibleBook(name: "1 John", usfm: "1JN", chapters: 5, aliases: ["1 Jhn", "1 Jn"]),
        BibleBook(name: "2 John", usfm: "2JN", chapters: 1, aliases: ["2 Jhn", "2 Jn"]),
        BibleBook(name: "3 John", usfm: "3JN", chapters: 1, aliases: ["3 Jhn", "3 Jn"]),
        BibleBook(name: "Jude", usfm: "JUD", chapters: 1, aliases: ["Jud", "Jd"]),
        BibleBook(name: "Revelation", usfm: "REV", chapters: 22, aliases: ["Rev", "Re", "Revelations", "Apocalypse"]),
    ]

    private static let romanNumerals = ["1": "I", "2": "II", "3": "III"]
    private static let ordinalWords = ["1": "First", "2": "Second", "3": "Third"]

    static func key(_ text: String) -> String {
        String(text.lowercased().unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) })
    }

    private static let byKey: [String: BibleBook] = {
        var map: [String: BibleBook] = [:]
        for book in all {
            for surface in [book.name] + book.aliases {
                map[key(surface)] = map[key(surface)] ?? book
                if let digit = surface.first.map(String.init), let roman = romanNumerals[digit] {
                    let rest = surface.dropFirst().trimmingCharacters(in: .whitespaces)
                    map[key(roman + rest)] = map[key(roman + rest)] ?? book
                    if let word = ordinalWords[digit] {
                        map[key(word + rest)] = map[key(word + rest)] ?? book
                    }
                }
            }
        }
        return map
    }()

    static func book(named text: String) -> BibleBook? {
        let k = key(text)
        guard !k.isEmpty else { return nil }
        return byKey[k]
    }

    static func book(usfm: String) -> BibleBook? {
        all.first { $0.usfm == usfm.uppercased() }
    }

    static func matching(prefix text: String, limit: Int = 4) -> [BibleBook] {
        let k = key(text)
        guard !k.isEmpty else { return [] }
        var result: [BibleBook] = []
        for book in all where !result.contains(book) {
            let surfaces = [book.name] + book.aliases
            if surfaces.contains(where: { key($0).hasPrefix(k) }) { result.append(book) }
            if result.count == limit { break }
        }
        return result
    }
}

struct BibleReference: Equatable {
    let book: BibleBook
    let chapter: Int
    let verses: String

    var reference: String { verses.isEmpty ? "\(chapter)" : "\(chapter):\(verses)" }

    var display: String { "\(book.name) \(reference)" }

    var usfm: String {
        let prefix = "\(book.usfm).\(chapter)"
        guard !verses.isEmpty else { return prefix }
        return verses.split(separator: ",").map { part -> String in
            let bounds = part.split(separator: "-")
            guard bounds.count == 2 else { return "\(prefix).\(part)" }
            if bounds[1].contains(":") {
                let end = bounds[1].split(separator: ":")
                return "\(prefix).\(bounds[0])-\(book.usfm).\(end[0]).\(end[1])"
            }
            return "\(prefix).\(bounds[0])-\(prefix).\(bounds[1])"
        }.joined(separator: "+")
    }

    static func parse(_ text: String) -> BibleReference? {
        let trimmed = normalized(text).trimmingCharacters(in: .whitespacesAndNewlines)
        guard let match = firstMatch(in: trimmed, anchored: true) else { return nil }
        return match.range.upperBound == trimmed.endIndex ? match.reference : nil
    }

    static func find(in text: String) -> (reference: BibleReference, range: Range<String.Index>)? {
        let source = normalized(text)
        guard let m = firstMatch(in: source, anchored: false) else { return nil }
        let lower = text.index(text.startIndex, offsetBy: source.distance(from: source.startIndex, to: m.range.lowerBound))
        let upper = text.index(lower, offsetBy: source.distance(from: m.range.lowerBound, to: m.range.upperBound))
        return (m.reference, lower..<upper)
    }

    private static func normalized(_ text: String) -> String {
        text.replacingOccurrences(of: "\u{2013}", with: "-")
            .replacingOccurrences(of: "\u{2014}", with: "-")
            .replacingOccurrences(of: "\u{00A0}", with: " ")
    }

    private static let pattern: NSRegularExpression = {
        let surfaces = BibleBooks.all
            .flatMap { [$0.name] + $0.aliases }
            .flatMap { surface -> [String] in
                guard let digit = surface.first, digit.isNumber else { return [surface] }
                let rest = surface.dropFirst().trimmingCharacters(in: .whitespaces)
                let roman = ["1": "I", "2": "II", "3": "III"][String(digit)] ?? ""
                let word = ["1": "First", "2": "Second", "3": "Third"][String(digit)] ?? ""
                return [surface, "\(roman) \(rest)", "\(word) \(rest)"]
            }
            .sorted { $0.count > $1.count }
            .map { NSRegularExpression.escapedPattern(for: $0).replacingOccurrences(of: " ", with: "\\s*") }
            .joined(separator: "|")
        let verse = "\\d{1,3}[a-c]?"
        let range = "\(verse)(?:\\s*-\\s*(?:\\d{1,3}\\s*:\\s*)?\(verse))?"
        let list = "\(range)(?:\\s*,\\s*\(range))*"
        let full = "\\b(\(surfaces))\\.?\\s*(\\d{1,3})(?:(?:\\s*[:.]\\s*|\\s+)(\(list)))?(?![\\d:])"
        return try! NSRegularExpression(pattern: full, options: [.caseInsensitive])
    }()

    private static func firstMatch(in text: String, anchored: Bool) -> (reference: BibleReference, range: Range<String.Index>)? {
        let ns = text as NSString
        let options: NSRegularExpression.MatchingOptions = anchored ? [.anchored] : []
        for match in pattern.matches(in: text, options: options, range: NSRange(location: 0, length: ns.length)) {
            guard let book = BibleBooks.book(named: ns.substring(with: match.range(at: 1))),
                  let chapter = Int(ns.substring(with: match.range(at: 2))),
                  chapter >= 1,
                  let range = Range(match.range, in: text) else { continue }
            var verses = ""
            if match.range(at: 3).location != NSNotFound {
                verses = ns.substring(with: match.range(at: 3))
                    .filter { !$0.isWhitespace }
                    .replacingOccurrences(of: "[a-cA-C]", with: "", options: .regularExpression)
            }
            if book.chapters == 1, verses.isEmpty, chapter > 1 {
                return (BibleReference(book: book, chapter: 1, verses: "\(chapter)"), range)
            }
            guard chapter <= book.chapters else { continue }
            return (BibleReference(book: book, chapter: chapter, verses: verses), range)
        }
        return nil
    }
}
