import XCTest
import Foundation
@testable import SRSCore

final class BibleReferenceVectorTests: XCTestCase {

    private static let file = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("shared/test-vectors/bible_reference.json")

    private struct ReferenceCase: Codable, Equatable {
        let input: String
        let display: String?
        let usfm: String?
    }

    private struct PasteCase: Codable, Equatable {
        let input: String
        let reference: String?
        let version: String?
        let text: String
    }

    private struct Vectors: Codable {
        let description: String
        let references: [ReferenceCase]
        let pastes: [PasteCase]
    }

    private static let referenceInputs = [
        "John 3:16", "jn 3 16", "Rom 8:28-29", "1 Cor 13:4-7", "I John 1:9", "1jn1:9", "Psalms 119:9,11",
        "Ps 143:8, 10", "Jude 3", "Phil 4:6\u{2013}7", "john 3:16-4:2", "Genesis 1", "Hello 3:16", "Mt 6:33a",
        "Second Timothy 3:16-17", "Song 2:4", "Is 41:10", "Rev 22:21", "Rev 23:1", "Obadiah 1:3", "", "3:16",
        "2 Tim. 2:15", "Prov 3:5-6", "Eph 2:8,9", "1 Thess 5:16-18",
    ]

    private static let pasteInputs = [
        "\u{201C}For God so loved the world that he gave his one and only Son, that whoever believes in him shall not perish but have eternal life.\u{201D}\n\nJohn 3:16 NIV\nhttps://bible.com/bible/111/jhn.3.16.NIV",
        "16 For God so loved the world that he gave his one and only Son,[a] that whoever believes in him shall not perish but have eternal life. 17 For God did not send his Son into the world to condemn the world, but to save the world through him.\nJohn 3:16-17 New International Version (NIV)",
        "Romans 8:28 ESV\nAnd we know that for those who love God all things work together for good, for those who are called according to his purpose.",
        "Trust in the LORD with all your heart and lean not on your own understanding; Proverbs 3:5 (NIV)",
        "Philippians 4:13 - I can do all this through him who gives me strength.",
        "I can do all this through him who gives me strength.",
        "",
    ]

    private func referenceCase(_ input: String) -> ReferenceCase {
        let r = BibleReference.parse(input)
        return ReferenceCase(input: input, display: r?.display, usfm: r?.usfm)
    }

    private func pasteCase(_ input: String) -> PasteCase {
        let p = PastedVerse.parse(input)
        return PasteCase(input: input, reference: p.reference?.display, version: p.version, text: p.text)
    }

    func testVectors() throws {
        if ProcessInfo.processInfo.environment["REGENERATE_VECTORS"] == "1" {
            let vectors = Vectors(description: "BibleReference.parse and PastedVerse.parse.",
                                  references: Self.referenceInputs.map(referenceCase),
                                  pastes: Self.pasteInputs.map(pasteCase))
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            try encoder.encode(vectors).write(to: Self.file)
        }
        let vectors = try JSONDecoder().decode(Vectors.self, from: Data(contentsOf: Self.file))
        for c in vectors.references { XCTAssertEqual(c, referenceCase(c.input), c.input) }
        for c in vectors.pastes { XCTAssertEqual(c, pasteCase(c.input), c.input) }
    }

    func testSingleChapterBookTakesTheNumberAsVerse() {
        XCTAssertEqual(BibleReference.parse("Jude 3")?.display, "Jude 1:3")
    }

    func testAnkiPlanMatchesBundledVersesAndKeepsTheRest() {
        let review = AnkiCardSchedule(kind: .review, isSuspended: false, intervalDays: 37, ease: 2.35,
                                      due: Date(timeIntervalSince1970: 1_800_000_000), reps: 6, lapses: 1,
                                      lastReviewed: Date(timeIntervalSince1970: 1_796_800_000))
        let notes = [
            AnkiNote(deck: "Verses::OYO", noteType: "Basic", fieldNames: ["Front", "Back"],
                     fields: ["John 3:16", "For God so loved the world that he gave his one and only Son"],
                     tags: [], cards: [review]),
            AnkiNote(deck: "Verses::OYO", noteType: "Basic", fieldNames: ["Front", "Back"],
                     fields: ["Micah 6:8", "He has shown all you people what is good."],
                     tags: [], cards: []),
            AnkiNote(deck: "Verses::OYO", noteType: "Basic", fieldNames: ["Front", "Back"],
                     fields: ["What is grace?", "Undeserved favour"], tags: [], cards: []),
        ]
        let key = AnkiVerseImport.referenceKey(book: "John", reference: "3:16")
        let plan = AnkiVerseImport.plan(AnkiImport(notes: notes), bundledKeys: [key: "uid-john"])
        XCTAssertEqual(plan.matches.map(\.cardUid), ["uid-john"])
        XCTAssertEqual(plan.decks.map(\.name), ["OYO"])
        XCTAssertEqual(plan.decks.first?.verses.map(\.reference.display), ["Micah 6:8"])
        XCTAssertEqual(plan.skipped.count, 1)
        let state = AnkiVerseImport.state(for: review, key: "k", now: Date())
        XCTAssertEqual(state?.phase, .review)
        XCTAssertEqual(state?.interval, 37)
        XCTAssertEqual(state?.ease, 2.35)
    }
}
