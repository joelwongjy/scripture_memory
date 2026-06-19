import XCTest
@testable import SRSCore

final class SRSAlgorithmTests: XCTestCase {

    private let now = Date(timeIntervalSince1970: 1_000_000)
    private let day = 86_400.0

    /// Seconds from `now` until the card is next due.
    private func dueOffset(_ s: SRSCardState) -> TimeInterval { s.due.timeIntervalSince(now) }

    private func reviewState(interval: Double, ease: Double) -> SRSCardState {
        SRSCardState(key: "k", phase: .review, interval: interval, ease: ease,
                     reps: 3, lapses: 0, learningStep: 0, due: now, lastReviewed: nil)
    }

    // MARK: - Learning phase

    func testNewCardGoodWalksLearningStepsThenGraduates() {
        let s1 = updateSRS(state: .newCard(key: "k", now: now), grade: .good, now: now)
        XCTAssertEqual(s1.phase, .learning)
        XCTAssertEqual(s1.learningStep, 1)
        XCTAssertEqual(dueOffset(s1), 600, accuracy: 0.001)   // 10 min step

        let s2 = updateSRS(state: s1, grade: .good, now: now)
        XCTAssertEqual(s2.phase, .review)
        XCTAssertEqual(s2.interval, 1.0, accuracy: 1e-9)       // graduating interval
        XCTAssertEqual(dueOffset(s2), day, accuracy: 0.001)
        XCTAssertGreaterThanOrEqual(s2.reps, 1)
    }

    func testNewCardEasyGraduatesImmediately() {
        let s = updateSRS(state: .newCard(key: "k", now: now), grade: .easy, now: now)
        XCTAssertEqual(s.phase, .review)
        XCTAssertEqual(s.interval, 4.0, accuracy: 1e-9)        // easy interval
        XCTAssertEqual(dueOffset(s), 4 * day, accuracy: 0.001)
    }

    func testNewCardAgainResetsToFirstStep() {
        let s = updateSRS(state: .newCard(key: "k", now: now), grade: .again, now: now)
        XCTAssertEqual(s.phase, .learning)
        XCTAssertEqual(s.learningStep, 0)
        XCTAssertEqual(dueOffset(s), 60, accuracy: 0.001)      // 1 min step
    }

    // MARK: - Review phase

    func testReviewGoodMultipliesByEase() {
        let s = updateSRS(state: reviewState(interval: 10, ease: 2.5), grade: .good, now: now)
        XCTAssertEqual(s.interval, 25, accuracy: 1e-9)
        XCTAssertEqual(s.reps, 4)
    }

    func testReviewHardTrimsEaseAndScales() {
        let s = updateSRS(state: reviewState(interval: 10, ease: 2.5), grade: .hard, now: now)
        XCTAssertEqual(s.ease, 2.35, accuracy: 1e-9)
        XCTAssertEqual(s.interval, 12, accuracy: 1e-9)         // 10 * 1.2
    }

    func testReviewEasyAppliesBonusBeforeInterval() {
        let s = updateSRS(state: reviewState(interval: 10, ease: 2.5), grade: .easy, now: now)
        XCTAssertEqual(s.ease, 2.65, accuracy: 1e-9)           // bonus applied first
        XCTAssertEqual(s.interval, 10 * 2.65 * 1.3, accuracy: 1e-9)
    }

    func testReviewAgainLapsesBackToLearning() {
        let s = updateSRS(state: reviewState(interval: 10, ease: 2.5), grade: .again, now: now)
        XCTAssertEqual(s.phase, .learning)
        XCTAssertEqual(s.lapses, 1)
        XCTAssertEqual(s.ease, 2.3, accuracy: 1e-9)            // 2.5 - 0.20 penalty
        XCTAssertEqual(dueOffset(s), 60, accuracy: 0.001)
    }

    func testEaseNeverDropsBelowFloor() {
        let hard = updateSRS(state: reviewState(interval: 5, ease: 1.3), grade: .hard, now: now)
        XCTAssertEqual(hard.ease, 1.3, accuracy: 1e-9)
        let again = updateSRS(state: reviewState(interval: 5, ease: 1.3), grade: .again, now: now)
        XCTAssertEqual(again.ease, 1.3, accuracy: 1e-9)
    }

    // MARK: - Suggested grade + predicted labels

    func testSuggestedGrade() {
        XCTAssertEqual(suggestedGrade(isAllCorrect: false, mistakes: 0), .again)
        XCTAssertEqual(suggestedGrade(isAllCorrect: true, mistakes: 0), .good)
        XCTAssertEqual(suggestedGrade(isAllCorrect: true, mistakes: 3), .hard)
    }

    func testPredictedIntervalLabelsForFreshCard() {
        let fresh = SRSCardState.newCard(key: "k", now: now)
        XCTAssertEqual(predictedIntervalLabel(state: fresh, grade: .again, now: now), "1m")
        XCTAssertEqual(predictedIntervalLabel(state: fresh, grade: .good, now: now), "10m")
        XCTAssertEqual(predictedIntervalLabel(state: fresh, grade: .easy, now: now), "4d")
    }

    // MARK: - Invariants over random grade walks

    func testRandomWalkKeepsInvariants() {
        var rng = SplitMix64(seed: 0x5EED_1234)
        let grades = SRSGrade.allCases
        for _ in 0..<3_000 {
            var s = SRSCardState.newCard(key: "k", now: now)
            for _ in 0..<Int.random(in: 1...30, using: &rng) {
                s = updateSRS(state: s, grade: grades.randomElement(using: &rng)!, now: now)
                XCTAssertGreaterThanOrEqual(s.ease, 1.3 - 1e-9)            // ease floor
                XCTAssertGreaterThanOrEqual(dueOffset(s), -1e-6)          // never due in the past
                XCTAssertGreaterThanOrEqual(s.reps, 0)
                XCTAssertGreaterThanOrEqual(s.lapses, 0)
                if s.phase == .review {
                    XCTAssertGreaterThanOrEqual(s.interval, 1.0 - 1e-9)   // review >= 1 day
                }
            }
        }
    }
}
