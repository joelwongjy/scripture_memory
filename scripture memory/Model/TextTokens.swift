import Foundation

// MARK: - String tokenization
//
// Pure, Foundation-only word tokenization shared by the diff engine and the
// study input logic. Lives in Model (not the SwiftUI utilities file) so it can
// be unit-tested without UIKit/SwiftUI — see Tests/SRSCoreTests.

extension String {
    /// Opening/closing marks we strip from each token's ends so study input matches spoken/typed text
    /// (e.g. `"Until` → `Until`, `` `Man `` → `Man`, `said,"` → `said,`). Middle apostrophes stay (`don't`).
    static let quotationDelimiterCharacters: Set<Character> = [
        "\"", "'", "`",
        "\u{2018}", "\u{2019}", "\u{201C}", "\u{201D}",
        "\u{00AB}", "\u{00BB}", "\u{2039}", "\u{203A}",
    ]

    /// Strips `quotationDelimiterCharacters` from both ends, repeatedly.
    func trimmingQuotationDelimitersOnEnds() -> String {
        var t = self
        while let c = t.first, Self.quotationDelimiterCharacters.contains(c) { t.removeFirst() }
        while let c = t.last,  Self.quotationDelimiterCharacters.contains(c) { t.removeLast() }
        return String(t)
    }

    /// Splits into non-empty words on spaces and on `--` (em-dash style in stored text).
    /// Single `-` is kept (e.g. `God-breathed`, `us-whatever`) so only `--` adds a word boundary.
    var wordTokens: [String] {
        components(separatedBy: " ")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .flatMap { piece -> [String] in
                piece
                    .components(separatedBy: "--")
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
            }
            .map { $0.trimmingQuotationDelimitersOnEnds() }
            .filter { !$0.isEmpty }
    }
}
