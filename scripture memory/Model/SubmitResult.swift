import Foundation

// MARK: - Diff Word

/// A single word annotated with the result of comparing a typed answer against the target.
struct DiffWord: Identifiable {
    enum Kind { case correct, wrong, missing, extra }

    let id         = UUID()
    let text:       String
    let kind:       Kind
    let correction: String?     // The expected word when kind == .wrong

    init(text: String, kind: Kind, correction: String? = nil) {
        self.text       = text
        self.kind       = kind
        self.correction = correction
    }
}

// MARK: - Submit Result

/// The outcome of a Submit-mode card attempt, carrying per-word diffs for title and verse.
struct SubmitResult {
    let titleDiffs: [DiffWord]
    let verseDiffs: [DiffWord]

    var isAllCorrect: Bool {
        !titleDiffs.isEmpty && !verseDiffs.isEmpty
            && titleDiffs.allSatisfy { $0.kind == .correct }
            && verseDiffs.allSatisfy { $0.kind == .correct }
    }
}
