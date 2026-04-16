import Foundation

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

    var packs: [Pack] {
        self == .niv11 ? packsNIV11 : packsNIV84
    }
}
