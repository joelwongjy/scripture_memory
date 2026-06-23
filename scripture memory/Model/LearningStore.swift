import Foundation
import Combine

/// Tracks which verses the user has **learnt**, and derives the linear "current
/// learning verse" from that — the first verse, in pack order, that hasn't been
/// marked learnt yet. Crossing pack boundaries falls out naturally.
///
/// A verse only becomes learnt via an explicit **Mark as Learnt** action (after
/// the user has tested themselves) — never by merely scrolling/navigating to it.
@MainActor
final class LearningStore: ObservableObject {

    static let shared = LearningStore()

    /// `srsKey`s of verses the user has marked learnt. Mutating it invalidates the
    /// cached current-verse key so badges/shortcuts recompute on the next read.
    @Published private(set) var learntKeys: Set<String> {
        didSet { cachedCurrent = nil }
    }

    /// Memoized current verse, tagged with the cheap input token it was computed
    /// for — recomputing `visibleOrdered` (a 480-verse flatMap) on every card
    /// frame would stutter swipes, so we only rebuild when an input actually moves.
    private var cachedCurrent: (token: Int, verse: Verse?)?

    /// `srsKey` of a verse the user pinned to feature on Home + the widget,
    /// overriding the live "current learning verse". Non-destructive: pinning
    /// never touches `learntKeys`, so clearing it returns to the cursor.
    @Published private(set) var pinnedKey: String?

    private let defaults = UserDefaults.standard
    private static let storageKey    = "learning.learntKeys.v1"
    private static let pinStorageKey = "learning.pinnedKey.v1"

    private init() {
        learntKeys = Set(defaults.stringArray(forKey: Self.storageKey) ?? [])
        pinnedKey  = defaults.string(forKey: Self.pinStorageKey)
    }

    func isLearnt(_ verse: Verse) -> Bool { learntKeys.contains(verse.srsKey) }

    /// The current learning verse + its index in `ordered` — the first not-yet-learnt
    /// verse. Returns nil when every visible verse has been learnt.
    func current(in ordered: [Verse]) -> (verse: Verse, index: Int)? {
        guard let i = ordered.firstIndex(where: { !learntKeys.contains($0.srsKey) }) else { return nil }
        return (ordered[i], i)
    }

    // MARK: - Current verse, resolved globally

    /// The visible verse sequence — the same flattening Home uses — rebuilt from
    /// the model layer (pack order/visibility + Bible version) so *any* screen can
    /// ask "is this the current verse?" without the dashboard plumbing it through.
    var visibleOrdered: [Verse] {
        let version = BibleVersion(rawValue: defaults.string(forKey: "bibleVersion") ?? "") ?? .niv84
        return PackPreferencesStore.shared.visible(from: version.packs).flatMap(\.verses)
    }

    /// Cheap fingerprint of everything `visibleOrdered` depends on except
    /// `learntKeys` (which invalidates via its `didSet`): Bible version + pack
    /// order/visibility. Hashing ~12 pack names is far cheaper than rebuilding the
    /// verse list, so this gates the cache without the heavy recompute.
    private var currentInputToken: Int {
        var h = Hasher()
        h.combine(defaults.string(forKey: "bibleVersion") ?? "")
        h.combine(PackPreferencesStore.shared.order)
        h.combine(PackPreferencesStore.shared.hidden)
        return h.finalize()
    }

    /// The current stopped verse (the learning cursor, ignoring any pin), or `nil`
    /// once every visible verse is learnt. Memoized (see `cachedCurrent`) so the
    /// per-card `isCurrent` checks during a swipe stay cheap.
    var currentVerse: Verse? {
        let token = currentInputToken
        if let c = cachedCurrent, c.token == token { return c.verse }
        let v = current(in: visibleOrdered)?.verse
        cachedCurrent = (token, v)
        return v
    }

    /// `srsKey` of the current stopped verse — drives the cross-surface checks.
    var currentKey: String? { currentVerse?.srsKey }

    /// Is `verse` the current stopped verse (the learning cursor)? Drives the
    /// "Current" badge and the Mark-as-Learnt button across every study surface.
    func isCurrent(_ verse: Verse) -> Bool {
        guard !verse.srsKey.isEmpty, let key = currentKey else { return false }
        return key == verse.srsKey
    }

    // MARK: - Pinned verse (Home + widget spotlight)

    /// The verse to feature on Home and in the widget: the pinned one if it's
    /// still visible, otherwise the current learning verse. `isPinned` lets the
    /// UI (and widget) label the two states differently.
    func displayed(in ordered: [Verse]) -> (verse: Verse, isPinned: Bool)? {
        if let key = pinnedKey, let v = ordered.first(where: { $0.srsKey == key }) {
            return (v, true)
        }
        return current(in: ordered).map { ($0.verse, false) }
    }

    func isPinned(_ verse: Verse) -> Bool { pinnedKey != nil && pinnedKey == verse.srsKey }

    /// Pin `verse` to Home/widget. Does not change learning progress.
    func pin(_ verse: Verse) {
        guard !verse.srsKey.isEmpty else { return }
        pinnedKey = verse.srsKey
        defaults.set(verse.srsKey, forKey: Self.pinStorageKey)
    }

    /// Clear the pin — Home/widget return to the current learning verse.
    func unpin() {
        guard pinnedKey != nil else { return }
        pinnedKey = nil
        defaults.removeObject(forKey: Self.pinStorageKey)
    }

    /// How many of `ordered` are learnt (for progress display).
    func learntCount(in ordered: [Verse]) -> Int {
        ordered.reduce(0) { $0 + (learntKeys.contains($1.srsKey) ? 1 : 0) }
    }

    /// Mark a single verse learnt.
    func markLearnt(_ verse: Verse) {
        guard !verse.srsKey.isEmpty, !learntKeys.contains(verse.srsKey) else { return }
        learntKeys.insert(verse.srsKey)
        persist()
    }

    /// Mark `verse` and everything before it (in `ordered`) as learnt — lets a
    /// returning user who already knows the earlier packs set their starting point.
    func markLearntUpTo(_ verse: Verse, in ordered: [Verse]) {
        guard let i = ordered.firstIndex(where: { $0.srsKey == verse.srsKey }) else { return }
        var changed = false
        for v in ordered[...i] where !learntKeys.contains(v.srsKey) {
            learntKeys.insert(v.srsKey); changed = true
        }
        if changed { persist() }
    }

    /// Set the starting point: everything before `verse` (in `ordered`) becomes
    /// learnt, and `verse` onward is un-learnt — so the cursor lands on `verse`.
    /// Used by the onboarding / Settings "starting point" picker.
    func setProgress(startingAt verse: Verse, in ordered: [Verse]) {
        guard let i = ordered.firstIndex(where: { $0.srsKey == verse.srsKey }) else { return }
        learntKeys = Set(ordered[..<i].map(\.srsKey))
        persist()
    }

    /// Un-mark a verse (e.g. an accidental tap).
    func unlearn(_ verse: Verse) {
        guard learntKeys.contains(verse.srsKey) else { return }
        learntKeys.remove(verse.srsKey)
        persist()
    }

    func resetProgress() {
        guard !learntKeys.isEmpty else { return }
        learntKeys = []
        persist()
    }

    private func persist() {
        defaults.set(Array(learntKeys), forKey: Self.storageKey)
    }
}
