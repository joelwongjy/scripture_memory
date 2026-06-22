import XCTest
@testable import SRSCore

final class ReminderPlanTests: XCTestCase {

    func testShouldScheduleRequiresEnabledAndAuthorized() {
        XCTAssertTrue(ReminderPlan.shouldSchedule(enabled: true,  authorized: true))
        XCTAssertFalse(ReminderPlan.shouldSchedule(enabled: true,  authorized: false))
        XCTAssertFalse(ReminderPlan.shouldSchedule(enabled: false, authorized: true))
        XCTAssertFalse(ReminderPlan.shouldSchedule(enabled: false, authorized: false))
    }

    func testNormalizedTimePassesValid() {
        let t = ReminderPlan.normalizedTime(hour: 8, minute: 30)
        XCTAssertEqual(t.hour, 8)
        XCTAssertEqual(t.minute, 30)
    }

    func testNormalizedTimeClamps() {
        XCTAssertEqual(ReminderPlan.normalizedTime(hour: -1, minute: -5).hour, 0)
        XCTAssertEqual(ReminderPlan.normalizedTime(hour: -1, minute: -5).minute, 0)
        XCTAssertEqual(ReminderPlan.normalizedTime(hour: 25, minute: 99).hour, 23)
        XCTAssertEqual(ReminderPlan.normalizedTime(hour: 25, minute: 99).minute, 59)
        XCTAssertEqual(ReminderPlan.normalizedTime(hour: 23, minute: 59).hour, 23)
        XCTAssertEqual(ReminderPlan.normalizedTime(hour: 0, minute: 0).minute, 0)
    }

    private func utcCalendar() -> Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }

    func testNextFireDateIsInFutureAtRequestedTime() {
        let cal = utcCalendar()
        let now = Date(timeIntervalSince1970: 0) // 1970-01-01 00:00:00 UTC
        let next = ReminderPlan.nextFireDate(hour: 9, minute: 0, after: now, calendar: cal)
        XCTAssertNotNil(next)
        XCTAssertGreaterThan(next!, now)
        let c = cal.dateComponents([.hour, .minute], from: next!)
        XCTAssertEqual(c.hour, 9)
        XCTAssertEqual(c.minute, 0)
    }

    func testNextFireDateRollsToNextDayWhenTimePassed() {
        let cal = utcCalendar()
        // 10:00 UTC; ask for 09:00 -> must be tomorrow's 09:00.
        let now = Date(timeIntervalSince1970: 10 * 3600)
        let next = ReminderPlan.nextFireDate(hour: 9, minute: 0, after: now, calendar: cal)!
        XCTAssertGreaterThan(next, now)
        XCTAssertGreaterThanOrEqual(next.timeIntervalSince(now), 22 * 3600) // ~23h away
        let c = cal.dateComponents([.hour, .minute], from: next)
        XCTAssertEqual(c.hour, 9)
    }

    func testNextFireDateClampsOutOfRangeTime() {
        let cal = utcCalendar()
        let now = Date(timeIntervalSince1970: 0)
        let next = ReminderPlan.nextFireDate(hour: 30, minute: 80, after: now, calendar: cal)!
        let c = cal.dateComponents([.hour, .minute], from: next)
        XCTAssertEqual(c.hour, 23)
        XCTAssertEqual(c.minute, 59)
    }
}
