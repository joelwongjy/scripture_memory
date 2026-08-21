import Foundation

/// The one place progress is written to and read from.
///
/// Every value goes to **both** iCloud's key-value store and a local
/// `UserDefaults` mirror. Reads prefer iCloud and fall back to the mirror, so
/// the very first launch after a reinstall — before iCloud has hydrated — and a
/// device with no iCloud account at all both still work. Once iCloud does
/// deliver (the `didChangeExternallyNotification`), stores reload through
/// `ProgressStorage.didChangeExternally` and the in-memory copy follows it.
///
/// **Conflict policy:** last-writer-wins per key, which is what a single user
/// moving between their own devices expects. Stores that hold a set of facts
/// (studied days) union instead — see `StreakStore`.
///
/// **Limits:** iCloud KV allows 1 MB total and 1024 keys. The SRS map for the
/// whole catalogue is well under 100 KB; nothing else comes close.
///
/// **Entitlement:** `com.apple.developer.ubiquity-kvstore-identifier` in
/// `scripture_memory.entitlements` — Xcode's "iCloud → Key-value storage".
@MainActor
final class ProgressStorage {

    static let shared = ProgressStorage()

    /// Posted on the main actor after iCloud reports an external change.
    /// `userInfo[ProgressStorage.changedKeysUserInfoKey]` holds the `[String]`
    /// of affected keys when iCloud supplied them; absent means "assume all".
    static let didChangeExternally = Notification.Name("scripture.progressStorage.didChangeExternally")
    static let changedKeysUserInfoKey = "keys"

    private let cloud: NSUbiquitousKeyValueStore
    private let local: UserDefaults

    init(cloud: NSUbiquitousKeyValueStore = .default, local: UserDefaults = .standard) {
        self.cloud = cloud
        self.local = local
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(cloudDidChange(_:)),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: cloud
        )
        // Ask for the initial download right away; the answer arrives via the
        // notification above and the stores reload from it.
        cloud.synchronize()
    }

    // MARK: - Reads (iCloud first, mirror second)

    func data(forKey key: String) -> Data? {
        read(key, cloud.data(forKey:), local.data(forKey:))
    }

    func string(forKey key: String) -> String? {
        read(key, cloud.string(forKey:), local.string(forKey:))
    }

    func stringArray(forKey key: String) -> [String]? {
        read(key, { self.cloud.array(forKey: $0) as? [String] }, local.stringArray(forKey:))
    }

    /// iCloud's copy if it has one; otherwise the mirror's — which is also
    /// **backfilled** into iCloud. That's how progress saved by earlier builds
    /// (local-only) reaches iCloud without waiting for the user to change
    /// something first. If the initial iCloud sync later brings a server value,
    /// it replaces this and the stores reload — server wins, as intended.
    private func read<T>(_ key: String, _ fromCloud: (String) -> T?, _ fromLocal: (String) -> T?) -> T? {
        if let v = fromCloud(key) { return v }
        guard let v = fromLocal(key) else { return nil }
        cloud.set(v, forKey: key)
        return v
    }

    /// Decode a JSON-encoded value stored under `key`.
    func decode<T: Decodable>(_ type: T.Type, forKey key: String) -> T? {
        guard let data = data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    // MARK: - Writes (both, always)

    func set(_ value: Data?, forKey key: String) {
        write(value, forKey: key)
    }

    func set(_ value: String?, forKey key: String) {
        write(value, forKey: key)
    }

    func set(_ value: [String]?, forKey key: String) {
        write(value, forKey: key)
    }

    /// JSON-encode `value` under `key`. A failed encode leaves the stored value alone.
    func encode<T: Encodable>(_ value: T, forKey key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        write(data, forKey: key)
    }

    func removeObject(forKey key: String) {
        write(nil, forKey: key)
    }

    /// Push pending writes to iCloud. Called automatically after each write; the
    /// explicit form exists for callers batching several keys.
    func synchronize() { cloud.synchronize() }

    private func write(_ value: Any?, forKey key: String) {
        if let value {
            cloud.set(value, forKey: key)
            local.set(value, forKey: key)
        } else {
            cloud.removeObject(forKey: key)
            local.removeObject(forKey: key)
        }
        cloud.synchronize()
    }

    // MARK: - External changes

    @objc private func cloudDidChange(_ note: Notification) {
        let keys = note.userInfo?[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String]
        Task { @MainActor in
            var info: [AnyHashable: Any] = [:]
            if let keys { info[Self.changedKeysUserInfoKey] = keys }
            NotificationCenter.default.post(name: Self.didChangeExternally, object: self, userInfo: info)
        }
    }
}

extension Notification {
    /// Whether an external-change notification from `ProgressStorage` touches
    /// any of `keys`. No key list from iCloud means "could be anything" → true.
    func affectsAny(of keys: [String]) -> Bool {
        guard let changed = userInfo?[ProgressStorage.changedKeysUserInfoKey] as? [String] else { return true }
        return !Set(changed).isDisjoint(with: keys)
    }
}
