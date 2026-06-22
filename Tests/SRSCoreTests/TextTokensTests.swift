import XCTest
@testable import SRSCore

final class TextTokensTests: XCTestCase {

    func testSimpleSplit() {
        XCTAssertEqual("the quick fox".wordTokens, ["the", "quick", "fox"])
    }

    func testCollapsesRuns() {
        XCTAssertEqual("the   quick  fox".wordTokens, ["the", "quick", "fox"])
        XCTAssertEqual("  hi   there  ".wordTokens, ["hi", "there"])
    }

    func testEmpty() {
        XCTAssertEqual("".wordTokens, [])
        XCTAssertEqual("     ".wordTokens, [])
    }

    func testDoubleDashSplits() {
        XCTAssertEqual("life--death".wordTokens, ["life", "death"])
        XCTAssertEqual("a -- b".wordTokens, ["a", "b"])
    }

    func testSingleHyphenKept() {
        XCTAssertEqual("God-breathed word".wordTokens, ["God-breathed", "word"])
    }

    func testStripsEndQuotesKeepsInnerPunctuation() {
        XCTAssertEqual("\"Until".wordTokens, ["Until"])
        XCTAssertEqual("`Man".wordTokens, ["Man"])
        XCTAssertEqual("said,\"".wordTokens, ["said,"])     // trailing quote stripped, comma kept
    }

    func testKeepsMiddleApostrophe() {
        XCTAssertEqual("don't".wordTokens, ["don't"])
        XCTAssertEqual("it's mine".wordTokens, ["it's", "mine"])
    }

    func testCurlyAndGuillemetQuotes() {
        XCTAssertEqual("\u{2018}Man".wordTokens, ["Man"])      // ‘
        XCTAssertEqual("\u{201C}Word\u{201D}".wordTokens, ["Word"])  // “ ”
        XCTAssertEqual("\u{00AB}x\u{00BB}".wordTokens, ["x"])  // « »
    }

    func testTrimmingQuotationDelimitersOnEnds() {
        XCTAssertEqual("\"hello\"".trimmingQuotationDelimitersOnEnds(), "hello")
        XCTAssertEqual("'x'".trimmingQuotationDelimitersOnEnds(), "x")
        XCTAssertEqual("\u{201C}smart\u{201D}".trimmingQuotationDelimitersOnEnds(), "smart")
        XCTAssertEqual("plain".trimmingQuotationDelimitersOnEnds(), "plain")
        XCTAssertEqual("''".trimmingQuotationDelimitersOnEnds(), "")
    }

    func testRealVerseFragment() {
        let s = "\"And this is the testimony: God has given us eternal life--and this life is in his Son.\""
        let tokens = s.wordTokens
        XCTAssertEqual(tokens.first, "And")        // leading quote stripped
        XCTAssertEqual(tokens.last, "Son.")         // trailing quote stripped, period kept
        XCTAssertTrue(tokens.contains("life"))      // "life--and" split into life / and
        XCTAssertTrue(tokens.contains("and"))
        XCTAssertFalse(tokens.contains(""))         // no empty tokens
    }
}
