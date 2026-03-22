import UIKit

// MARK: - Diff Engine

/// Computes word-level diffs between a typed answer and the target using edit distance.
enum DiffEngine {

    // MARK: Public

    /// Builds an array of `DiffWord` annotations comparing `typed` words to `target` words.
    static func buildDiffs(typed: [String], target: [String]) -> [DiffWord] {
        let m = typed.count, n = target.count
        if m == 0 { return target.map { DiffWord(text: $0, kind: .missing) } }
        if n == 0 { return typed.map  { DiffWord(text: $0, kind: .extra)   } }

        let dp = editDistanceTable(typed: typed, target: target)
        return backtrack(dp: dp, typed: typed, target: target)
    }

    /// Case- and punctuation-insensitive equality check.
    static func normalizedMatch(_ a: String, _ b: String) -> Bool {
        normalize(a) == normalize(b)
    }

    static func normalize(_ word: String) -> String {
        word
            .lowercased()
            .components(separatedBy: CharacterSet.punctuationCharacters.union(.symbols))
            .joined()
            .trimmingCharacters(in: .whitespaces)
    }

    // MARK: Private

    private static func editDistanceTable(typed: [String], target: [String]) -> [[Int]] {
        let m = typed.count, n = target.count
        var dp = Array(repeating: Array(repeating: 0, count: n + 1), count: m + 1)
        for i in 0...m { dp[i][0] = i }
        for j in 0...n { dp[0][j] = j }
        for i in 1...m {
            for j in 1...n {
                dp[i][j] = normalizedMatch(typed[i - 1], target[j - 1])
                    ? dp[i - 1][j - 1]
                    : 1 + min(dp[i - 1][j - 1], dp[i - 1][j], dp[i][j - 1])
            }
        }
        return dp
    }

    /// Backtracks through the edit-distance table to produce the annotated diff list.
    ///
    /// Tiebreaking: when a substitution and an insertion cost the same AND there are more
    /// target words than typed words at the current position, prefer insertion (missing)
    /// so a single mistyped word aligns with the *first* target word, not the last.
    private static func backtrack(dp: [[Int]], typed: [String], target: [String]) -> [DiffWord] {
        var diffs: [DiffWord] = []
        var i = typed.count, j = target.count
        while i > 0 || j > 0 {
            if i > 0 && j > 0 && normalizedMatch(typed[i - 1], target[j - 1]) {
                diffs.append(DiffWord(text: target[j - 1], kind: .correct))
                i -= 1; j -= 1
            } else if i > 0 && j > 0
                        && dp[i][j] == dp[i - 1][j - 1] + 1
                        && (j <= i || dp[i][j] < dp[i][j - 1] + 1) {
                diffs.append(DiffWord(text: typed[i - 1], kind: .wrong, correction: target[j - 1]))
                i -= 1; j -= 1
            } else if j > 0 && (i == 0 || dp[i][j - 1] <= dp[i - 1][j]) {
                diffs.append(DiffWord(text: target[j - 1], kind: .missing))
                j -= 1
            } else {
                diffs.append(DiffWord(text: typed[i - 1], kind: .extra))
                i -= 1
            }
        }
        return diffs.reversed()
    }
}

// MARK: - Haptic Engine

/// Thin wrappers around UIKit feedback generators for consistent haptic responses.
enum HapticEngine {
    static func light()   { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func error()   { UINotificationFeedbackGenerator().notificationOccurred(.error) }
}
