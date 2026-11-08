import Foundation

struct PastedVerse: Equatable {
    var reference: BibleReference?
    var version: String?
    var text: String

    static let knownVersions: [String: String] = [
        "new international version": "NIV",
        "english standard version": "ESV",
        "new king james version": "NKJV",
        "king james version": "KJV",
        "new living translation": "NLT",
        "new american standard bible": "NASB",
        "christian standard bible": "CSB",
        "berean standard bible": "BSB",
        "new revised standard version": "NRSV",
        "the message": "MSG",
        "amplified bible": "AMP",
        "new english translation": "NET",
        "world english bible": "WEB",
    ]

    private static let invisible = CharacterSet(charactersIn:
        "\u{200B}\u{200E}\u{200F}\u{202A}\u{202B}\u{202C}\u{202D}\u{202E}\u{2060}\u{2066}\u{2067}\u{2068}\u{2069}\u{FEFF}")

    static func share(in raw: String) -> PastedVerse? {
        let pasted = parse(raw)
        guard pasted.reference != nil, !pasted.text.isEmpty,
              pasted.text != raw.trimmingCharacters(in: .whitespacesAndNewlines) else { return nil }
        return pasted
    }

    static func parse(_ raw: String) -> PastedVerse {
        let visible = String(String.UnicodeScalarView(raw.unicodeScalars.filter { !invisible.contains($0) }))
        let lines = visible
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !isLink($0) }

        var reference: BibleReference?
        var version: String?
        var body: [String] = []

        for line in lines {
            if reference == nil, let found = referenceLine(line) {
                reference = found.reference
                version = found.version
                continue
            }
            body.append(line)
        }

        if reference == nil, let found = inlineReference(in: body.joined(separator: " ")) {
            reference = found.reference
            version = found.version
            body = [found.remainder]
        }

        let text = cleaned(body.joined(separator: " "), reference: reference)
        return PastedVerse(reference: reference, version: version, text: text)
    }

    private static func isLink(_ line: String) -> Bool {
        let lower = line.lowercased()
        return lower.hasPrefix("http://") || lower.hasPrefix("https://") || lower.hasPrefix("www.")
    }

    private static func referenceLine(_ line: String) -> (reference: BibleReference, version: String?)? {
        guard let found = BibleReference.find(in: line) else { return nil }
        let before = line[..<found.range.lowerBound].trimmingCharacters(in: .whitespaces.union(.punctuationCharacters))
        guard before.isEmpty else { return nil }
        let after = String(line[found.range.upperBound...])
        guard let version = versionTag(after) else { return nil }
        return (found.reference, version.isEmpty ? nil : version)
    }

    private static func inlineReference(in text: String) -> (reference: BibleReference, version: String?, remainder: String)? {
        guard let found = BibleReference.find(in: text) else { return nil }
        let before = text[..<found.range.lowerBound].trimmingCharacters(in: .whitespaces)
        let after = String(text[found.range.upperBound...])
        let isTrailing = versionTag(after) != nil
        let isLeading = before.isEmpty
        guard isTrailing || isLeading else { return nil }
        if isTrailing && !before.isEmpty {
            let tag = versionTag(after)
            return (found.reference, tag?.isEmpty == false ? tag : nil, String(before))
        }
        let (tag, rest) = leadingVersion(after)
        return (found.reference, tag, rest)
    }

    static func versionCode(_ text: String) -> String? {
        guard let tag = versionTag(text), !tag.isEmpty else { return nil }
        return tag
    }

    private static func versionTag(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespaces.union(CharacterSet(charactersIn: "-–—,·|")))
        guard !trimmed.isEmpty else { return "" }
        let bare = trimmed.trimmingCharacters(in: CharacterSet(charactersIn: "()[]").union(.whitespaces))
        if isAbbreviation(bare) { return bare.uppercased() }
        let lower = bare.lowercased()
        for (name, code) in knownVersions where lower.hasPrefix(name) {
            let tail = lower.dropFirst(name.count).trimmingCharacters(in: .whitespaces)
            if tail.isEmpty || tail.trimmingCharacters(in: CharacterSet(charactersIn: "()[]")).uppercased() == code
                || tail.allSatisfy({ $0.isNumber || $0 == "(" || $0 == ")" || $0 == " " }) {
                return code
            }
        }
        if let open = bare.lastIndex(of: "("), bare.hasSuffix(")") {
            let inner = String(bare[bare.index(after: open)..<bare.index(before: bare.endIndex)])
            if isAbbreviation(inner) { return inner.uppercased() }
        }
        return nil
    }

    private static func leadingVersion(_ text: String) -> (String?, String) {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        let first = trimmed.prefix { !$0.isWhitespace }
        let bare = first.trimmingCharacters(in: CharacterSet(charactersIn: "()[],:"))
        if isAbbreviation(bare), bare == bare.uppercased() {
            return (bare, trimmed.dropFirst(first.count).trimmingCharacters(in: .whitespaces))
        }
        return (nil, trimmed.trimmingCharacters(in: CharacterSet(charactersIn: ":-–— ")))
    }

    private static func isAbbreviation(_ text: String) -> Bool {
        (2...6).contains(text.count)
            && text.first?.isLetter == true
            && text.allSatisfy { $0.isLetter || $0.isNumber }
            && text.filter(\.isLetter) == text.filter(\.isLetter).uppercased()
    }

    static func cleaned(_ text: String, reference: BibleReference?) -> String {
        var t = text
            .replacingOccurrences(of: "\u{2018}", with: "'")
            .replacingOccurrences(of: "\u{2019}", with: "'")
            .replacingOccurrences(of: "\u{201C}", with: "\"")
            .replacingOccurrences(of: "\u{201D}", with: "\"")
            .replacingOccurrences(of: "\u{00A0}", with: " ")
        t = t.replacingOccurrences(of: "\\[(?:[a-zA-Z]{1,2}|\\d{1,3})\\]", with: "", options: .regularExpression)
        t = t.replacingOccurrences(of: "\\([A-Z]{1,2}\\)", with: "", options: .regularExpression)
        let numbers = verseNumbers(reference)
        if !numbers.isEmpty {
            let alternation = numbers.map(String.init).joined(separator: "|")
            t = t.replacingOccurrences(of: "(^|(?<=[\\s.,;:!?\"'\\)]))(\(alternation))(?=\\s?[A-Za-z\"'(])\\s?",
                                       with: "", options: .regularExpression)
        }
        t = t.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
        if t.count >= 2, t.first == "\"", t.last == "\"", t.dropFirst().dropLast().contains("\"") == false {
            t = String(t.dropFirst().dropLast())
        } else if t.filter({ $0 == "\"" }).count == 1, t.first == "\"" || t.last == "\"" {
            t = t.replacingOccurrences(of: "\"", with: "").trimmingCharacters(in: .whitespaces)
        }
        return t
    }

    private static func verseNumbers(_ reference: BibleReference?) -> [Int] {
        guard let reference, !reference.verses.isEmpty else { return [] }
        var numbers: [Int] = []
        for part in reference.verses.split(separator: ",") {
            let bounds = part.split(separator: "-").map { $0.split(separator: ":").last.map(String.init) ?? "" }
            guard let start = Int(bounds[0]) else { continue }
            let end = bounds.count > 1 ? (Int(bounds[1]) ?? start) : start
            if part.contains(":") || end < start {
                numbers.append(contentsOf: [start, end])
            } else {
                numbers.append(contentsOf: start...min(end, start + 60))
            }
        }
        return numbers.sorted(by: >)
    }
}
