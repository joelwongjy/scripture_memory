import Foundation

/// Pure decision logic for the daily review reminder, extracted from
/// `NotificationManager` so it can be unit-tested without the
/// UserNotifications framework (which isn't available on a Linux CI runner).
enum ReminderPlan {

    /// Whether a daily reminder should currently be scheduled.
    static func shouldSchedule(enabled: Bool, authorized: Bool) -> Bool {
        enabled && authorized
    }

    /// Clamp a possibly out-of-range hour/minute into valid clock fields.
    static func normalizedTime(hour: Int, minute: Int) -> (hour: Int, minute: Int) {
        (min(max(hour, 0), 23), min(max(minute, 0), 59))
    }

    /// The next time the reminder would fire at `hour:minute` strictly after `now`.
    /// Used for display and tests; the live notification uses a repeating trigger.
    static func nextFireDate(hour: Int, minute: Int, after now: Date,
                             calendar: Calendar = .current) -> Date? {
        let (h, m) = normalizedTime(hour: hour, minute: minute)
        return calendar.nextDate(after: now,
                                 matching: DateComponents(hour: h, minute: m),
                                 matchingPolicy: .nextTime)
    }
}
