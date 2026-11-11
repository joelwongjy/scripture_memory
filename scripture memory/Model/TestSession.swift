import Foundation

/// Distinguishes a normal user-picked session from an SRS-driven daily session.
/// SRS sessions show grading buttons after each card and update SRSStore.
enum SessionKind {
    case custom
    case srs
    case pack
}

struct TestSession: Identifiable {
    let id    = UUID()
    let verses: [Verse]
    var kind:  SessionKind = .custom
    /// 1 for the review itself; 2 and on for another look at cards just missed.
    var round = 1
    /// The card it opens on.
    var startIndex = 0
    var entry: PracticeEntry?
}

extension TestSession {
    static func practice(_ verses: [Verse], from start: Int, entry: PracticeEntry) -> TestSession? {
        guard verses.indices.contains(start) else { return nil }
        return TestSession(verses: verses, kind: .pack, startIndex: start, entry: entry)
    }

    /// Today's review across `activePacks`, or `nil` when nothing is due.
    @MainActor
    static func dailyReview(activePacks: [Pack], newCap: NewCardCap, dailyReviewCap: Int) -> TestSession? {
        let verses = SRSQueueBuilder.buildAllPacksSession(
            packs: activePacks, store: SRSStore.shared,
            newCap: newCap, dailyReviewCap: dailyReviewCap
        )
        return verses.isEmpty ? nil : TestSession(verses: verses, kind: .srs)
    }
}
