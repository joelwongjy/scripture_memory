import Foundation

// MARK: - Card Section

/// Identifies which part of a flashcard — title or verse — is currently being studied.
enum CardSection: Hashable {
    case title
    case verse
}
