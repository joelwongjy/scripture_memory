import Foundation

/// Moves saved progress from the old content-derived card key to `cardUid`.
///
/// Everything the user has earned — which verses they've learnt, which one is
/// pinned, which are starred, and every SRS card's schedule — was filed under
/// `pack name + book + reference`. This rewrites all of it, once, to the
/// permanent id. See `Verse.cardUid` for why.
///
/// Runs before any store reads its defaults (see `ScriptureMemoryApp.init`),
/// because those stores load once and cache; migrating underneath a loaded
/// store would leave the in-memory copy on the old keys and persist them back.
///
/// Safe to call on every launch: it records completion and returns immediately
/// afterwards, and it only ever rewrites keys it can find a mapping for.
enum IdentityMigration {

    private static let completionKey = "identity.cardUidMigration.v1"

    static func runIfNeeded(defaults: UserDefaults = .standard,
                            cloud: NSUbiquitousKeyValueStore = .default) {
        guard !defaults.bool(forKey: completionKey) else { return }

        let map = legacyToUid()
        // No mapping means the catalog failed to load. Do nothing and stay
        // un-migrated rather than writing a half-translated store — this runs
        // again next launch.
        guard !map.isEmpty else { return }

        migrateStringArray("learning.learntKeys.v1", map: map, defaults: defaults, cloud: cloud)
        migrateStringArray("favorites.verseKeys.v1", map: map, defaults: defaults, cloud: cloud)
        migrateString("learning.pinnedKey.v1", map: map, defaults: defaults, cloud: cloud)
        migrateCardStates(map: map, defaults: defaults, cloud: cloud)
        cloud.synchronize()

        defaults.set(true, forKey: completionKey)
    }

    /// Old key → new id, for every card in either edition.
    ///
    /// Three passages are printed on two different cards in the same pack (Acts
    /// 17:11 in DEP 3, 1 Timothy 2:1-2 in DEP 4, Romans 10:9-10 in DEP 6). The
    /// old key couldn't tell those apart, so on disk there is only one entry for
    /// each pair and no way to know which card it meant. First occurrence wins;
    /// the twin starts fresh. That's the honest outcome — the two were being
    /// treated as one card, and one of them has to be the one that keeps the
    /// history.
    private static func legacyToUid() -> [String: String] {
        var map: [String: String] = [:]
        for packs in [packsNIV84, packsNIV11] {
            for pack in packs {
                for verse in pack.verses {
                    guard let uid = verse.cardUid else { continue }
                    let legacy = verse.legacyKey
                    if map[legacy] == nil { map[legacy] = uid }
                }
            }
        }
        return map
    }

    /// These live in both stores (see `ProgressStorage`); each copy is rewritten
    /// where it's found so neither side can re-introduce old keys.
    private static func migrateStringArray(_ key: String, map: [String: String],
                                           defaults: UserDefaults,
                                           cloud: NSUbiquitousKeyValueStore) {
        // Anything unmapped is kept as-is rather than dropped: it may belong to a
        // pack that's temporarily missing from the catalog, and silently deleting
        // someone's progress is far worse than carrying a stale key.
        if let stored = defaults.stringArray(forKey: key), !stored.isEmpty {
            defaults.set(Array(Set(stored.map { map[$0] ?? $0 })), forKey: key)
        }
        if let stored = cloud.array(forKey: key) as? [String], !stored.isEmpty {
            cloud.set(Array(Set(stored.map { map[$0] ?? $0 })), forKey: key)
        }
    }

    private static func migrateString(_ key: String, map: [String: String],
                                      defaults: UserDefaults,
                                      cloud: NSUbiquitousKeyValueStore) {
        if let stored = defaults.string(forKey: key), let uid = map[stored] {
            defaults.set(uid, forKey: key)
        }
        if let stored = cloud.string(forKey: key), let uid = map[stored] {
            cloud.set(uid, forKey: key)
        }
    }

    /// SRS schedules, which live in iCloud as well as locally.
    ///
    /// The key appears twice — as the dictionary key and inside each record —
    /// and both have to move together or `SRSStore` will disagree with itself.
    private static func migrateCardStates(map: [String: String],
                                          defaults: UserDefaults,
                                          cloud: NSUbiquitousKeyValueStore) {
        let key = "srs.cardStates.v1"
        let raw = cloud.data(forKey: key) ?? defaults.data(forKey: key)
        guard let raw,
              let states = try? JSONDecoder().decode([String: SRSCardState].self, from: raw)
        else { return }

        var migrated: [String: SRSCardState] = [:]
        migrated.reserveCapacity(states.count)
        for (legacy, state) in states {
            let uid = map[legacy] ?? legacy
            var moved = state
            moved.key = uid
            // Two legacy keys can't collide on one uid, but a partially-migrated
            // store could already hold the target — keep whichever is further
            // along rather than overwriting a real schedule with a fresh one.
            if let existing = migrated[uid], existing.reps >= moved.reps { continue }
            migrated[uid] = moved
        }

        guard let encoded = try? JSONEncoder().encode(migrated) else { return }
        defaults.set(encoded, forKey: key)
        cloud.set(encoded, forKey: key)
        cloud.synchronize()
    }
}
