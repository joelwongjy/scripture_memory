import Foundation

struct AnkiImportSummary: Equatable {
    var packsCreated = 0
    var versesAdded = 0
    var progressCarried = 0
    var matchedBundled = 0
}

@MainActor
enum AnkiImporter {

    static func bundledKeys() -> [String: String] {
        var keys: [String: String] = [:]
        for pack in packsNIV84 {
            for verse in pack.verses {
                guard let uid = verse.cardUid else { continue }
                let key = AnkiVerseImport.referenceKey(book: verse.book, reference: verse.reference)
                if keys[key] == nil { keys[key] = uid }
            }
        }
        return keys
    }

    static func plan(for source: AnkiImport) -> AnkiImportPlan {
        AnkiVerseImport.plan(source, bundledKeys: bundledKeys(), bundledPackNames: Set(packsNIV84.map(\.name)),
                             fallbackName: UserPack.defaultName)
    }

    struct DeckChoice: Equatable {
        var include: Bool
        var name: String
    }

    static func apply(_ plan: AnkiImportPlan, decks: [DeckChoice], includeMatches: Bool,
                      now: Date = Date()) -> AnkiImportSummary {
        var summary = AnkiImportSummary()
        var states: [SRSCardState] = []
        var learnt = Set<String>()

        func carry(_ candidate: AnkiVerseCandidate, key: String) {
            guard let schedule = candidate.schedule,
                  let state = AnkiVerseImport.state(for: schedule, key: key, now: now) else { return }
            states.append(state)
            learnt.insert(key)
            summary.progressCarried += 1
        }

        for (i, deck) in plan.decks.enumerated() where i < decks.count && decks[i].include {
            let verses = deck.verses.map { candidate -> UserVerse in
                let verse = UserVerse(id: UserVerse.newID(), title: candidate.title, text: candidate.text,
                                      book: candidate.reference.book.name,
                                      reference: candidate.reference.reference,
                                      version: candidate.version)
                carry(candidate, key: verse.id)
                return verse
            }
            guard !verses.isEmpty else { continue }
            let color = UserPack.colors[(UserPackStore.shared.userPacks.count) % UserPack.colors.count]
            UserPackStore.shared.createPack(name: decks[i].name, color: color, verses: verses)
            summary.packsCreated += 1
            summary.versesAdded += verses.count
        }

        if includeMatches {
            for match in plan.matches {
                carry(match.candidate, key: match.cardUid)
                summary.matchedBundled += 1
            }
        }

        SRSStore.shared.importStates(states)
        LearningStore.shared.markLearnt(keys: learnt)
        return summary
    }
}
