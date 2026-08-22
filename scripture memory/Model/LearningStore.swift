import Foundation
import Combine

extension Notification.Name {
    /// Posted when the pinned/featured verse changes, so the app re-syncs the widget
    /// snapshot right away — SwiftUI `onChange` on the pinned key can miss the update
    /// while the pin-picker sheet is presented.
    static let featuredVerseDidChange = Notification.Name("scripture.featuredVerseDidChange")
}

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

    private let storage: ProgressStorage
    private static let storageKey    = "learning.learntKeys.v1"
    private static let pinStorageKey = "learning.pinnedKey.v1"

    private init(storage: ProgressStorage = .shared) {
        self.storage = storage
        learntKeys = Set(storage.stringArray(forKey: Self.storageKey) ?? [])
        pinnedKey  = storage.string(forKey: Self.pinStorageKey)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(externalChange(_:)),
            name: ProgressStorage.didChangeExternally,
            object: nil
        )
    }

    /// iCloud delivered another device's (or this device's pre-reinstall) copy.
    /// Last-writer-wins: take it wholesale.
    @objc private func externalChange(_ note: Notification) {
        if note.affectsAny(of: [Self.storageKey]) {
            let incoming = Set(storage.stringArray(forKey: Self.storageKey) ?? [])
            if incoming != learntKeys { learntKeys = incoming }
        }
        if note.affectsAny(of: [Self.pinStorageKey]) {
            let incoming = storage.string(forKey: Self.pinStorageKey)
            if incoming != pinnedKey {
                pinnedKey = incoming
                NotificationCenter.default.post(name: .featuredVerseDidChange, object: nil)
            }
        }
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
        let version = BibleVersion(rawValue: UserDefaults.standard.string(forKey: "bibleVersion") ?? "") ?? .niv84
        return Catalogue.verses(in: PackPreferencesStore.shared.visible(from: version.packs))
    }

    /// Cheap fingerprint of everything `visibleOrdered` depends on except
    /// `learntKeys` (which invalidates via its `didSet`): Bible version + pack
    /// order/visibility. Hashing ~12 pack names is far cheaper than rebuilding the
    /// verse list, so this gates the cache without the heavy recompute.
    private var currentInputToken: Int {
        var h = Hasher()
        h.combine(UserDefaults.standard.string(forKey: "bibleVersion") ?? "")
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
        storage.set(verse.srsKey, forKey: Self.pinStorageKey)
        NotificationCenter.default.post(name: .featuredVerseDidChange, object: nil)
    }

    /// Clear the pin — Home/widget return to the current learning verse.
    func unpin() {
        guard pinnedKey != nil else { return }
        pinnedKey = nil
        storage.removeObject(forKey: Self.pinStorageKey)
        NotificationCenter.default.post(name: .featuredVerseDidChange, object: nil)
    }

    /// Mark a single verse learnt.
    func markLearnt(_ verse: Verse) {
        guard !verse.srsKey.isEmpty, !learntKeys.contains(verse.srsKey) else { return }
        learntKeys.insert(verse.srsKey)
        persist()
    }

    /// Undo `markLearnt` — used when a review grade that auto-advanced the cursor is
    /// undone, so the cursor returns to this verse.
    func unmarkLearnt(_ verse: Verse) {
        guard learntKeys.remove(verse.srsKey) != nil else { return }
        persist()
    }

    /// Set the starting point: everything before `verse` (in `ordered`) becomes
    /// learnt, and `verse` onward is un-learnt — so the cursor lands on `verse`.
    /// Used by the onboarding / Settings "starting point" picker.
    func setProgress(startingAt verse: Verse, in ordered: [Verse]) {
        guard let i = ordered.firstIndex(where: { $0.srsKey == verse.srsKey }) else { return }
        learntKeys = Set(ordered[..<i].map(\.srsKey))
        persist()
    }

    private func persist() {
        storage.set(Array(learntKeys), forKey: Self.storageKey)
    }
}
