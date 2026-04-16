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
