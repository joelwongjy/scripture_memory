import XCTest
@testable import SRSCore

/// Simulates review days advancing into the FUTURE — reviewing each card on its
/// due date and checking the schedule progresses sanely over time. (The other
/// SRS tests grade at a single fixed `now`; these advance the clock.)
final class SRSScheduleTests: XCTestCase {

    private let day = 86_400.0
    private let start = Date(timeIntervalSince1970: 1_700_000_000)

    /// Review a card on its due date with a fixed grade, `times` times, advancing
    /// `now` to each due date. Returns the (reviewTime, resultingState) trajectory.
    private func reviewOnDueDates(grade: SRSGrade, times: Int,
                                  from initial: SRSCardState? = nil) -> [(now: Date, state: SRSCardState)] {
        var s = initial ?? SRSCardState.newCard(key: "k", now: start)
        var now = start
        var traj: [(Date, SRSCardState)] = []
        for _ in 0..<times {
            now = max(now, s.due)            // user reviews when (or after) it's due
            s = updateSRS(state: s, grade: grade, now: now)
            traj.append((now, s))
        }
        return traj
    }

    func testGoodEveryDueDateGrowsIntervalsIntoTheFuture() {
        let traj = reviewOnDueDates(grade: .good, times: 8)

        // Every review schedules the card strictly into the future.
        for step in traj {
            XCTAssertGreaterThan(step.state.due, step.now, "card must be scheduled forward")
        }

        // Review-phase intervals are non-decreasing across days.
        let intervals = traj.map(\.state).filter { $0.phase == .review }.map(\.interval)
        XCTAssertFalse(intervals.isEmpty)
        for i in 1..<intervals.count {
            XCTAssertGreaterThanOrEqual(intervals[i], intervals[i - 1] - 1e-9)
        }

        // After 8 "Good"s the interval has grown well beyond a few days.
        let last = traj.last!.state
        XCTAssertEqual(last.phase, .review)
        XCTAssertGreaterThan(last.interval, 5)
    }

    func testEasyGraduatesAndIsDueFourDaysOut() {
        let s = updateSRS(state: .newCard(key: "k", now: start), grade: .easy, now: start)
        XCTAssertEqual(s.phase, .review)
        // Not due at +3 days, due exactly at +4 days.
        XCTAssertGreaterThan(s.due, start.addingTimeInterval(3 * day))
        XCTAssertEqual(s.due.timeIntervalSince(start), 4 * day, accuracy: 1)
    }

    func testLapseAfterBuildupResetsTheSchedule() {
        var s = reviewOnDueDates(grade: .good, times: 5).last!.state
        XCTAssertEqual(s.phase, .review)
        XCTAssertGreaterThan(s.interval, 2)

        let now = s.due
        s = updateSRS(state: s, grade: .again, now: now)        // missed it
        XCTAssertEqual(s.phase, .learning)
        XCTAssertEqual(s.lapses, 1)
        XCTAssertEqual(s.interval, 0)
        XCTAssertEqual(s.due.timeIntervalSince(now), 60, accuracy: 1)  // back to first 1m step
    }

    func testTwoWeekGoodStudyKeepsEaseStable() {
        var s = SRSCardState.newCard(key: "k", now: start)
        var now = start
        var reviews = 0
        let end = start.addingTimeInterval(14 * day)
        while now < end, reviews < 60 {
            now = max(now, s.due)
            if now >= end { break }
            s = updateSRS(state: s, grade: .good, now: now)
            reviews += 1
        }
        XCTAssertGreaterThan(reviews, 0)
        XCTAssertGreaterThanOrEqual(s.reps, 1)
        XCTAssertEqual(s.ease, 2.5, accuracy: 1e-9)             // Good never changes ease
        if s.phase == .review { XCTAssertGreaterThanOrEqual(s.interval, 1.0) }
    }

    func testHardSchedulesSoonerThanGood() {
        let base = SRSCardState(key: "k", phase: .review, interval: 10, ease: 2.5,
                                reps: 3, lapses: 0, learningStep: 0, due: start, lastReviewed: nil)
        let good = updateSRS(state: base, grade: .good, now: start)
        let hard = updateSRS(state: base, grade: .hard, now: start)
        XCTAssertLessThan(hard.due, good.due)
    }

    /// Over a long mixed-grade walk that advances the clock to each due date, the
    /// card is NEVER left scheduled in the past, and learning lapses re-shorten it.
    func testMixedGradeWalkNeverDueInThePast() {
        var rng = SplitMix64(seed: 0xDA17_5EED)
        let grades = SRSGrade.allCases
        var s = SRSCardState.newCard(key: "k", now: start)
        var now = start
        for _ in 0..<300 {
            now = max(now, s.due)
            s = updateSRS(state: s, grade: grades.randomElement(using: &rng)!, now: now)
            XCTAssertGreaterThan(s.due, now.addingTimeInterval(-1e-6))
            XCTAssertGreaterThanOrEqual(s.ease, 1.3 - 1e-9)
        }
    }
}
