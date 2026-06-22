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

    /// `srsKey`s of verses the user has marked learnt.
    @Published private(set) var learntKeys: Set<String>

    private let defaults = UserDefaults.standard
    private static let storageKey = "learning.learntKeys.v1"

    private init() {
        learntKeys = Set(defaults.stringArray(forKey: Self.storageKey) ?? [])
    }

    func isLearnt(_ verse: Verse) -> Bool { learntKeys.contains(verse.srsKey) }

    /// The current learning verse + its index in `ordered` — the first not-yet-learnt
    /// verse. Returns nil when every visible verse has been learnt.
    func current(in ordered: [Verse]) -> (verse: Verse, index: Int)? {
        guard let i = ordered.firstIndex(where: { !learntKeys.contains($0.srsKey) }) else { return nil }
        return (ordered[i], i)
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
