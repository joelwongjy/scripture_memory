import XCTest
import Foundation
@testable import SRSCore

final class AnkiImportTests: XCTestCase {

    struct ExpectedCard: Decodable {
        let kind: String
        let isSuspended: Bool
        let intervalDays: Double
        let ease: Double
        let due: Double?
        let reps: Int
        let lapses: Int
        let lastReviewed: Double?
    }

    struct ExpectedNote: Decodable {
        let deck: String
        let noteType: String
        let fieldNames: [String]
        let fields: [String]
        let tags: [String]
        let cards: [ExpectedCard]
    }

    struct ExpectedImport: Decodable {
        let deckNames: [String]
        let notes: [ExpectedNote]
    }

    struct TextExport: Decodable {
        let file: String
        let expected: ExpectedImport
    }

    struct TextCase: Decodable {
        let name: String
        let input: String
        let expected: ExpectedImport
    }

    struct TextError: Decodable {
        let name: String
        let input: String
        let error: String
    }

    struct CleaningCase: Decodable {
        let input: String
        let html: Bool
        let output: String
    }

    struct DetectionCase: Decodable {
        let input: String
        let html: Bool
    }

    struct Row: Decodable {
        let type: Int
        let queue: Int
        let due: Int64
        let interval: Int64
        let factor: Int64
        let reps: Int
        let lapses: Int
        let originalDue: Int64
        let originalDeckID: Int64
        let lastReviewMilliseconds: Int64?
    }

    struct Timing: Decodable {
        let creation: Int64
        let creationMinutesWest: Int?
        let currentMinutesWest: Int
        let rolloverHour: Int?

        var value: AnkiCollectionTiming {
            AnkiCollectionTiming(creation: creation, creationMinutesWest: creationMinutesWest,
                                 currentMinutesWest: currentMinutesWest, rolloverHour: rolloverHour)
        }
    }

    struct ScheduleCase: Decodable {
        let name: String
        let row: Row
        let timing: Timing
        let expected: ExpectedCard
    }

    struct TimingCase: Decodable {
        let name: String
        let creation: Int64
        let schedulerVersion: Int?
        let rollover: Int?
        let creationOffset: Int?
        let deviceMinutesWest: Int
        let expected: Timing
    }

    struct Vectors: Decodable {
        let textExport: TextExport
        let textCases: [TextCase]
        let textErrors: [TextError]
        let cleaning: [CleaningCase]
        let htmlDetection: [DetectionCase]
        let schedules: [ScheduleCase]
        let timings: [TimingCase]
    }

    private static let vectorsDirectory = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("shared/test-vectors")

    private func vectors() throws -> Vectors {
        let data = try Data(contentsOf: Self.vectorsDirectory.appendingPathComponent("anki_import.json"))
        return try JSONDecoder().decode(Vectors.self, from: data)
    }

    private func assertCard(_ actual: AnkiCardSchedule, _ expected: ExpectedCard, _ message: String) {
        XCTAssertEqual(actual.kind.rawValue, expected.kind, "\(message) kind")
        XCTAssertEqual(actual.isSuspended, expected.isSuspended, "\(message) isSuspended")
        XCTAssertEqual(actual.intervalDays, expected.intervalDays, accuracy: 1e-9, "\(message) intervalDays")
        XCTAssertEqual(actual.ease, expected.ease, accuracy: 1e-9, "\(message) ease")
        XCTAssertEqual(actual.due?.timeIntervalSince1970, expected.due, "\(message) due")
        XCTAssertEqual(actual.reps, expected.reps, "\(message) reps")
        XCTAssertEqual(actual.lapses, expected.lapses, "\(message) lapses")
        if let expectedLast = expected.lastReviewed, let actualLast = actual.lastReviewed {
            XCTAssertEqual(actualLast.timeIntervalSince1970, expectedLast, accuracy: 1e-6, "\(message) lastReviewed")
        } else {
            XCTAssertNil(actual.lastReviewed, "\(message) lastReviewed")
            XCTAssertNil(expected.lastReviewed, "\(message) lastReviewed")
        }
    }

    private func assertImport(_ actual: AnkiImport, _ expected: ExpectedImport, _ message: String) {
        XCTAssertEqual(actual.deckNames, expected.deckNames, "\(message) deckNames")
        XCTAssertEqual(actual.notes.count, expected.notes.count, "\(message) note count")
        for (index, (note, want)) in zip(actual.notes, expected.notes).enumerated() {
            let label = "\(message) note \(index)"
            XCTAssertEqual(note.deck, want.deck, "\(label) deck")
            XCTAssertEqual(note.noteType, want.noteType, "\(label) noteType")
            XCTAssertEqual(note.fieldNames, want.fieldNames, "\(label) fieldNames")
            XCTAssertEqual(note.fields, want.fields, "\(label) fields")
            XCTAssertEqual(note.tags, want.tags, "\(label) tags")
            XCTAssertEqual(note.cards.count, want.cards.count, "\(label) card count")
            for (cardIndex, (card, wantCard)) in zip(note.cards, want.cards).enumerated() {
                assertCard(card, wantCard, "\(label) card \(cardIndex)")
            }
        }
    }

    func testFieldCleaning() throws {
        for vector in try vectors().cleaning {
            XCTAssertEqual(AnkiFieldCleaner.clean(vector.input, isHTML: vector.html), vector.output, vector.input)
        }
    }

    func testHTMLDetection() throws {
        for vector in try vectors().htmlDetection {
            XCTAssertEqual(AnkiFieldCleaner.containsHTML(vector.input), vector.html, vector.input)
        }
    }

    func testTextExportFixture() throws {
        let export = try vectors().textExport
        let text = try String(contentsOf: Self.vectorsDirectory.appendingPathComponent(export.file), encoding: .utf8)
        assertImport(try AnkiTextExport.parse(text), export.expected, export.file)
    }

    func testTextCases() throws {
        for vector in try vectors().textCases {
            assertImport(try AnkiTextExport.parse(vector.input), vector.expected, vector.name)
        }
    }

    func testTextErrors() throws {
        for vector in try vectors().textErrors {
            XCTAssertThrowsError(try AnkiTextExport.parse(vector.input), vector.name) { error in
                XCTAssertEqual(error as? AnkiImportError, .empty, vector.name)
            }
        }
    }

    func testSchedules() throws {
        for vector in try vectors().schedules {
            let row = AnkiCardRow(
                type: vector.row.type, queue: vector.row.queue, due: vector.row.due,
                interval: vector.row.interval, factor: vector.row.factor, reps: vector.row.reps,
                lapses: vector.row.lapses, originalDue: vector.row.originalDue,
                originalDeckID: vector.row.originalDeckID,
                lastReviewMilliseconds: vector.row.lastReviewMilliseconds
            )
            assertCard(AnkiCardSchedule(row: row, timing: vector.timing.value), vector.expected, vector.name)
        }
    }

    func testTimings() throws {
        for vector in try vectors().timings {
            let timing = AnkiCollectionTiming(
                creation: vector.creation, schedulerVersion: vector.schedulerVersion,
                rollover: vector.rollover, creationOffset: vector.creationOffset,
                deviceMinutesWest: vector.deviceMinutesWest
            )
            XCTAssertEqual(timing, vector.expected.value, vector.name)
        }
    }
}
