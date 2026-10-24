import Foundation

/// Distinguishes a normal user-picked session from an SRS-driven daily session.
/// SRS sessions show grading buttons after each card and update SRSStore.
enum SessionKind {
    case custom
    case srs
}

struct TestSession: Identifiable {
    let id    = UUID()
    let verses: [Verse]
    var kind:  SessionKind = .custom
}

extension TestSession {
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
