import XCTest
@testable import SRSCore

final class DiffEngineTests: XCTestCase {

    private func kinds(_ d: [DiffWord]) -> [DiffWord.Kind] { d.map(\.kind) }
    private func texts(_ d: [DiffWord]) -> [String] { d.map(\.text) }

    // MARK: - Exact / empty cases

    func testAllCorrect() {
        let d = DiffEngine.buildDiffs(typed: ["the", "quick", "fox"], target: ["the", "quick", "fox"])
        XCTAssertEqual(kinds(d), [.correct, .correct, .correct])
        XCTAssertEqual(texts(d), ["the", "quick", "fox"])
    }

    func testEmptyTypedIsAllMissing() {
        let d = DiffEngine.buildDiffs(typed: [], target: ["a", "b"])
        XCTAssertEqual(kinds(d), [.missing, .missing])
        XCTAssertEqual(texts(d), ["a", "b"])
    }

    func testEmptyTargetIsAllExtra() {
        let d = DiffEngine.buildDiffs(typed: ["a", "b"], target: [])
        XCTAssertEqual(kinds(d), [.extra, .extra])
    }

    func testBothEmpty() {
        XCTAssertTrue(DiffEngine.buildDiffs(typed: [], target: []).isEmpty)
    }

    // MARK: - Edits

    func testMissingWordInMiddle() {
        let d = DiffEngine.buildDiffs(typed: ["the", "fox"], target: ["the", "quick", "fox"])
        XCTAssertEqual(kinds(d), [.correct, .missing, .correct])
        XCTAssertEqual(texts(d), ["the", "quick", "fox"])
    }

    func testExtraWord() {
        let d = DiffEngine.buildDiffs(typed: ["the", "big", "fox"], target: ["the", "fox"])
        XCTAssertEqual(texts(d.filter { $0.kind == .extra }), ["big"])
        XCTAssertEqual(texts(d.filter { $0.kind == .correct }), ["the", "fox"])
    }

    func testWrongWordCarriesCorrection() {
        let d = DiffEngine.buildDiffs(typed: ["the", "quik", "fox"], target: ["the", "quick", "fox"])
        let wrong = d.filter { $0.kind == .wrong }
        XCTAssertEqual(wrong.map(\.text), ["quik"])
        XCTAssertEqual(wrong.map(\.correction), ["quick"])
    }

    // MARK: - Normalization

    func testCaseInsensitive() {
        XCTAssertTrue(DiffEngine.normalizedMatch("The", "the"))
        XCTAssertTrue(DiffEngine.normalizedMatch("GOD", "god"))
        XCTAssertFalse(DiffEngine.normalizedMatch("god", "lord"))
    }

    func testPunctuationIgnoredInMatch() {
        XCTAssertTrue(DiffEngine.normalizedMatch("Son.", "Son"))
        XCTAssertTrue(DiffEngine.normalizedMatch("life;", "life"))
        XCTAssertTrue(DiffEngine.normalizedMatch("\"Until", "Until"))
        XCTAssertTrue(DiffEngine.normalizedMatch("don't", "dont"))
    }

    func testNormalize() {
        XCTAssertEqual(DiffEngine.normalize("God,"), "god")
        XCTAssertEqual(DiffEngine.normalize("Son!"), "son")
        XCTAssertEqual(DiffEngine.normalize("\u{201C}Whoever\u{201D}"), "whoever")
    }

    // MARK: - SubmitResult

    func testSubmitResultIsAllCorrect() {
        let ok    = [DiffWord(text: "a", kind: .correct)]
        let bad   = [DiffWord(text: "b", kind: .missing)]
        XCTAssertTrue(SubmitResult(titleDiffs: ok, verseDiffs: ok).isAllCorrect)
        XCTAssertFalse(SubmitResult(titleDiffs: ok, verseDiffs: bad).isAllCorrect)
        XCTAssertFalse(SubmitResult(titleDiffs: bad, verseDiffs: ok).isAllCorrect)
        // An empty section is never "all correct".
        XCTAssertFalse(SubmitResult(titleDiffs: [], verseDiffs: ok).isAllCorrect)
        XCTAssertFalse(SubmitResult(titleDiffs: ok, verseDiffs: []).isAllCorrect)
    }

    // MARK: - Properties

    /// Identical input ⇒ every word correct and nothing dropped.
    func testIdenticalIsAllCorrectProperty() {
        var rng = SplitMix64(seed: 0xD1FF_0001)
        let vocab = ["the", "quick", "brown", "fox", "god", "son", "life", "word"]
        for _ in 0..<5_000 {
            let n = Int.random(in: 0...8, using: &rng)
            let target = (0..<n).map { _ in vocab.randomElement(using: &rng)! }
            let d = DiffEngine.buildDiffs(typed: target, target: target)
            XCTAssertEqual(d.count, target.count)
            XCTAssertTrue(d.allSatisfy { $0.kind == .correct })
        }
    }

    /// Every target word is accounted for exactly once (as correct / missing /
    /// wrong) — the diff never silently drops a target word.
    func testTargetCoverageProperty() {
        var rng = SplitMix64(seed: 0xBEEF_0002)
        let vocab = ["a", "b", "c", "d", "e"]
        for _ in 0..<5_000 {
            let target = (0..<Int.random(in: 1...6, using: &rng)).map { _ in vocab.randomElement(using: &rng)! }
            let typed  = (0..<Int.random(in: 0...6, using: &rng)).map { _ in vocab.randomElement(using: &rng)! }
            let d = DiffEngine.buildDiffs(typed: typed, target: target)
            let consumedTargets = d.filter { $0.kind == .correct || $0.kind == .missing || $0.kind == .wrong }.count
            XCTAssertEqual(consumedTargets, target.count)
            let consumedTyped = d.filter { $0.kind == .correct || $0.kind == .extra || $0.kind == .wrong }.count
            XCTAssertEqual(consumedTyped, typed.count)
        }
    }
}
