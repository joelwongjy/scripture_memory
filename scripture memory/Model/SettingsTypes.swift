import Foundation

// MARK: - New-Card Pacing

/// The period the new-card cap is measured over.
///
/// Two a week is the default because that's the pace the printed programmes
/// set, and it's the one people actually keep. A per-day cap of 1 — the old
/// default — permits seven new verses a week, which mostly succeeds at turning
/// the review queue into a backlog.
enum NewCapUnit: String, CaseIterable {
    case day
    case week

    var settingTitle: String { self == .day ? "New cards / day"  : "New cards / week" }
    var pickerLabel:  String { self == .day ? "Day"              : "Week" }
}

/// The global new-card allowance: how many, over what period.
///
/// One value carrying both halves, rather than an `Int` and a unit travelling
/// separately — a cap of 2 means nothing without knowing what it's 2 of, and
/// the queue builder is the last place that should be guessing.
struct NewCardCap: Equatable {
    let amount: Int
    let unit:   NewCapUnit

    static let amountKey = "srs.newCap"
    /// The daily *review* ceiling. Not part of `NewCardCap` itself, but read
    /// alongside it everywhere the two caps are applied, so the key and its
    /// default live here rather than being re-typed at each call site.
    static let dailyReviewCapKey     = "srs.dailyReviewCap"
    static let dailyReviewCapDefault = 5
    static let unitKey   = "srs.newCapUnit"
    /// Pre-day/week setting. Read only by the migration below.
    static let legacyDailyKey = "srs.dailyNewCap"

    static let fallback = NewCardCap(amount: 2, unit: .week)

    static func current(_ defaults: UserDefaults = .standard) -> NewCardCap {
        let amount = defaults.object(forKey: amountKey) as? Int ?? fallback.amount
        let unit   = (defaults.string(forKey: unitKey).flatMap(NewCapUnit.init(rawValue:))) ?? fallback.unit
        return NewCardCap(amount: amount, unit: unit)
    }

    /// Carry a deliberately-set per-day cap over to the new keys.
    ///
    /// The default moved from 1/day to 2/week, which is a real slowdown — fine
    /// for someone who never opened Settings, wrong for someone who chose 5/day
    /// on purpose. `@AppStorage` only writes its key once the user changes the
    /// control, so the presence of the old key is exactly the signal that a
    /// choice was made. Everyone else lands on the new default.
    static func migrateIfNeeded(_ defaults: UserDefaults = .standard) {
        guard defaults.object(forKey: amountKey) == nil,
              let legacy = defaults.object(forKey: legacyDailyKey) as? Int else { return }
        defaults.set(legacy, forKey: amountKey)
        defaults.set(NewCapUnit.day.rawValue, forKey: unitKey)
    }
}

// MARK: - Study Mode

/// Determines how the user interacts with cards during review.
enum StudyMode: String, CaseIterable {
    case firstLetter
    case fullWord
    case submit

    var displayName: String {
        switch self {
        case .firstLetter: return "First Letter"
        case .fullWord:    return "Full Word"
        case .submit:      return "Entire Verse"
        }
    }

    var instructions: String {
        switch self {
        case .firstLetter: return "Type the first letter of each word to reveal it."
        case .fullWord:    return "Type each word in full."
        case .submit:      return "Type the full verse on the card, then tap Submit to check all at once."
        }
    }

    /// Placeholder text for the single text field used in first-letter / full-word input.
    var inputPlaceholder: String {
        self == .fullWord
            ? "Type each word, press space to check..."
            : "Type first letter of each word..."
    }
}

// MARK: - Bible Version

/// The Bible translation used to source verse text.
enum BibleVersion: String, CaseIterable {
    case niv84 = "NIV84"
    case niv11 = "NIV11"

    var displayName: String {
        switch self {
        case .niv84: return "NIV 1984"
        case .niv11: return "NIV 2011"
        }
    }

    /// Packs that have no NIV 2011 edition in the material we're tested on. Their
    /// cards stay on NIV 1984 whichever translation is selected — otherwise the
    /// user would memorise wording that the test doesn't accept.
    static let niv84OnlyPackNames: Set<String> = ["5 Assurances"]

    /// Built once rather than per access. `packs` is read inside `body` on
    /// several screens — which means once per frame of any animation running on
    /// them — and rebuilding 15 pack values each time is enough copying to show
    /// up as dropped frames in a system transition. The two bundles are fixed for
    /// the life of the process (see `VerseCatalog`), so this can be a constant.
    private static let niv11Packs: [Pack] = packsNIV11.map { pack in
        guard niv84OnlyPackNames.contains(pack.name) else { return pack }
        return packsNIV84.first { $0.name == pack.name } ?? pack
    }

    var packs: [Pack] { self == .niv11 ? Self.niv11Packs : packsNIV84 }
}

// MARK: - Home Verse Start Mode

/// Which mode the Home "current verse" card opens in when tapped: `.read` shows
/// the full verse for study; `.review` starts active-recall practice. The
/// in-session Read/Review toggle still lets the user switch at any time.
enum HomeVerseStartMode: String, CaseIterable {
    case read
    case review

    var displayName: String {
        switch self {
        case .read:   return "Read"
        case .review: return "Review"
        }
    }

    /// CTA verb shown on the Home current-verse card.
    var ctaLabel: String {
        switch self {
        case .read:   return "Read"
        case .review: return "Practice"
        }
    }

    /// Whether the learning session should open in active-recall review mode.
    var opensInReview: Bool { self == .review }
}
