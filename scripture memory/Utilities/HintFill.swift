import Foundation

/// Filling an Entire Verse answer box one word at a time.
///
/// The hint types the next word straight into the field rather than showing it
/// beside one. Consistent with the other two study modes, where a hint reveals
/// the word in place and the card still counts as finished — hints are free
/// everywhere, so a separate "this was given to you" display would be the odd
/// one out. It also means Try Again clears the hints for nothing extra: the
/// hints *are* the field, and Try Again already empties it.
///
/// Splits on whitespace rather than `String.wordTokens`, because tokens have
/// their surrounding quotation marks stripped for matching — filling from them
/// would type a subtly different verse to the one printed on the card.
enum HintFill {

    static func words(_ text: String) -> [String] {
        text.split(whereSeparator: { $0 == " " || $0.isNewline }).map(String.init)
    }

    /// `typed` extended by one more word of `target`, or `nil` when there's
    /// nothing left to give.
    ///
    /// Counts what's already in the box and rewrites the whole prefix, so the
    /// hint continues from wherever the user got to — and quietly corrects a
    /// wrong word rather than appending after it.
    static func next(target: String, typed: String) -> String? {
        let targetWords = words(target)
        let typedCount  = words(typed).count
        guard typedCount < targetWords.count else { return nil }
        return targetWords.prefix(typedCount + 1).joined(separator: " ")
    }
}
