import Foundation

@MainActor
final class SettingsSync {

    static let shared = SettingsSync()

    static let keys = [
        BibleVersion.storageKey,
        NewCardCap.amountKey,
        NewCardCap.unitKey,
        NewCardCap.dailyReviewCapKey,
        StudyMode.storageKey,
        SRSQueueBuilder.NewCardPolicy.reviewsKnownKey,
        CardAppearance.storageKey,
        "hardMode",
        "userVerse.lastTranslation.v1",
    ]

    private let cloud: NSUbiquitousKeyValueStore
    private let local: UserDefaults
    private var applying = false

    init(cloud: NSUbiquitousKeyValueStore = .default, local: UserDefaults = .standard) {
        self.cloud = cloud
        self.local = local
    }

    func start() {
        for key in Self.keys {
            if let value = cloud.object(forKey: key) {
                apply(value, forKey: key)
            } else if let value = local.object(forKey: key) {
                cloud.set(value, forKey: key)
            }
        }
        NotificationCenter.default.addObserver(self, selector: #selector(localChanged),
                                               name: UserDefaults.didChangeNotification, object: local)
        NotificationCenter.default.addObserver(self, selector: #selector(cloudChanged(_:)),
                                               name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
                                               object: cloud)
    }

    private func apply(_ value: Any, forKey key: String) {
        guard !Self.same(local.object(forKey: key), value) else { return }
        applying = true
        local.set(value, forKey: key)
        applying = false
    }

    @objc private func localChanged() {
        guard !applying else { return }
        var pushed = false
        for key in Self.keys {
            let value = local.object(forKey: key)
            guard !Self.same(cloud.object(forKey: key), value) else { continue }
            cloud.set(value, forKey: key)
            pushed = true
        }
        if pushed { cloud.synchronize() }
    }

    @objc private func cloudChanged(_ note: Notification) {
        let changed = note.userInfo?[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String] ?? Self.keys
        Task { @MainActor in
            for key in changed where Self.keys.contains(key) {
                if let value = cloud.object(forKey: key) { apply(value, forKey: key) }
            }
        }
    }

    private static func same(_ a: Any?, _ b: Any?) -> Bool {
        switch (a, b) {
        case (nil, nil): return true
        case let (a as NSObject, b as NSObject): return a.isEqual(b)
        default: return false
        }
    }
}
