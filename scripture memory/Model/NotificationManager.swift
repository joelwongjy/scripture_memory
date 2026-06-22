import Foundation
import UserNotifications

/// Schedules / cancels the daily review reminder as a repeating local
/// notification. Pure scheduling decisions live in `ReminderPlan` (testable);
/// this type is the thin UserNotifications adapter.
@MainActor
enum NotificationManager {

    static let reminderId = "daily-review-reminder"

    // Persisted settings keys (also bound by `@AppStorage` in SettingsView).
    enum Keys {
        static let enabled = "notif.reminderEnabled"
        static let hour    = "notif.reminderHour"
        static let minute  = "notif.reminderMinute"
    }
    static let defaultHour = 8
    static let defaultMinute = 0

    static func requestAuthorization() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    static func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    static func scheduleDailyReminder(hour: Int, minute: Int) {
        let (h, m) = ReminderPlan.normalizedTime(hour: hour, minute: minute)
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [reminderId])

        let content = UNMutableNotificationContent()
        content.title = "Scripture Memory"
        content.body  = "Time for your daily review 📖"
        content.sound = .default

        var comps = DateComponents()
        comps.hour = h
        comps.minute = m
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        center.add(UNNotificationRequest(identifier: reminderId, content: content, trigger: trigger))
    }

    static func cancelDailyReminder() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [reminderId])
    }

    /// Re-apply scheduling from persisted settings. Call on launch and whenever
    /// the reminder toggle/time changes.
    static func refreshFromSettings() async {
        let d = UserDefaults.standard
        let enabled = d.bool(forKey: Keys.enabled)
        let status = await authorizationStatus()
        let authorized = (status == .authorized || status == .provisional)
        guard ReminderPlan.shouldSchedule(enabled: enabled, authorized: authorized) else {
            cancelDailyReminder()
            return
        }
        let hour   = d.object(forKey: Keys.hour)   as? Int ?? defaultHour
        let minute = d.object(forKey: Keys.minute) as? Int ?? defaultMinute
        scheduleDailyReminder(hour: hour, minute: minute)
    }
}
