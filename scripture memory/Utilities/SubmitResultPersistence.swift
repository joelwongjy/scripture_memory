import Foundation

// MARK: - Submit result encoding (UserDefaults / session JSON)

/// Codable bridge for `[Int: SubmitResult]` used by pack review files and test session snapshots.
enum SubmitResultPersistence {

    struct Blob: Codable {
        var results: [String: StoredResult]
    }

    struct StoredResult: Codable {
        var titleDiffs: [StoredWord]
        var verseDiffs: [StoredWord]
    }

    struct StoredWord: Codable {
        var text: String
        var kind: String
        var correction: String?
    }

    // MARK: - Data blob (pack per-pack key)

    static func encodeToData(_ dict: [Int: SubmitResult]) -> Data? {
        let results = encodeToMap(dict)
        return try? JSONEncoder().encode(Blob(results: results))
    }

    static func decodeFromData(_ data: Data, validVerseIds: Set<Int>) -> [Int: SubmitResult] {
        guard let blob = try? JSONDecoder().decode(Blob.self, from: data) else { return [:] }
        return decodeFromMap(blob.results, validVerseIds: validVerseIds)
    }

    // MARK: - Inline dictionary (session `SessionProgress` JSON)

    static func encodeToMap(_ dict: [Int: SubmitResult]) -> [String: StoredResult] {
        var out: [String: StoredResult] = [:]
        for (id, r) in dict {
            out[String(id)] = StoredResult(
                titleDiffs: r.titleDiffs.map(wordToStored),
                verseDiffs: r.verseDiffs.map(wordToStored)
            )
        }
        return out
    }

    static func decodeFromMap(_ map: [String: StoredResult]?, validVerseIds: Set<Int>) -> [Int: SubmitResult] {
        guard let map, !map.isEmpty else { return [:] }
        var out: [Int: SubmitResult] = [:]
        for (key, stored) in map {
            guard let id = Int(key), validVerseIds.contains(id),
                  let result = submitResult(from: stored) else { continue }
            out[id] = result
        }
        return out
    }

    // MARK: - Private

    private static func wordToStored(_ w: DiffWord) -> StoredWord {
        let k: String
        switch w.kind {
        case .correct: k = "c"
        case .wrong:   k = "w"
        case .missing: k = "m"
        case .extra:   k = "e"
        }
        return StoredWord(text: w.text, kind: k, correction: w.correction)
    }

    private static func word(from s: StoredWord) -> DiffWord? {
        let kind: DiffWord.Kind
        switch s.kind {
        case "c": kind = .correct
        case "w": kind = .wrong
        case "m": kind = .missing
        case "e": kind = .extra
        default:  return nil
        }
        return DiffWord(text: s.text, kind: kind, correction: s.correction)
    }

    private static func submitResult(from stored: StoredResult) -> SubmitResult? {
        let title = stored.titleDiffs.compactMap(word(from:))
        let verse = stored.verseDiffs.compactMap(word(from:))
        guard title.count == stored.titleDiffs.count,
              verse.count == stored.verseDiffs.count else { return nil }
        return SubmitResult(titleDiffs: title, verseDiffs: verse)
    }
}
