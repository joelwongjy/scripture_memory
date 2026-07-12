import Foundation
import Combine

/// Tracks daily study activity and derives the user's current streak.
///
/// A "day" counts once the user starts a learning or review session that day.
/// Persisted locally (a set of `yyyy-MM-dd` day keys).
@MainActor
final class StreakStore: ObservableObject {

    static let shared = StreakStore()

    @Published private(set) var days: Set<String> = []

    private let defaults = UserDefaults.standard
    private static let storageKey = "streak.days.v1"

    private init() {
        days = Set(defaults.stringArray(forKey: Self.storageKey) ?? [])
    }

    /// Mark today as active. Idempotent.
    func recordToday(_ now: Date = Date()) {
        let key = Self.dayKey(now)
        guard !days.contains(key) else { return }
        days.insert(key)
        // Keep ~400 days so the set can't grow unbounded.
        if days.count > 400 {
            days = Set(days.sorted().suffix(400))
        }
        defaults.set(Array(days), forKey: Self.storageKey)
    }

    /// Consecutive days ending today (or yesterday, if today isn't done yet — the
    /// streak is still "alive" until the day fully passes).
    var current: Int {
        let cal = Calendar.current
        var day = cal.startOfDay(for: Date())
        if !days.contains(Self.dayKey(day)) {
            guard let yesterday = cal.date(byAdding: .day, value: -1, to: day) else { return 0 }
            day = yesterday
        }
        var streak = 0
        while days.contains(Self.dayKey(day)) {
            streak += 1
            guard let prev = cal.date(byAdding: .day, value: -1, to: day) else { break }
            day = prev
        }
        return streak
    }

    /// Whether today is already recorded (drives the "studied today" affordance).
    var didStudyToday: Bool { days.contains(Self.dayKey(Date())) }

    /// The 7 days of the current calendar week (Duolingo-style row) — single-letter
    /// weekday initial + studied / today / future state.
    func thisWeek() -> [(initial: String, done: Bool, isToday: Bool, isFuture: Bool)] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        guard let week = cal.dateInterval(of: .weekOfYear, for: today) else { return [] }
        let fmt = DateFormatter()
        fmt.locale = Locale.current
        fmt.dateFormat = "EEEEE"   // narrow weekday: S M T W T F S
        var out: [(String, Bool, Bool, Bool)] = []
        var day = week.start
        for _ in 0..<7 {
            let d = cal.startOfDay(for: day)
            out.append((fmt.string(from: d), days.contains(Self.dayKey(d)), d == today, d > today))
            day = cal.date(byAdding: .day, value: 1, to: day) ?? day.addingTimeInterval(86_400)
        }
        return out
    }

    static func dayKey(_ date: Date) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
}
