import Foundation
import UserNotifications

/// Schedules / cancels the daily review reminder. Pure scheduling decisions and
/// wording live in `ReminderPlan` (testable); this type is the thin
/// UserNotifications adapter.
///
/// Reminders are a rolling window of individual (non-repeating) notifications —
/// one per day for the next `windowDays` — each carrying that day's actual due
/// count. Days with nothing due are skipped. The window is re-armed on launch
/// and when the app backgrounds, so the pre-scheduled counts stay current.
@MainActor
enum NotificationManager {

    static let reminderId = "daily-review-reminder"

    /// Days ahead to pre-schedule, so a lapsed user keeps getting nudged between
    /// app opens (each open re-arms the window).
    static let windowDays = 7

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

    /// Schedule the next `windowDays` daily reminders, each carrying that day's
    /// actual due count (reviews + new). Days with nothing due are skipped.
    static func scheduleReminders(hour: Int, minute: Int) {
        let (h, m) = ReminderPlan.normalizedTime(hour: hour, minute: minute)
        let center = UNUserNotificationCenter.current()
        let cal = Calendar.current

        // Resolve the active packs + new-card cap from saved settings.
        let d = UserDefaults.standard
        let version = BibleVersion(rawValue: d.string(forKey: "bibleVersion") ?? "") ?? .niv84
        let activePacks = PackPreferencesStore.shared.visible(from: version.packs)
            .filter { SRSStore.shared.isActive($0.name) }
        let cap = d.object(forKey: "srs.dailyNewCap") as? Int ?? 1

        clearPending(center)

        let now = Date()
        guard let todayFire = cal.date(bySettingHour: h, minute: m, second: 0, of: now) else { return }
        // Start at the next occurrence: today if the time is still ahead, else tomorrow.
        let firstFire = todayFire > now
            ? todayFire
            : (cal.date(byAdding: .day, value: 1, to: todayFire) ?? todayFire)

        for i in 0..<windowDays {
            guard let fire = cal.date(byAdding: .day, value: i, to: firstFire) else { continue }
            let summary = SRSQueueBuilder.dueSummary(activePacks: activePacks,
                                                     store: SRSStore.shared,
                                                     dailyNewCap: cap, now: fire)
            guard let body = ReminderPlan.reminderBody(review: summary.review, new: summary.new) else { continue }

            let content = UNMutableNotificationContent()
            content.title = "Daily review"
            content.body  = body
            content.sound = .default

            let comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            center.add(UNNotificationRequest(identifier: "\(reminderId)-\(i)",
                                             content: content, trigger: trigger))
        }
    }

    static func cancelDailyReminder() {
        clearPending(UNUserNotificationCenter.current())
    }

    /// Remove everything we may have scheduled — the legacy single id and the
    /// whole rolling window.
    private static func clearPending(_ center: UNUserNotificationCenter) {
        let ids = [reminderId] + (0..<windowDays).map { "\(reminderId)-\($0)" }
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }

    /// Re-apply scheduling from persisted settings. Call on launch, when the
    /// reminder toggle/time changes, and when the app backgrounds (so the
    /// pre-scheduled counts reflect the latest review state).
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
        scheduleReminders(hour: hour, minute: minute)
    }
}
