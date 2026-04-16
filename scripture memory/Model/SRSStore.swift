import Foundation
import Combine

/// Persists per-card SRS state and the "new cards introduced today" counter.
///
/// **Storage:** primary backing is `NSUbiquitousKeyValueStore` (iCloud KV). A local
/// `UserDefaults` mirror is also written so the very first launch — before iCloud
/// has hydrated — still has data, and subsequent launches work offline.
///
/// **Conflict policy:** last-writer-wins via the `didChangeExternallyNotification`.
/// Acceptable for a single-user app across the user's own devices.
///
/// **Required entitlement:** `com.apple.developer.ubiquity-kvstore-identifier`
/// = `$(TeamIdentifierPrefix)$(CFBundleIdentifier)` — enabled via Xcode's
/// "iCloud → Key-value storage" capability.
@MainActor
final class SRSStore: ObservableObject {

    static let shared = SRSStore()

    /// Card state map, keyed by `Verse.srsKey`.
    @Published private(set) var states: [String: SRSCardState] = [:]

    /// Per-day, per-pack count of new cards introduced (so we don't exceed the cap).
    /// Outer key is `yyyy-MM-dd` (device-local). Inner key is pack name.
    @Published private(set) var dailyNewByDate: [String: [String: Int]] = [:]

    /// Packs the user has opted into for daily review. Off by default —
    /// the user explicitly turns on the packs they're memorizing.
    @Published private(set) var activePackNames: Set<String> = []

    private let kvStore = NSUbiquitousKeyValueStore.default
    private let local   = UserDefaults.standard

    private static let statesKey      = "srs.cardStates.v1"
    private static let dailyNewKey    = "srs.dailyNewByDate.v1"
    private static let activePacksKey = "srs.activePackNames.v1"

    private init() {
        load()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(externalChange(_:)),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: kvStore
        )
        kvStore.synchronize()
    }

    // MARK: - Public Queries

    func state(for key: String) -> SRSCardState? { states[key] }

    func state(for verse: Verse) -> SRSCardState? { states[verse.srsKey] }

    /// Cards that are due NOW (or earlier) in the given pack.
    func dueCards(in packName: String, allVerses: [Verse], now: Date = Date()) -> [Verse] {
        allVerses.filter { v in
            guard let s = states[v.srsKey] else { return false }
            return s.due <= now
        }
    }

    /// Cards in the pack with no SRS state yet.
    func newCandidateCards(in packName: String, allVerses: [Verse]) -> [Verse] {
        allVerses.filter { states[$0.srsKey] == nil }
    }

    /// New cards already introduced today for the given pack.
    func newIntroducedToday(in packName: String, now: Date = Date()) -> Int {
        dailyNewByDate[Self.dayKey(now)]?[packName] ?? 0
    }

    /// Total new cards introduced today across ALL packs.
    /// This is what the `dailyNewCap` setting gates against.
    func newIntroducedToday(now: Date = Date()) -> Int {
        dailyNewByDate[Self.dayKey(now)]?.values.reduce(0, +) ?? 0
    }

    /// Earliest upcoming due date across the supplied verses (or nil if none scheduled).
    func nextDue(in verses: [Verse], now: Date = Date()) -> Date? {
        verses
            .compactMap { states[$0.srsKey]?.due }
            .filter { $0 > now }
            .min()
    }

    // MARK: - Active Packs

    func isActive(_ packName: String) -> Bool {
        activePackNames.contains(packName)
    }

    func setActive(_ packName: String, _ active: Bool) {
        if active { activePackNames.insert(packName) }
        else      { activePackNames.remove(packName) }
        persist()
    }

    // MARK: - Mutation

    /// Grades a card. Creates initial state if none exists.
    /// Bumps the daily-new counter the FIRST time a brand-new card is graded.
    @discardableResult
    func grade(verse: Verse, grade: SRSGrade, now: Date = Date()) -> SRSCardState {
        let key = verse.srsKey
        let isFirstGrade = (states[key] == nil)
        let prior = states[key] ?? SRSCardState.newCard(key: key, now: now)
        let next = updateSRS(state: prior, grade: grade, now: now)
        states[key] = next

        if isFirstGrade && !verse.packName.isEmpty {
            bumpDailyNew(packName: verse.packName, now: now)
        }
        persist()
        return next
    }

    /// Re-grade a card from a KNOWN pre-grade state. Used when the user swipes
    /// back to a card already graded this session and picks a different grade —
    /// the new schedule is computed from the original state, not the
    /// already-advanced one (so re-grading doesn't compound).
    /// Daily-new counter is NOT bumped (the bump happened on the first grade).
    @discardableResult
    func regrade(verse: Verse, grade: SRSGrade, from priorState: SRSCardState, now: Date = Date()) -> SRSCardState {
        let next = updateSRS(state: priorState, grade: grade, now: now)
        states[verse.srsKey] = next
        persist()
        return next
    }

    /// Wipe all SRS state. `ReviewProgress.completedIds` is intentionally untouched.
    /// Active-pack opt-ins are preserved — they're a UI preference, not progress.
    func resetAll() {
        states = [:]
        dailyNewByDate = [:]
        persist()
    }

    func resetPack(_ packName: String) {
        let prefix = "\(packName)#"
        states = states.filter { !$0.key.hasPrefix(prefix) }
        for date in dailyNewByDate.keys {
            dailyNewByDate[date]?.removeValue(forKey: packName)
        }
        persist()
    }

    // MARK: - Daily Counter

    private func bumpDailyNew(packName: String, now: Date) {
        let day = Self.dayKey(now)
        var perPack = dailyNewByDate[day] ?? [:]
        perPack[packName, default: 0] += 1
        dailyNewByDate[day] = perPack
    }

    /// Trim daily-new counts older than 14 days so the dictionary doesn't grow unbounded.
    private func pruneDailyNew(now: Date = Date()) {
        let cutoff = Calendar.current.date(byAdding: .day, value: -14, to: now) ?? now
        let cutoffKey = Self.dayKey(cutoff)
        dailyNewByDate = dailyNewByDate.filter { $0.key >= cutoffKey }
    }

    static func dayKey(_ date: Date) -> String {
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d",
                      comps.year ?? 0, comps.month ?? 0, comps.day ?? 0)
    }

    // MARK: - Persistence

    private func persist() {
        pruneDailyNew()
        if let data = try? JSONEncoder().encode(states) {
            kvStore.set(data, forKey: Self.statesKey)
            local.set(data, forKey: Self.statesKey)
        }
        if let data = try? JSONEncoder().encode(dailyNewByDate) {
            kvStore.set(data, forKey: Self.dailyNewKey)
            local.set(data, forKey: Self.dailyNewKey)
        }
        if let data = try? JSONEncoder().encode(Array(activePackNames)) {
            kvStore.set(data, forKey: Self.activePacksKey)
            local.set(data, forKey: Self.activePacksKey)
        }
        kvStore.synchronize()
    }

    private func load() {
        // Prefer iCloud — fall back to local cache when iCloud hasn't hydrated yet.
        if let data = kvStore.data(forKey: Self.statesKey) ?? local.data(forKey: Self.statesKey),
           let decoded = try? JSONDecoder().decode([String: SRSCardState].self, from: data) {
            states = decoded
        }
        if let data = kvStore.data(forKey: Self.dailyNewKey) ?? local.data(forKey: Self.dailyNewKey),
           let decoded = try? JSONDecoder().decode([String: [String: Int]].self, from: data) {
            dailyNewByDate = decoded
        }
        if let data = kvStore.data(forKey: Self.activePacksKey) ?? local.data(forKey: Self.activePacksKey),
           let decoded = try? JSONDecoder().decode([String].self, from: data) {
            activePackNames = Set(decoded)
        }
    }

    @objc private func externalChange(_ note: Notification) {
        // Last-writer-wins. Reload everything from iCloud.
        Task { @MainActor in self.load() }
    }
}
