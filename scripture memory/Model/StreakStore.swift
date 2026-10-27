import Foundation
import Combine

/// Tracks daily study activity and derives the user's current streak.
///
/// A day counts once the user opens the app that day.
/// Persisted through `ProgressStorage` (a set of `yyyy-MM-dd` day keys). Days
/// are facts, so an external copy is **unioned** in rather than replacing ours —
/// a day studied on either device stays studied.
@MainActor
final class StreakStore: ObservableObject {

    static let shared = StreakStore()

    @Published private(set) var days: Set<String> = []

    /// Set to the new streak length when today's first visit reaches a
    /// milestone; the celebration overlay shows it and clears it.
    @Published var celebration: Int?

    private let storage: ProgressStorage
    private static let storageKey = "streak.days.v1"

    private init(storage: ProgressStorage = .shared) {
        self.storage = storage
        days = Set(storage.stringArray(forKey: Self.storageKey) ?? [])
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(externalChange(_:)),
            name: ProgressStorage.didChangeExternally,
            object: nil
        )
    }

    @objc private func externalChange(_ note: Notification) {
        guard note.affectsAny(of: [Self.storageKey]) else { return }
        let incoming = Set(storage.stringArray(forKey: Self.storageKey) ?? [])
        let merged = days.union(incoming)
        guard merged != days else { return }
        days = merged
        if merged != incoming { persist() }   // our side had days iCloud lacked
    }

    /// Mark today as done. Idempotent; the first call of the day raises the
    /// celebration when the streak lands on a milestone.
    func recordToday(_ now: Date = Date()) {
        let key = Self.dayKey(now)
        guard !days.contains(key) else { return }
        days.insert(key)
        if Self.milestones.contains(current) { celebration = current }
        // Keep ~400 days so the set can't grow unbounded.
        if days.count > 400 {
            days = Set(days.sorted().suffix(400))
        }
        persist()
    }

    private func persist() {
        storage.set(Array(days), forKey: Self.storageKey)
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

    /// Whether today has been practised yet. While it hasn't, a running streak
    /// is "at risk": still alive, but it ends at midnight.
    var isTodayDone: Bool { days.contains(Self.dayKey(Date())) }

    /// Days practised, in all (within the kept window of about 400 days).
    var totalDays: Int { days.count }

    /// The longest run of consecutive practised days on record.
    var longest: Int {
        let cal = Calendar.current
        let dates = days.compactMap(Self.date(fromKey:)).sorted()
        var best = 0, run = 0
        var previous: Date?
        for d in dates {
            if let p = previous, cal.dateComponents([.day], from: p, to: d).day == 1 { run += 1 } else { run = 1 }
            best = max(best, run)
            previous = d
        }
        return best
    }

    /// Whether the given calendar day was practised.
    func isDone(_ date: Date) -> Bool { days.contains(Self.dayKey(date)) }

    static let milestones = [3, 7, 14, 30, 50, 100, 200, 365, 500, 1000]

    /// The next streak milestone above `count`, Duolingo-style.
    static func milestone(after count: Int) -> Int {
        milestones.first { $0 > count } ?? (count / 100 + 1) * 100
    }

    var nextMilestone: Int { Self.milestone(after: current) }

    private static func date(fromKey key: String) -> Date? {
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return Calendar.current.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }

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
            day = cal.date(byAdding: .day, value: 1, to: day) ?? day.addingTimeInterval(SRSStore.secondsPerDay)
        }
        return out
    }

    /// The `yyyy-MM-dd` key a date is filed under. One definition, shared with
    /// `SRSStore`, so streak days and SRS days can never disagree.
    static func dayKey(_ date: Date) -> String { SRSStore.dayKey(date) }
}
