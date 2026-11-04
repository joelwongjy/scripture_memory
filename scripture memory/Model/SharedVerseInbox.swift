import Foundation

struct SharedVerseDraft: Codable, Equatable {
    var packID: String?
    var newPackName: String?
    var title: String
    var text: String
    var book: String
    var reference: String
    var version: String?
}

struct SharedPackChoice: Codable, Equatable, Identifiable {
    var id: String
    var name: String
}

enum SharedVerseInbox {

    static let appGroup = "group.joel.scripture-memory"
    private static let draftsKey = "share.inbox.v1"
    private static let packsKey = "share.packs.v1"
    private static let lastPackKey = "share.lastPack.v1"
    private static let lastTranslationKey = "share.lastTranslation.v1"

    private static var defaults: UserDefaults? { UserDefaults(suiteName: appGroup) }

    static var packs: [SharedPackChoice] {
        guard let data = defaults?.data(forKey: packsKey) else { return [] }
        return (try? JSONDecoder().decode([SharedPackChoice].self, from: data)) ?? []
    }

    static func setPacks(_ packs: [SharedPackChoice]) {
        guard packs != self.packs, let data = try? JSONEncoder().encode(packs) else { return }
        defaults?.set(data, forKey: packsKey)
    }

    static var lastPackID: String? {
        get { defaults?.string(forKey: lastPackKey) }
        set { defaults?.set(newValue, forKey: lastPackKey) }
    }

    static var lastTranslation: String? {
        get { defaults?.string(forKey: lastTranslationKey) }
        set { defaults?.set(newValue, forKey: lastTranslationKey) }
    }

    static var drafts: [SharedVerseDraft] {
        guard let data = defaults?.data(forKey: draftsKey) else { return [] }
        return (try? JSONDecoder().decode([SharedVerseDraft].self, from: data)) ?? []
    }

    static func append(_ draft: SharedVerseDraft) {
        guard let data = try? JSONEncoder().encode(drafts + [draft]) else { return }
        defaults?.set(data, forKey: draftsKey)
    }

    static func takeAll() -> [SharedVerseDraft] {
        let pending = drafts
        if !pending.isEmpty { defaults?.removeObject(forKey: draftsKey) }
        return pending
    }
}
