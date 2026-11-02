import XCTest
import Foundation
@testable import SRSCore

final class GoldenVectorTests: XCTestCase {

    private static var regenerating: Bool {
        ProcessInfo.processInfo.environment["REGENERATE_VECTORS"] == "1"
    }

    private static let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    private static let vectorsDirectory = root.appendingPathComponent("shared/test-vectors")

    // MARK: - File format

    private struct Section {
        let name: String
        let lines: [String]

        init<T: Encodable>(_ name: String, _ items: [T]) throws {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
            self.name = name
            self.lines = try items.map { String(decoding: try encoder.encode($0), as: UTF8.self) }
        }
    }

    private func write(_ filename: String, description: String, sections: [Section]) throws {
        guard Self.regenerating else { return }
        try FileManager.default.createDirectory(at: Self.vectorsDirectory,
                                                withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        var out = "{\n\"description\": \(String(decoding: try encoder.encode(description), as: UTF8.self))"
        for section in sections {
            out += ",\n\"\(section.name)\": [\n"
            out += section.lines.joined(separator: ",\n")
            out += "\n]"
        }
        out += "\n}\n"
        try out.write(to: Self.vectorsDirectory.appendingPathComponent(filename),
                      atomically: true, encoding: .utf8)
    }

    private func load<T: Decodable>(_ type: T.Type, _ filename: String) throws -> T {
        let data = try Data(contentsOf: Self.vectorsDirectory.appendingPathComponent(filename))
        return try JSONDecoder().decode(type, from: data)
    }

    // MARK: - SRS scheduling

    private struct ConfigVector: Codable, Equatable {
        var learningSteps: [Double]
        var graduatingInterval, easyInterval, startingEase, easeFloor, easeBonus: Double
        var easePenaltyHard, easePenaltyAgain, hardIntervalMultiplier, easyMultiplier: Double
        var knownCardInterval: Double

        init(_ c: SRSConfig) {
            learningSteps = c.learningSteps
            graduatingInterval = c.graduatingInterval
            easyInterval = c.easyInterval
            startingEase = c.startingEase
            easeFloor = c.easeFloor
            easeBonus = c.easeBonus
            easePenaltyHard = c.easePenaltyHard
            easePenaltyAgain = c.easePenaltyAgain
            hardIntervalMultiplier = c.hardIntervalMultiplier
            easyMultiplier = c.easyMultiplier
            knownCardInterval = c.knownCardInterval
        }

        var config: SRSConfig {
            var c = SRSConfig()
            c.learningSteps = learningSteps
            c.graduatingInterval = graduatingInterval
            c.easyInterval = easyInterval
            c.startingEase = startingEase
            c.easeFloor = easeFloor
            c.easeBonus = easeBonus
            c.easePenaltyHard = easePenaltyHard
            c.easePenaltyAgain = easePenaltyAgain
            c.hardIntervalMultiplier = hardIntervalMultiplier
            c.easyMultiplier = easyMultiplier
            c.knownCardInterval = knownCardInterval
            return c
        }
    }

    private struct StepCase: Codable, Equatable {
        var name: String
        var config: ConfigVector?
        var state: SRSCardState
        var grade: SRSGrade
        var now: Double
        var expected: SRSCardState
        var label: String
    }

    private struct SequenceStep: Codable, Equatable {
        var grade: SRSGrade
        var now: Double
        var state: SRSCardState
    }

    private struct SequenceCase: Codable, Equatable {
        var name: String
        var initial: SRSCardState
        var steps: [SequenceStep]
    }

    private struct LabelCase: Codable, Equatable {
        var seconds: Double
        var now: Double
        var label: String
    }

    private struct InitialCase: Codable, Equatable {
        var kind: String
        var key: String
        var now: Double
        var expected: SRSCardState
    }

    private struct SuggestedCase: Codable, Equatable {
        var isAllCorrect: Bool
        var mistakes: Int
        var expected: SRSGrade
    }

    private struct SRSVectors: Codable {
        var steps: [StepCase]
        var sequences: [SequenceCase]
        var labels: [LabelCase]
        var initialStates: [InitialCase]
        var suggestedGrades: [SuggestedCase]
    }

    private func date(_ t: Double) -> Date { Date(timeIntervalSinceReferenceDate: t) }

    private func stepCase(_ name: String, _ config: SRSConfig?, _ state: SRSCardState,
                          _ grade: SRSGrade, _ now: Double) -> StepCase {
        let c = config ?? .default
        return StepCase(name: name, config: config.map(ConfigVector.init), state: state, grade: grade, now: now,
                        expected: updateSRS(state: state, grade: grade, now: date(now), config: c),
                        label: predictedIntervalLabel(state: state, grade: grade, now: date(now), config: c))
    }

    private func srsSteps() -> [StepCase] {
        let t0 = 784_000_000.0
        let fractional = 784_000_000.123456
        var cases: [StepCase] = []

        let configs: [(String, SRSConfig?)] = {
            var empty = SRSConfig(); empty.learningSteps = []
            var single = SRSConfig(); single.learningSteps = [300]
            var three = SRSConfig(); three.learningSteps = [60, 600, 3_600]
            var custom = SRSConfig()
            custom.graduatingInterval = 2; custom.easyInterval = 7; custom.startingEase = 2.1
            custom.easeFloor = 1.5; custom.easeBonus = 0.2; custom.easePenaltyHard = 0.1
            custom.easePenaltyAgain = 0.33; custom.hardIntervalMultiplier = 1.15
            custom.easyMultiplier = 1.45; custom.knownCardInterval = 5
            return [("default", nil), ("emptySteps", empty), ("singleStep", single),
                    ("threeSteps", three), ("custom", custom)]
        }()

        for (configName, config) in configs {
            let c = config ?? .default
            for grade in SRSGrade.allCases {
                for now in [t0, fractional] {
                    let new = SRSCardState.newCard(key: "k", now: date(now))
                    let known = SRSCardState.knownCard(key: "k", now: date(now), config: c)
                    let learnt = SRSCardState.justLearnt(key: "k", now: date(now), config: c)
                    cases.append(stepCase("\(configName)/new/\(grade)", config, new, grade, now))
                    cases.append(stepCase("\(configName)/known/\(grade)", config, known, grade, now))
                    cases.append(stepCase("\(configName)/justLearnt/\(grade)", config, learnt, grade, now))
                    for step in 0...4 {
                        var s = new
                        s.learningStep = step
                        s.reps = step % 2
                        cases.append(stepCase("\(configName)/learningStep\(step)/\(grade)", config, s, grade, now))
                    }
                    var lapsed = new
                    lapsed.ease = 1.5; lapsed.lapses = 3; lapsed.reps = 9
                    cases.append(stepCase("\(configName)/lapsed/\(grade)", config, lapsed, grade, now))
                }
            }
        }

        for interval in [0.0, 0.5, 1, 2.5, 3, 10, 37.3, 365, 1_000.123] {
            for ease in [1.3, 1.31, 1.45, 1.5, 2.3, 2.5, 2.65, 3.1] {
                for grade in SRSGrade.allCases {
                    let s = SRSCardState(key: "k", phase: .review, interval: interval, ease: ease,
                                         reps: 3, lapses: 1, learningStep: 0, due: date(t0), lastReviewed: date(t0 - 86_400))
                    cases.append(stepCase("review/\(interval)/\(ease)/\(grade)", nil, s, grade, t0))
                }
            }
        }
        return cases
    }

    private func walk(_ name: String, from initial: SRSCardState, start: Double,
                      grades: [SRSGrade], delay: (Int) -> Double = { _ in 0 }) -> SequenceCase {
        var s = initial
        var now = start
        var steps: [SequenceStep] = []
        for (i, grade) in grades.enumerated() {
            now = max(now, s.due.timeIntervalSinceReferenceDate) + delay(i)
            s = updateSRS(state: s, grade: grade, now: date(now))
            steps.append(SequenceStep(grade: grade, now: now, state: s))
        }
        return SequenceCase(name: name, initial: initial, steps: steps)
    }

    private func srsSequences() -> [SequenceCase] {
        let start = 784_000_000.0
        let new = SRSCardState.newCard(key: "k", now: date(start))
        let known = SRSCardState.knownCard(key: "k", now: date(start))
        var cases: [SequenceCase] = [
            walk("allGood", from: new, start: start, grades: Array(repeating: .good, count: 40)),
            walk("allEasy", from: new, start: start, grades: Array(repeating: .easy, count: 25)),
            walk("allHard", from: new, start: start, grades: Array(repeating: .hard, count: 40)),
            walk("allAgain", from: new, start: start, grades: Array(repeating: .again, count: 10)),
            walk("knownAllGood", from: known, start: start, grades: Array(repeating: .good, count: 25)),
            walk("hardToFloor", from: known, start: start, grades: Array(repeating: .hard, count: 30)),
            walk("repeatedLapses", from: new, start: start, grades:
                    Array(repeating: [.good, .good, .good, .good, .again] as [SRSGrade], count: 12).flatMap { $0 }),
            walk("lapseThenRecover", from: known, start: start, grades:
                    [.good, .good, .again, .again, .hard, .good, .good, .good, .easy, .again, .easy, .hard]),
        ]
        var rng = SplitMix64(seed: 0x60_1DE4_5EED)
        for i in 0..<30 {
            let count = Int.random(in: 10...30, using: &rng)
            let grades = (0..<count).map { _ in SRSGrade.allCases.randomElement(using: &rng)! }
            let delays = (0..<count).map { _ in Double(Int.random(in: 0...200_000, using: &rng)) / 8 }
            let initial = i.isMultiple(of: 3) ? known : new
            cases.append(walk("fuzz\(i)", from: initial, start: start, grades: grades, delay: { delays[$0] }))
        }
        return cases
    }

    private func labelSeconds(_ seconds: Double, now: Double) -> String {
        var config = SRSConfig()
        config.learningSteps = [seconds]
        return predictedIntervalLabel(state: .newCard(key: "k", now: date(now)), grade: .again,
                                      now: date(now), config: config)
    }

    private func srsLabels() -> [LabelCase] {
        let day = 86_400.0
        let seconds: [Double] = [
            0, 0.5, 1, 59, 59.75, 60, 61, 119, 120, 599, 600, 3_599, 3_600, 3_660, 7_199, 7_200,
            86_399, day, day * 1.25, day * 1.5, day * 2.5, day * 3.5, day * 29, day * 29.5, day * 29.75,
            day * 30, day * 44, day * 45, day * 75, day * 105, day * 364, day * 364.75, day * 365,
            day * 547, day * 547.5, day * 912.5, day * 3_650,
        ]
        return [784_000_000.0, 784_000_000.5, 1_000_000].flatMap { now in
            seconds.map { LabelCase(seconds: $0, now: now, label: labelSeconds($0, now: now)) }
        }
    }

    private func srsInitial() -> [InitialCase] {
        [784_000_000.0, 784_000_000.25].flatMap { now -> [InitialCase] in
            [
                InitialCase(kind: "new", key: "uid-1", now: now, expected: .newCard(key: "uid-1", now: date(now))),
                InitialCase(kind: "known", key: "uid-2", now: now, expected: .knownCard(key: "uid-2", now: date(now))),
                InitialCase(kind: "justLearnt", key: "uid-3", now: now, expected: .justLearnt(key: "uid-3", now: date(now))),
            ]
        }
    }

    private func srsSuggested() -> [SuggestedCase] {
        [true, false].flatMap { correct in
            [0, 1, 2, 5, 9].map {
                SuggestedCase(isAllCorrect: correct, mistakes: $0,
                              expected: suggestedGrade(isAllCorrect: correct, mistakes: $0))
            }
        }
    }

    func testSRSSchedulingVectors() throws {
        try write("srs_scheduling.json",
                  description: "updateSRS and friends. Dates are seconds since 2001-01-01, the format SRSCardState is stored in.",
                  sections: [
                    Section("steps", srsSteps()),
                    Section("sequences", srsSequences()),
                    Section("labels", srsLabels()),
                    Section("initialStates", srsInitial()),
                    Section("suggestedGrades", srsSuggested()),
                  ])
        let v = try load(SRSVectors.self, "srs_scheduling.json")
        XCTAssertFalse(v.steps.isEmpty)
        for c in v.steps {
            XCTAssertEqual(c, stepCase(c.name, c.config?.config, c.state, c.grade, c.now), c.name)
        }
        for c in v.sequences {
            var s = c.initial
            for (i, step) in c.steps.enumerated() {
                s = updateSRS(state: s, grade: step.grade, now: date(step.now))
                XCTAssertEqual(s, step.state, "\(c.name) step \(i)")
            }
        }
        for c in v.labels {
            XCTAssertEqual(c.label, labelSeconds(c.seconds, now: c.now), "\(c.seconds)")
        }
        for c in v.initialStates {
            let now = date(c.now)
            let state: SRSCardState
            switch c.kind {
            case "new":   state = .newCard(key: c.key, now: now)
            case "known": state = .knownCard(key: c.key, now: now)
            default:      state = .justLearnt(key: c.key, now: now)
            }
            XCTAssertEqual(c.expected, state, c.kind)
        }
        for c in v.suggestedGrades {
            XCTAssertEqual(c.expected, suggestedGrade(isAllCorrect: c.isAllCorrect, mistakes: c.mistakes))
        }
    }

    // MARK: - SRSMath

    private struct DripCase: Codable, Equatable {
        var budget: Int
        var candidates: [Int]
        var expected: [Int]
    }

    private struct SRSMathVectors: Codable {
        var drip: [DripCase]
    }

    func testSRSMathVectors() throws {
        var rng = SplitMix64(seed: 0xD219_0001)
        var cases: [([Int], Int)] = [([0, 5, 5, 5], 2), ([3, 3], 0), ([3], -5), ([-2, 3], 5), ([], 5), ([2, 3], 10), ([2, 5], 3)]
        for _ in 0..<200 {
            let n = Int.random(in: 0...8, using: &rng)
            cases.append(((0..<n).map { _ in Int.random(in: -2...9, using: &rng) }, Int.random(in: -3...12, using: &rng)))
        }
        try write("srs_math.json", description: "SRSMath.dripBudget.", sections: [
            Section("drip", cases.map {
                DripCase(budget: $0.1, candidates: $0.0, expected: SRSMath.dripBudget($0.1, across: $0.0))
            }),
        ])
        for c in try load(SRSMathVectors.self, "srs_math.json").drip {
            XCTAssertEqual(c.expected, SRSMath.dripBudget(c.budget, across: c.candidates))
        }
    }

    // MARK: - Text helpers

    private struct Digest {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        var count = 0

        mutating func add(_ text: String) {
            for byte in text.utf8 {
                hash = (hash ^ UInt64(byte)) &* 0x0000_0100_0000_01B3
            }
            count += 1
        }

        var hex: String { String(hash, radix: 16) }
    }

    private struct BundledVerse: Decodable { let title: String; let verse: String }
    private struct BundledPack: Decodable { let verses: [BundledVerse] }

    private static let bundledFiles = ["verseData.json", "verseDataNIV11.json"]

    private func bundledVerses(_ file: String) throws -> [BundledVerse] {
        let url = Self.root.appendingPathComponent("scripture memory/Resources/\(file)")
        return try JSONDecoder().decode([BundledPack].self, from: Data(contentsOf: url)).flatMap(\.verses)
    }

    private func ranges(_ matches: (Unicode.Scalar) -> Bool) -> [[Int]] {
        var out: [[Int]] = []
        for value in 0..<0x3400 {
            guard let scalar = Unicode.Scalar(UInt32(value)), matches(scalar) else { continue }
            if let last = out.last, last[1] == value - 1 {
                out[out.count - 1][1] = value
            } else {
                out.append([value, value])
            }
        }
        return out
    }

    // MARK: - TextTokens

    private struct StringCase: Codable, Equatable {
        var input: String
        var expected: String
    }

    private struct TokensCase: Codable, Equatable {
        var input: String
        var expected: [String]
    }

    private struct LegacyKeyCase: Codable, Equatable {
        var pack: String
        var book: String
        var reference: String
        var expected: String
    }

    private struct DigestCase: Codable, Equatable {
        var file: String
        var count: Int
        var digest: String
    }

    private struct RangesCase: Codable, Equatable {
        var name: String
        var ranges: [[Int]]
    }

    private struct TextTokensVectors: Codable {
        var tokens: [TokensCase]
        var quotes: [StringCase]
        var legacyKeys: [LegacyKeyCase]
        var catalog: [DigestCase]
        var darwinTokens: [TokensCase]
        var darwinCharacterSets: [RangesCase]
    }

    private func tokenDigest(_ file: String) throws -> DigestCase {
        var digest = Digest()
        for verse in try bundledVerses(file) {
            for token in verse.title.wordTokens + verse.verse.wordTokens { digest.add(token) }
        }
        return DigestCase(file: file, count: digest.count, digest: digest.hex)
    }

    func testTextTokensVectors() throws {
        let inputs = [
            "", " ", "     ", "the quick fox", "the   quick  fox", "  hi   there  ", "life--death", "a -- b",
            "a---b", "a----b", "--", "---", "-- a", "a --", "God-breathed word", "\"Until", "`Man", "said,\"",
            "don't", "it's mine", "\u{2018}Man", "\u{201C}Word\u{201D}", "\u{00AB}x\u{00BB}", "\u{2039}y\u{203A}",
            "\"''\"", "' '", "\" \"", "a \" b", "word\u{2014}word", "word \u{2014} word", "\u{2014}", "- word",
            "Man - the sinner", "\"And this is the testimony: God has given us eternal life--and this life is in his Son.\"",
            "\u{201C}\u{2018}Nested\u{2019}\u{201D}", "'tis", "rock 'n' roll", "1 John 1:9", "100%", "(parens)",
        ]
        let quotes = ["\"hello\"", "'x'", "\u{201C}smart\u{201D}", "plain", "''", "", "\"", "a\"b", "\"a\"b\"",
                      "`'\"x\"'`", "\u{00AB}\u{2039}x\u{203A}\u{00BB}", " \"x\" "]
        let keys = [
            ("TMS 60", "Psalm", "119:9"), ("DEP 1: Assurance", " Psalms ", "1 : 2 - 3"),
            ("Pack", "1 JOHN", "1:9\u{00A0}b"), ("5 Assurances", "John\n", "16:24"), ("", "", ""),
            ("P", "Ephesians\t", "2:8-9"),
        ]
        let quirks = [
            "a\tb", "\tleading", "trailing\t", "a\nb", "\na", "a\n", "x\u{00A0}y", "\u{00A0}x\u{00A0}", "\u{200B}z\u{200B}",
            "\u{2003}em\u{2003}", "\u{3000}ideographic\u{3000}", "\u{0085}nel\u{0085}", "\u{2028}ls\u{2028}",
        ]
        try write("text_tokens.json",
                  description: "String.wordTokens and quote trimming, plus a digest of every bundled verse's tokens. Regenerate after editing the verse JSON.",
                  sections: [
                    Section("tokens", inputs.map { TokensCase(input: $0, expected: $0.wordTokens) }),
                    Section("quotes", quotes.map { StringCase(input: $0, expected: $0.trimmingQuotationDelimitersOnEnds()) }),
                    Section("legacyKeys", keys.map {
                        LegacyKeyCase(pack: $0.0, book: $0.1, reference: $0.2,
                                      expected: SRSKey.make(packName: $0.0, book: $0.1, reference: $0.2))
                    }),
                    Section("catalog", try Self.bundledFiles.map(tokenDigest)),
                    Section("darwinTokens", quirks.map { TokensCase(input: $0, expected: $0.wordTokens) }),
                    Section("darwinCharacterSets", [
                        RangesCase(name: "whitespaces", ranges: ranges { CharacterSet.whitespaces.contains($0) }),
                        RangesCase(name: "whitespacesAndNewlines", ranges: ranges { CharacterSet.whitespacesAndNewlines.contains($0) }),
                    ]),
                  ])
        let v = try load(TextTokensVectors.self, "text_tokens.json")
        for c in v.tokens { XCTAssertEqual(c.expected, c.input.wordTokens, c.input) }
        for c in v.quotes { XCTAssertEqual(c.expected, c.input.trimmingQuotationDelimitersOnEnds(), c.input) }
        for c in v.legacyKeys {
            XCTAssertEqual(c.expected, SRSKey.make(packName: c.pack, book: c.book, reference: c.reference))
        }
        for c in v.catalog { XCTAssertEqual(c, try tokenDigest(c.file), c.file) }
        #if canImport(Darwin)
        for c in v.darwinTokens { XCTAssertEqual(c.expected, c.input.wordTokens, c.input) }
        XCTAssertEqual(v.darwinCharacterSets[0].ranges, ranges { CharacterSet.whitespaces.contains($0) })
        XCTAssertEqual(v.darwinCharacterSets[1].ranges, ranges { CharacterSet.whitespacesAndNewlines.contains($0) })
        #endif
    }

    // MARK: - DiffEngine

    private struct DiffVector: Codable, Equatable {
        var text: String
        var kind: String
        var correction: String?

        init(_ word: DiffWord) {
            text = word.text
            kind = "\(word.kind)"
            correction = word.correction
        }
    }

    private struct DiffCase: Codable, Equatable {
        var name: String
        var typed: [String]
        var target: [String]
        var expected: [DiffVector]
    }

    private struct MatchCase: Codable, Equatable {
        var a: String
        var b: String
        var expected: Bool
    }

    private struct DiffVectors: Codable {
        var diffs: [DiffCase]
        var normalize: [StringCase]
        var matches: [MatchCase]
        var catalog: [DigestCase]
        var darwinCharacterSets: [RangesCase]
    }

    private func diffCase(_ name: String, _ typed: [String], _ target: [String]) -> DiffCase {
        DiffCase(name: name, typed: typed, target: target,
                 expected: DiffEngine.buildDiffs(typed: typed, target: target).map(DiffVector.init))
    }

    private func diffDigest(_ file: String) throws -> DigestCase {
        var digest = Digest()
        for verse in try bundledVerses(file) {
            let target = verse.verse.wordTokens
            var typed: [String] = []
            for (i, token) in target.enumerated() {
                if i % 7 == 3 { continue }
                if i % 11 == 5 { typed.append("xyzzy"); continue }
                typed.append(i % 5 == 0 ? token.uppercased() : token)
            }
            for word in DiffEngine.buildDiffs(typed: typed, target: target) {
                digest.add("\(word.kind)|\(word.text)|\(word.correction ?? "")")
            }
        }
        return DigestCase(file: file, count: digest.count, digest: digest.hex)
    }

    func testDiffEngineVectors() throws {
        var cases: [DiffCase] = [
            diffCase("allCorrect", ["the", "quick", "fox"], ["the", "quick", "fox"]),
            diffCase("emptyTyped", [], ["a", "b"]),
            diffCase("emptyTarget", ["a", "b"], []),
            diffCase("bothEmpty", [], []),
            diffCase("missingMiddle", ["the", "fox"], ["the", "quick", "fox"]),
            diffCase("extraWord", ["the", "big", "fox"], ["the", "fox"]),
            diffCase("wrongWord", ["the", "quik", "fox"], ["the", "quick", "fox"]),
            diffCase("singleWrongAgainstMany", ["x"], ["a", "b", "c"]),
            diffCase("manyWrongAgainstOne", ["x", "y", "z"], ["a"]),
            diffCase("standaloneDash", ["Man", "the", "sinner"], ["Man", "-", "the", "sinner"]),
            diffCase("typedDash", ["Man", "-", "the", "sinner"], ["Man", "-", "the", "sinner"]),
            diffCase("onlyPunctuationTyped", ["-", "--", "."], ["a"]),
            diffCase("onlyPunctuationTarget", ["a"], ["-", "."]),
            diffCase("spelling", ["our", "saviour", "showed", "favour"], ["our", "savior", "showed", "favor"]),
            diffCase("caseAndPunctuation", ["GOD,", "so", "loved!"], ["God", "so", "\"loved\""]),
            diffCase("transposed", ["b", "a"], ["a", "b"]),
            diffCase("decomposed", ["cafe\u{301}"], ["caf\u{E9}"]),
        ]
        var rng = SplitMix64(seed: 0xD1FF_C0DE)
        let vocab = ["a", "b", "c", "d", "the", "The", "god,", "God", "-", "saviour", "savior", "don't", "dont", "\"x\"", "x"]
        for i in 0..<500 {
            let typed = (0..<Int.random(in: 0...9, using: &rng)).map { _ in vocab.randomElement(using: &rng)! }
            let target = (0..<Int.random(in: 0...9, using: &rng)).map { _ in vocab.randomElement(using: &rng)! }
            cases.append(diffCase("fuzz\(i)", typed, target))
        }
        let normalizeInputs = [
            "God,", "Son!", "\u{201C}Whoever\u{201D}", "don't", "don\u{2019}t", "God-breathed", "word\u{2014}word", "\u{2014}",
            "-", "--", "...", "$100", "1+1=2", "a_b", "Saviour", "HONOURED", "fulfilled", "fulfilling", "centre", "centred",
            "realising", "realised", "\u{0391}\u{03A3}", "\u{03A3}\u{0391}\u{03A3}", "\u{0130}", "STRASSE", "stra\u{DF}e", "emoji\u{1F600}",
            "caf\u{E9}", "cafe\u{301}", "", " ", " padded ", "`quoted`", "(Psalm)", "[v1]", "{x}", "#tag", "@you", "100%", "a/b", "a\\b",
        ]
        let pairs: [(String, String)] = [
            ("The", "the"), ("GOD", "god"), ("god", "lord"), ("Son.", "Son"), ("life;", "life"), ("\"Until", "Until"),
            ("don't", "dont"), ("saviour", "savior"), ("honour", "honor"), ("neighbour", "neighbor"), ("realise", "realize"),
            ("baptised", "baptized"), ("defence", "defense"), ("judgement", "judgment"), ("fulfilled", "fulfilled"),
            ("four", "for"), ("hour", "hor"), ("wise", "wize"), ("praise", "praize"), ("honour", "honesty"),
            ("cafe\u{301}", "caf\u{E9}"), ("\u{03A3}\u{0391}\u{03A3}", "\u{03C3}\u{03B1}\u{03C3}"), ("-", ""), ("", ""),
        ]
        try write("diff_engine.json",
                  description: "DiffEngine. The catalog digests score mutated copies of every bundled verse: skip word i when i%7==3, type xyzzy when i%11==5, uppercase when i%5==0. Regenerate after editing the verse JSON.",
                  sections: [
                    Section("diffs", cases),
                    Section("normalize", normalizeInputs.map { StringCase(input: $0, expected: DiffEngine.normalize($0)) }),
                    Section("matches", pairs.map { MatchCase(a: $0.0, b: $0.1, expected: DiffEngine.normalizedMatch($0.0, $0.1)) }),
                    Section("catalog", try Self.bundledFiles.map(diffDigest)),
                    Section("darwinCharacterSets", [
                        RangesCase(name: "punctuationAndSymbols",
                                   ranges: ranges { CharacterSet.punctuationCharacters.union(.symbols).contains($0) }),
                    ]),
                  ])
        let v = try load(DiffVectors.self, "diff_engine.json")
        for c in v.diffs { XCTAssertEqual(c, diffCase(c.name, c.typed, c.target), c.name) }
        for c in v.normalize { XCTAssertEqual(c.expected, DiffEngine.normalize(c.input), c.input) }
        for c in v.matches { XCTAssertEqual(c.expected, DiffEngine.normalizedMatch(c.a, c.b), "\(c.a) / \(c.b)") }
        for c in v.catalog { XCTAssertEqual(c, try diffDigest(c.file), c.file) }
        #if canImport(Darwin)
        XCTAssertEqual(v.darwinCharacterSets[0].ranges,
                       ranges { CharacterSet.punctuationCharacters.union(.symbols).contains($0) })
        #endif
    }

    // MARK: - SpellingVariants

    private struct SpellingVectors: Codable {
        var canonical: [StringCase]
    }

    func testSpellingVariantsVectors() throws {
        let british = ["saviour", "honour", "favour", "labour", "neighbour", "colour", "splendour", "vigour", "valour",
                       "armour", "harbour", "odour", "rumour", "clamour", "endeavour", "behaviour", "humour", "marvellous",
                       "counsellor", "traveller", "worshipper", "defence", "offence", "pretence", "realise", "baptise",
                       "recognise", "apologise", "centre", "fulfil", "skilful", "wilful", "judgement", "grey", "plough",
                       "enrolment", "practise"]
        let american = ["savior", "honor", "favor", "labor", "neighbor", "color", "splendor", "vigor", "valor", "armor",
                        "harbor", "odor", "rumor", "clamor", "endeavor", "behavior", "humor", "marvelous", "counselor",
                        "traveler", "worshiper", "defense", "offense", "pretense", "realize", "baptize", "recognize",
                        "apologize", "center", "fulfill", "skillful", "willful", "judgment", "gray", "plow", "enrollment",
                        "practice"]
        let suffixes = ["", "s", "es", "ed", "d", "ing", "er", "ers", "able", "ably"]
        var inputs: [String] = []
        for stem in british + american {
            inputs += suffixes.map { stem + $0 }
            inputs += ["ed", "ing", "er", "ers"].map { stem + String(stem.last!) + $0 }
        }
        inputs += ["realising", "baptising", "recognising", "apologising", "practising", "centring", "centred",
                   "honourably", "four", "hour", "pour", "devour", "wise", "praise", "promise", "paradise", "", "x"]
        try write("spelling_variants.json", description: "SpellingVariants.canonical.", sections: [
            Section("canonical", inputs.map { StringCase(input: $0, expected: SpellingVariants.canonical($0)) }),
        ])
        for c in try load(SpellingVectors.self, "spelling_variants.json").canonical {
            XCTAssertEqual(c.expected, SpellingVariants.canonical(c.input), c.input)
        }
    }

    // MARK: - ReminderPlan

    private struct ScheduleCase: Codable, Equatable {
        var enabled: Bool
        var authorized: Bool
        var expected: Bool
    }

    private struct TimeCase: Codable, Equatable {
        var hour: Int
        var minute: Int
        var expectedHour: Int
        var expectedMinute: Int
    }

    private struct FireCase: Codable, Equatable {
        var zone: String
        var hour: Int
        var minute: Int
        var after: Double
        var expected: Double?
    }

    private struct BodyCase: Codable, Equatable {
        var review: Int
        var new: Int
        var expected: String?
    }

    private struct ReminderVectors: Codable {
        var shouldSchedule: [ScheduleCase]
        var normalizedTime: [TimeCase]
        var nextFireDate: [FireCase]
        var darwinNextFireDate: [FireCase]
        var reminderBody: [BodyCase]
    }

    private func fire(_ zone: String, _ hour: Int, _ minute: Int, _ after: Double) -> FireCase {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: zone)!
        let next = ReminderPlan.nextFireDate(hour: hour, minute: minute, after: date(after), calendar: cal)
        return FireCase(zone: zone, hour: hour, minute: minute, after: after,
                        expected: next?.timeIntervalSinceReferenceDate)
    }

    private func fireCases() -> [FireCase] {
        var cases: [FireCase] = []
        let t0 = 784_000_000.0
        for (hour, minute) in [(0, 0), (9, 0), (9, 30), (23, 59), (30, 80), (-1, -1)] {
            for offset in [0.0, 1, 3_600, 32_400, 34_200, 43_199.5, 86_399, 86_400, 200_000.25] {
                cases.append(fire("UTC", hour, minute, t0 + offset))
            }
        }
        return cases
    }

    private func darwinFireCases() -> [FireCase] {
        let transitions: [(String, Double)] = [
            ("America/New_York", 1_772_953_200),
            ("America/New_York", 1_793_512_800),
            ("Europe/London", 1_774_746_000),
            ("Europe/London", 1_792_890_000),
            ("Australia/Lord_Howe", 1_775_314_800),
            ("Australia/Lord_Howe", 1_791_041_400),
            ("America/Havana", 1_772_942_400),
            ("Asia/Singapore", 1_772_953_200),
        ]
        var cases: [FireCase] = []
        for (zone, instant) in transitions {
            let start = instant - Self.referenceOffset
            for (hour, minute) in [(0, 0), (0, 30), (1, 0), (1, 30), (1, 45), (2, 0), (2, 15), (2, 30), (3, 0), (23, 59)] {
                var offset = -129_600.0
                while offset <= 129_600 {
                    cases.append(fire(zone, hour, minute, start + offset))
                    offset += 11_220
                }
                var near = -10_800.0
                while near <= 10_800 {
                    cases.append(fire(zone, hour, minute, start + near))
                    near += 900
                }
                for edge in [-3_601.0, -3_600, -3_599, -2_701, -2_700, -2_699, -1_801, -1_800, -1_799, -901, -900, -899, -1, 1] {
                    cases.append(fire(zone, hour, minute, start + edge))
                }
            }
        }
        return cases
    }

    private static let referenceOffset = 978_307_200.0

    private func normalizedTimeCase(_ hour: Int, _ minute: Int) -> TimeCase {
        let t = ReminderPlan.normalizedTime(hour: hour, minute: minute)
        return TimeCase(hour: hour, minute: minute, expectedHour: t.hour, expectedMinute: t.minute)
    }

    func testReminderPlanVectors() throws {
        let times = [(8, 30), (-1, -5), (25, 99), (23, 59), (0, 0), (24, 60), (12, -1), (-3, 30)]
        let bodies = [(3, 1), (1, 2), (1, 0), (5, 0), (0, 1), (0, 2), (0, 0), (-1, 0), (0, -1), (-2, 3)]
        try write("reminder_plan.json",
                  description: "ReminderPlan. Dates are seconds since 2001-01-01. darwinNextFireDate covers daylight-saving gaps and overlaps in named zones.",
                  sections: [
                    Section("shouldSchedule", [true, false].flatMap { e in
                        [true, false].map {
                            ScheduleCase(enabled: e, authorized: $0,
                                         expected: ReminderPlan.shouldSchedule(enabled: e, authorized: $0))
                        }
                    }),
                    Section("normalizedTime", times.map { normalizedTimeCase($0.0, $0.1) }),
                    Section("nextFireDate", fireCases()),
                    Section("darwinNextFireDate", darwinFireCases()),
                    Section("reminderBody", bodies.map {
                        BodyCase(review: $0.0, new: $0.1,
                                 expected: ReminderPlan.reminderBody(review: $0.0, new: $0.1))
                    }),
                  ])
        let v = try load(ReminderVectors.self, "reminder_plan.json")
        for c in v.shouldSchedule {
            XCTAssertEqual(c.expected, ReminderPlan.shouldSchedule(enabled: c.enabled, authorized: c.authorized))
        }
        for c in v.normalizedTime { XCTAssertEqual(c, normalizedTimeCase(c.hour, c.minute)) }
        for c in v.nextFireDate { XCTAssertEqual(c, fire(c.zone, c.hour, c.minute, c.after)) }
        #if canImport(Darwin)
        for c in v.darwinNextFireDate { XCTAssertEqual(c, fire(c.zone, c.hour, c.minute, c.after)) }
        #endif
        for c in v.reminderBody {
            XCTAssertEqual(c.expected, ReminderPlan.reminderBody(review: c.review, new: c.new))
        }
    }

    // MARK: - ScrubberMath

    private struct FractionCase: Codable, Equatable { var index, count: Int; var expected: Double }
    private struct IndexCase: Codable, Equatable { var fraction: Double; var count, expected: Int }
    private struct TravelCase: Codable, Equatable { var containerHeight, thumbSize, inset, expected: Double }
    private struct ThumbIndexCase: Codable, Equatable { var index, count: Int; var travel, inset, expected: Double }
    private struct ThumbFractionCase: Codable, Equatable { var fraction, travel, inset, expected: Double }
    private struct DragFractionCase: Codable, Equatable { var startThumbY, translationY, inset, travel, expected: Double }
    private struct DragIndexCase: Codable, Equatable {
        var startThumbY, translationY, inset, travel: Double
        var count, expected: Int
    }

    private struct ScrubberVectors: Codable {
        var fraction: [FractionCase]
        var index: [IndexCase]
        var trackTravel: [TravelCase]
        var thumbYIndex: [ThumbIndexCase]
        var thumbYFraction: [ThumbFractionCase]
        var fractionForDrag: [DragFractionCase]
        var indexForDrag: [DragIndexCase]
    }

    func testScrubberMathVectors() throws {
        var rng = SplitMix64(seed: 0x5C2B_60D1)
        var fractions: [FractionCase] = []
        for (index, count) in [(0, 10), (9, 10), (0, 1), (4, 0), (-3, 10), (99, 10), (5, 11), (1, 3), (2, 7)] {
            fractions.append(FractionCase(index: index, count: count,
                                          expected: ScrubberMath.fraction(index: index, count: count)))
        }
        var indices: [IndexCase] = []
        for (f, count) in [(0.0, 10), (1.0, 10), (0.5, 11), (-1.0, 10), (2.0, 10), (0.4, 1), (0.5, 2), (0.5, 4),
                           (0.25, 3), (0.75, 3), (0.5, 6), (0.1, 6), (0.3, 6), (0.49999999999999994, 2)] {
            indices.append(IndexCase(fraction: f, count: count, expected: ScrubberMath.index(fraction: f, count: count)))
        }
        var thumbFractions: [ThumbFractionCase] = []
        var dragFractions: [DragFractionCase] = []
        var dragIndices: [DragIndexCase] = []
        var thumbIndices: [ThumbIndexCase] = []
        for _ in 0..<300 {
            let count = Int.random(in: 0...60, using: &rng)
            let i = Int.random(in: -2...62, using: &rng)
            let f = Double.random(in: -0.2...1.2, using: &rng)
            let travel = Double(Int.random(in: 0...400, using: &rng))
            let inset = Double(Int.random(in: 0...16, using: &rng))
            let start = Double.random(in: 0...420, using: &rng)
            let translation = Double.random(in: -500...500, using: &rng)
            fractions.append(FractionCase(index: i, count: count, expected: ScrubberMath.fraction(index: i, count: count)))
            indices.append(IndexCase(fraction: f, count: count, expected: ScrubberMath.index(fraction: f, count: count)))
            thumbIndices.append(ThumbIndexCase(index: i, count: count, travel: travel, inset: inset,
                                               expected: ScrubberMath.thumbY(index: i, count: count, travel: travel, inset: inset)))
            thumbFractions.append(ThumbFractionCase(fraction: f, travel: travel, inset: inset,
                                                    expected: ScrubberMath.thumbY(fraction: f, travel: travel, inset: inset)))
            dragFractions.append(DragFractionCase(startThumbY: start, translationY: translation, inset: inset, travel: travel,
                                                  expected: ScrubberMath.fractionForDrag(startThumbY: start, translationY: translation, inset: inset, travel: travel)))
            dragIndices.append(DragIndexCase(startThumbY: start, translationY: translation, inset: inset, travel: travel, count: count,
                                             expected: ScrubberMath.indexForDrag(startThumbY: start, translationY: translation, inset: inset, travel: travel, count: count)))
        }
        let travels = [(100.0, 40.0, 8.0), (30, 40, 8), (0, 0, 0), (48.5, 12.25, 3.5)].map {
            TravelCase(containerHeight: $0.0, thumbSize: $0.1, inset: $0.2,
                       expected: ScrubberMath.trackTravel(containerHeight: $0.0, thumbSize: $0.1, inset: $0.2))
        }
        try write("scrubber_math.json", description: "ScrubberMath.", sections: [
            Section("fraction", fractions), Section("index", indices), Section("trackTravel", travels),
            Section("thumbYIndex", thumbIndices), Section("thumbYFraction", thumbFractions),
            Section("fractionForDrag", dragFractions), Section("indexForDrag", dragIndices),
        ])
        let v = try load(ScrubberVectors.self, "scrubber_math.json")
        for c in v.fraction { XCTAssertEqual(c.expected, ScrubberMath.fraction(index: c.index, count: c.count)) }
        for c in v.index { XCTAssertEqual(c.expected, ScrubberMath.index(fraction: c.fraction, count: c.count)) }
        for c in v.trackTravel {
            XCTAssertEqual(c.expected, ScrubberMath.trackTravel(containerHeight: c.containerHeight, thumbSize: c.thumbSize, inset: c.inset))
        }
        for c in v.thumbYIndex {
            XCTAssertEqual(c.expected, ScrubberMath.thumbY(index: c.index, count: c.count, travel: c.travel, inset: c.inset))
        }
        for c in v.thumbYFraction {
            XCTAssertEqual(c.expected, ScrubberMath.thumbY(fraction: c.fraction, travel: c.travel, inset: c.inset))
        }
        for c in v.fractionForDrag {
            XCTAssertEqual(c.expected, ScrubberMath.fractionForDrag(startThumbY: c.startThumbY, translationY: c.translationY, inset: c.inset, travel: c.travel))
        }
        for c in v.indexForDrag {
            XCTAssertEqual(c.expected, ScrubberMath.indexForDrag(startThumbY: c.startThumbY, translationY: c.translationY, inset: c.inset, travel: c.travel, count: c.count))
        }
    }

    // MARK: - PackArranger

    private struct ArrangedCase: Codable, Equatable { var order, all, expected: [String] }
    private struct VisibleCase: Codable, Equatable { var order, hidden, all, expected: [String] }
    private struct MovedCase: Codable, Equatable {
        var arranged: [String]
        var source: [Int]
        var destination: Int
        var expected: [String]
    }

    private struct PackVectors: Codable {
        var arranged: [ArrangedCase]
        var visible: [VisibleCase]
        var moved: [MovedCase]
    }

    private func moved(_ arranged: [String], _ source: [Int], _ destination: Int) -> MovedCase {
        MovedCase(arranged: arranged, source: source, destination: destination,
                  expected: PackArranger.movedOrder(arranged: arranged, from: IndexSet(source), to: destination))
    }

    func testPackArrangerVectors() throws {
        var rng = SplitMix64(seed: 0xACED_C0DE)
        let all = ["a", "b", "c", "d", "e", "f"]
        var arranged: [ArrangedCase] = []
        var visible: [VisibleCase] = []
        var moves = [moved(["a", "b", "c"], [0], 3), moved(["a", "b", "c"], [2], 0), moved(["a", "b", "c"], [1], 1),
                     moved(["a", "b", "c"], [1], 2), moved(["a", "b", "c", "d"], [0, 2], 4), moved(["a", "b", "c", "d"], [1, 3], 0),
                     moved(["a", "b", "c", "d"], [], 2), moved(["a", "b", "c"], [0], 99), moved(["a", "b", "c"], [2], -4)]
        for (order, names) in [([], ["a", "b", "c"]), (["c", "a", "b"], ["a", "b", "c"]), (["b", "a"], ["a", "b", "c", "d"]),
                               (["x", "b", "a"], ["a", "b"]), (["a", "a", "b"], ["a", "b", "c"]), ([], [])] as [([String], [String])] {
            arranged.append(ArrangedCase(order: order, all: names, expected: PackArranger.arrangedNames(order: order, all: names)))
        }
        for _ in 0..<150 {
            let order = (0..<Int.random(in: 0...8, using: &rng)).map { _ in (all + ["x", "y"]).randomElement(using: &rng)! }
            let hidden = all.filter { _ in Int.random(in: 0...3, using: &rng) == 0 }
            arranged.append(ArrangedCase(order: order, all: all, expected: PackArranger.arrangedNames(order: order, all: all)))
            visible.append(VisibleCase(order: order, hidden: hidden, all: all,
                                       expected: PackArranger.visibleNames(order: order, hidden: Set(hidden), all: all)))
            let source = all.indices.filter { _ in Int.random(in: 0...2, using: &rng) == 0 }
            moves.append(moved(all, source, Int.random(in: 0...6, using: &rng)))
        }
        try write("pack_arranger.json", description: "PackArranger.", sections: [
            Section("arranged", arranged), Section("visible", visible), Section("moved", moves),
        ])
        let v = try load(PackVectors.self, "pack_arranger.json")
        for c in v.arranged { XCTAssertEqual(c.expected, PackArranger.arrangedNames(order: c.order, all: c.all)) }
        for c in v.visible {
            XCTAssertEqual(c.expected, PackArranger.visibleNames(order: c.order, hidden: Set(c.hidden), all: c.all))
        }
        for c in v.moved { XCTAssertEqual(c, moved(c.arranged, c.source, c.destination)) }
    }

    // MARK: - Calendar

    private struct CalendarCase: Codable, Equatable {
        var zone: String
        var firstWeekday: Int
        var date: Double
        var dayKey: String
        var weekDayKeys: [String]
        var pruneCutoffKey: String
    }

    private struct CalendarVectors: Codable {
        var darwinDays: [CalendarCase]
    }

    private func dayKey(_ date: Date, _ cal: Calendar) -> String {
        let comps = cal.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", comps.year ?? 0, comps.month ?? 0, comps.day ?? 0)
    }

    private func calendarCase(_ zone: String, _ firstWeekday: Int, _ t: Double) -> CalendarCase {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: zone)!
        cal.firstWeekday = firstWeekday
        let date = date(t)
        let week = cal.dateInterval(of: .weekOfYear, for: date)!
        let keys = (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: week.start).map { dayKey($0, cal) } }
        let cutoff = cal.date(byAdding: .day, value: -14, to: date) ?? date
        return CalendarCase(zone: zone, firstWeekday: firstWeekday, date: t, dayKey: dayKey(date, cal),
                            weekDayKeys: keys, pruneCutoffKey: dayKey(cutoff, cal))
    }

    func testCalendarVectors() throws {
        #if canImport(Darwin)
        var rng = SplitMix64(seed: 0xCA1E_DA25)
        let zones = ["UTC", "America/New_York", "Europe/London", "Asia/Singapore", "Asia/Kolkata",
                     "Australia/Lord_Howe", "Pacific/Apia", "America/Havana"]
        var cases: [CalendarCase] = []
        for zone in zones {
            for firstWeekday in [1, 2, 7] {
                for t in [784_000_000.0, 794_620_800, 794_707_199.5, 794_707_200, 815_356_799, 815_356_800] {
                    cases.append(calendarCase(zone, firstWeekday, t))
                }
                for _ in 0..<12 {
                    cases.append(calendarCase(zone, firstWeekday, Double(Int.random(in: 760_000_000...850_000_000, using: &rng)) + 0.5))
                }
            }
        }
        try write("calendar.json",
                  description: "Day keys and week keys in named zones. The Swift side copies SRSStore's calendar steps with the calendar passed in.",
                  sections: [Section("darwinDays", cases)])
        for c in try load(CalendarVectors.self, "calendar.json").darwinDays {
            XCTAssertEqual(c, calendarCase(c.zone, c.firstWeekday, c.date))
        }
        #endif
    }
}
