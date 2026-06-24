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

    /// Plain, factual reminder body — just the counts, no marketing. Returns
    /// `nil` when nothing is due, so no reminder is sent that day.
    /// e.g. "3 reviews, 1 new verse" · "1 review" · "2 new verses".
    static func reminderBody(review: Int, new: Int) -> String? {
        var parts: [String] = []
        if review > 0 { parts.append("\(review) \(review == 1 ? "review" : "reviews")") }
        if new   > 0 { parts.append("\(new) new \(new == 1 ? "verse" : "verses")") }
        return parts.isEmpty ? nil : parts.joined(separator: ", ")
    }
}
