import Foundation

struct AnkiVerseCandidate: Equatable {
    var deck: String
    var reference: BibleReference
    var text: String
    var title: String
    var version: String?
    var schedule: AnkiCardSchedule?

    var hasProgress: Bool { schedule.map { $0.kind != .new } ?? false }
}

struct AnkiImportPlan: Equatable {
    struct Deck: Equatable {
        var name: String
        var verses: [AnkiVerseCandidate]
    }

    struct Match: Equatable {
        var cardUid: String
        var candidate: AnkiVerseCandidate
    }

    var decks: [Deck]
    var matches: [Match]
    var skipped: [String]
}

enum AnkiFieldRole: Equatable {
    case reference, text, title
}

enum AnkiVerseImport {

    static func plan(_ source: AnkiImport, bundledKeys: [String: String] = [:],
                     fallbackName: String = "OYO") -> AnkiImportPlan {
        var roles: [String: [AnkiFieldRole?]] = [:]
        for type in Set(source.notes.map(\.noteType)) {
            roles[type] = guessRoles(source.notes.filter { $0.noteType == type })
        }

        var decks: [AnkiImportPlan.Deck] = []
        var matches: [AnkiImportPlan.Match] = []
        var skipped: [String] = []
        var seen = Set<String>()

        for note in source.notes {
            guard var candidate = candidate(from: note, roles: roles[note.noteType] ?? []) else {
                skipped.append(note.fields.first(where: { !$0.isEmpty }) ?? "")
                continue
            }
            candidate.schedule = bestSchedule(note.cards)
            let key = referenceKey(book: candidate.reference.book.name, reference: candidate.reference.reference)
            if let uid = bundledKeys[key] {
                if !matches.contains(where: { $0.cardUid == uid }) {
                    matches.append(.init(cardUid: uid, candidate: candidate))
                }
                continue
            }
            guard seen.insert(note.deck + "|" + key).inserted else { continue }
            let name = deckDisplayName(note.deck, fallback: fallbackName)
            if let i = decks.firstIndex(where: { $0.name == name }) {
                decks[i].verses.append(candidate)
            } else {
                decks.append(.init(name: name, verses: [candidate]))
            }
        }
        return AnkiImportPlan(decks: decks, matches: matches, skipped: skipped)
    }

    static func referenceKey(book: String, reference: String) -> String {
        (BibleBooks.book(named: book)?.usfm ?? book.lowercased()) + "|" + SRSKey.normalizedReference(reference)
    }

    static func deckDisplayName(_ deck: String, fallback: String = "OYO") -> String {
        let leaf = deck.components(separatedBy: "::").last?.trimmingCharacters(in: .whitespaces) ?? ""
        return leaf.isEmpty || leaf == "Default" ? fallback : leaf
    }

    // MARK: - Fields

    private static let referenceNames = ["reference", "ref", "address", "verse reference", "passage"]
    private static let textNames = ["text", "verse", "verse text", "scripture", "back", "answer"]
    private static let titleNames = ["topic", "title", "theme", "heading", "subject", "category"]

    static func guessRoles(_ notes: [AnkiNote]) -> [AnkiFieldRole?] {
        let count = notes.map(\.fields.count).max() ?? 0
        guard count > 0, !notes.isEmpty else { return [] }
        let names = notes.first?.fieldNames.map { $0.lowercased().trimmingCharacters(in: .whitespaces) } ?? []
        func values(_ i: Int) -> [String] { notes.map { i < $0.fields.count ? $0.fields[i] : "" } }
        func share(_ i: Int, _ test: (String) -> Bool) -> Double {
            let filled = values(i).filter { !$0.isEmpty }
            return filled.isEmpty ? 0 : Double(filled.filter(test).count) / Double(filled.count)
        }
        func averageLength(_ i: Int) -> Double {
            let filled = values(i).filter { !$0.isEmpty }
            return filled.isEmpty ? 0 : Double(filled.map(\.count).reduce(0, +)) / Double(filled.count)
        }

        var roles = [AnkiFieldRole?](repeating: nil, count: count)
        let referenceScores = (0..<count).map { share($0) { BibleReference.parse($0) != nil } }
        if let best = referenceScores.indices.max(by: { referenceScores[$0] < referenceScores[$1] }),
           referenceScores[best] >= 0.6 {
            roles[best] = .reference
        } else if let named = names.firstIndex(where: referenceNames.contains), named < count {
            roles[named] = .reference
        }

        let open = (0..<count).filter { roles[$0] == nil }
        let textIndex = open.first { i in i < names.count && textNames.contains(names[i]) && averageLength(i) > 20 }
            ?? open.max { averageLength($0) < averageLength($1) }
        if let textIndex, averageLength(textIndex) > 0 { roles[textIndex] = .text }

        let rest = (0..<count).filter { roles[$0] == nil && averageLength($0) > 0 }
        let titleIndex = rest.first { i in i < names.count && titleNames.contains(names[i]) }
            ?? rest.first { averageLength($0) <= 60 && share($0) { BibleReference.parse($0) == nil } >= 0.8 }
        if let titleIndex { roles[titleIndex] = .title }
        return roles
    }

    static func candidate(from note: AnkiNote, roles: [AnkiFieldRole?]) -> AnkiVerseCandidate? {
        func field(_ role: AnkiFieldRole) -> String? {
            guard let i = roles.firstIndex(of: role), i < note.fields.count else { return nil }
            let value = note.fields[i].trimmingCharacters(in: .whitespacesAndNewlines)
            return value.isEmpty ? nil : value
        }
        let title = field(.title).map { $0.replacingOccurrences(of: "\n", with: " ") } ?? ""
        let hint = versionHint(note.deck + " " + note.noteType + " " + note.tags.joined(separator: " "))

        if let raw = field(.reference), let text = field(.text) {
            let pastedRef = PastedVerse.parse(raw)
            let reference = BibleReference.parse(raw) ?? pastedRef.reference
            let body = PastedVerse.parse(text)
            if let reference, !body.text.isEmpty {
                return AnkiVerseCandidate(deck: note.deck, reference: reference,
                                          text: PastedVerse.cleaned(body.text, reference: reference),
                                          title: title, version: pastedRef.version ?? body.version ?? hint)
            }
        }

        let ordered = roles.enumerated().filter { $0.element != .title }.map(\.offset)
            + roles.indices.filter { roles[$0] == .title }
        let combined = (ordered.isEmpty ? Array(note.fields.indices) : ordered)
            .filter { $0 < note.fields.count && !note.fields[$0].isEmpty && roles[safe: $0] != .title }
            .map { note.fields[$0] }
            .joined(separator: "\n")
        let pasted = PastedVerse.parse(combined)
        guard let reference = pasted.reference, pasted.text.split(separator: " ").count >= 3 else { return nil }
        return AnkiVerseCandidate(deck: note.deck, reference: reference, text: pasted.text,
                                  title: title, version: pasted.version ?? hint)
    }

    private static func versionHint(_ text: String) -> String? {
        let words = Set(text.uppercased().split { !$0.isLetter && !$0.isNumber }.map(String.init))
        for code in ["NIV84", "NIV", "ESV", "NKJV", "KJV", "NLT", "NASB", "CSB", "BSB", "NRSV"] where words.contains(code) {
            return code
        }
        return nil
    }

    // MARK: - Schedules

    static func bestSchedule(_ cards: [AnkiCardSchedule]) -> AnkiCardSchedule? {
        let pool = cards.contains { !$0.isSuspended } ? cards.filter { !$0.isSuspended } : cards
        return pool.max { a, b in
            if a.intervalDays != b.intervalDays { return a.intervalDays < b.intervalDays }
            return rank(a.kind) < rank(b.kind)
        }
    }

    private static func rank(_ kind: AnkiCardSchedule.Kind) -> Int {
        switch kind {
        case .new: return 0
        case .learning: return 1
        case .relearning: return 2
        case .review: return 3
        }
    }

    static func state(for schedule: AnkiCardSchedule, key: String, now: Date,
                      config: SRSConfig = .default) -> SRSCardState? {
        let ease = schedule.ease > 0 ? max(schedule.ease, config.easeFloor) : config.startingEase
        switch schedule.kind {
        case .new:
            return nil
        case .learning:
            return SRSCardState(key: key, phase: .learning, interval: 0, ease: ease,
                                reps: schedule.reps, lapses: schedule.lapses, learningStep: 0,
                                due: schedule.due ?? now, lastReviewed: schedule.lastReviewed ?? now)
        case .relearning:
            return SRSCardState(key: key, phase: .learning, interval: max(schedule.intervalDays, 1), ease: ease,
                                reps: schedule.reps, lapses: schedule.lapses, learningStep: 0,
                                due: schedule.due ?? now, lastReviewed: schedule.lastReviewed ?? now)
        case .review:
            return SRSCardState(key: key, phase: .review, interval: max(schedule.intervalDays, 1), ease: ease,
                                reps: max(schedule.reps, 1), lapses: schedule.lapses, learningStep: 0,
                                due: schedule.due ?? now, lastReviewed: schedule.lastReviewed ?? now)
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? { indices.contains(index) ? self[index] : nil }
}
