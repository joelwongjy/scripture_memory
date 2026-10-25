import Foundation

/// Whether each pack opens as the pouch or straight into its list, learnt from
/// what you did last: spread a pack out into the list and it opens as a list
/// next time; gather it back into the pouch and it opens as the pouch again.
/// Packs you've never switched open as the pouch. Kept on this device only.
enum PackViewPreference {
    private static let key = "packOpensAsList.v1"

    static func opensAsList(_ packName: String, defaults: UserDefaults = .standard) -> Bool {
        (defaults.dictionary(forKey: key) as? [String: Bool])?[packName] ?? false
    }

    static func set(opensAsList: Bool, for packName: String, defaults: UserDefaults = .standard) {
        var all = defaults.dictionary(forKey: key) as? [String: Bool] ?? [:]
        all[packName] = opensAsList
        defaults.set(all, forKey: key)
    }
}
