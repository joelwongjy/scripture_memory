import Foundation

// MARK: - Phase

enum SRSPhase: String, Codable {
    case learning
    case review
}

// MARK: - Grade

/// User's self-assessment after seeing a card. Drives the next interval.
enum SRSGrade: String, CaseIterable, Codable {
    case again
    case hard
    case good
    case easy

    var displayName: String {
        switch self {
        case .again: return "Again"
        case .hard:  return "Hard"
        case .good:  return "Good"
        case .easy:  return "Easy"
        }
    }
}

// MARK: - Card State

/// Per-card scheduling state. Keyed by `Verse.srsKey` (pack + canonical book + normalized reference)
/// so the same passage in the same pack survives a NIV84 ↔ NIV11 switch.
struct SRSCardState: Codable, Equatable {
    var key:           String
    var phase:         SRSPhase
    /// Days. Only meaningful in `.review` phase.
    var interval:      Double
    /// Ease factor. Floored at `config.easeFloor`. Default `config.startingEase`.
    var ease:          Double
    /// Number of successful review reps so far.
    var reps:          Int
    /// Times the card has lapsed back to learning from review.
    var lapses:        Int
    /// Index into `config.learningSteps` while in `.learning`.
    var learningStep:  Int
    /// Absolute next-due moment.
    var due:           Date
    var lastReviewed:  Date?

    /// Initial state for a brand-new card encountered for the first time.
    static func newCard(key: String, now: Date) -> SRSCardState {
        SRSCardState(
            key:          key,
            phase:        .learning,
            interval:     0,
            ease:         SRSConfig.default.startingEase,
            reps:         0,
            lapses:       0,
            learningStep: 0,
            due:          now,            // Available immediately
            lastReviewed: nil
        )
    }
}

// MARK: - Config

/// All SM-2 tunables. Values default to Anki-like settings.
struct SRSConfig {
    /// Successive learning waits, in seconds. New-card grading walks through these.
    var learningSteps:        [TimeInterval] = [60, 600]   // 1 min, 10 min
    /// First review interval after graduating with Good (days).
    var graduatingInterval:   Double = 1.0
    /// First review interval if the user picks Easy from learning (days).
    var easyInterval:         Double = 4.0
    /// Starting ease for newly-graduated cards.
    var startingEase:         Double = 2.5
    /// Lower bound on ease.
    var easeFloor:            Double = 1.3
    /// Ease boost on Easy.
    var easeBonus:            Double = 0.15
    /// Ease penalty on Hard.
    var easePenaltyHard:      Double = 0.15
    /// Ease penalty on Again (lapse).
    var easePenaltyAgain:     Double = 0.20
    /// Multiplier for Hard grade in review phase.
    var hardIntervalMultiplier: Double = 1.2
    /// Extra multiplier for Easy grade in review phase.
    var easyMultiplier:       Double = 1.3

    static let `default` = SRSConfig()
}

// MARK: - Key Helper

/// Builds and normalizes the per-card key. Pack-qualified so cross-pack verse reuse
/// (5 Assurances vs. TMS 60) keeps independent schedules; book and reference normalized
/// so NIV84 ↔ NIV11 alignment survives whitespace and book-name typos.
enum SRSKey {
    static func canonicalBook(_ book: String) -> String {
        return book.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func normalizedReference(_ reference: String) -> String {
        reference.filter { !$0.isWhitespace }.lowercased()
    }

    static func make(packName: String, book: String, reference: String) -> String {
        "\(packName)#\(canonicalBook(book))|\(normalizedReference(reference))"
    }
}
