import Foundation
import Combine
import os
import UIKit

@MainActor
final class UserPackStore: ObservableObject {

    static let shared = UserPackStore()

    @Published private(set) var userPacks: [UserPack] = []

    private let storage: ProgressStorage
    private static let storageKey = "userPacks.v2"
    private static let legacyKey = "userPacks.v1"

    private struct Snapshot {
        var packs: [Pack] = []
        var revision = 0
    }

    private static let snapshot = OSAllocatedUnfairLock(initialState: Snapshot())

    nonisolated static var packs: [Pack] { snapshot.withLock { $0.packs } }

    nonisolated static var revision: Int { snapshot.withLock { $0.revision } }

    private init(storage: ProgressStorage = .shared) {
        self.storage = storage
        load()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(externalChange(_:)),
            name: ProgressStorage.didChangeExternally,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(becameActive(_:)),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        ingestShared()
    }

    @objc private func becameActive(_ note: Notification) {
        ingestShared()
    }

    @discardableResult
    func ingestShared() -> Int {
        let drafts = SharedVerseInbox.takeAll()
        guard !drafts.isEmpty else { return 0 }
        var packs = userPacks
        for draft in drafts {
            let verse = UserVerse(id: UserVerse.newID(), title: draft.title, text: draft.text,
                                  book: draft.book, reference: draft.reference, version: draft.version)
            if let id = draft.packID, let i = packs.firstIndex(where: { $0.id == id }) {
                packs[i].verses.append(verse)
            } else {
                let name = draft.newPackName ?? UserPack.defaultName
                if let i = packs.firstIndex(where: { $0.name == name }) {
                    packs[i].verses.append(verse)
                } else {
                    packs.append(UserPack(id: UserVerse.newID(), name: availableName(name),
                                          color: UserPack.colors[0], verses: [verse]))
                }
            }
        }
        commit(packs)
        return drafts.count
    }

    @objc private func externalChange(_ note: Notification) {
        guard note.affectsAny(of: [Self.storageKey, Self.legacyKey]) else { return }
        load()
    }

    private func load() {
        let current = storage.decodeCompressed([UserPack].self, forKey: Self.storageKey)
        let legacy = current == nil ? storage.decode([UserPack].self, forKey: Self.legacyKey) : nil
        let decoded = current ?? legacy ?? []
        if let legacy {
            storage.encodeCompressed(legacy, forKey: Self.storageKey)
            storage.removeObject(forKey: Self.legacyKey)
        }
        guard decoded != userPacks || Self.revision == 0 else { return }
        publish(decoded)
    }

    private func publish(_ packs: [UserPack]) {
        userPacks = packs
        SharedVerseInbox.setPacks(packs.map { SharedPackChoice(id: $0.id, name: $0.name) })
        let built = packs.map(\.pack)
        Self.snapshot.withLock {
            $0.packs = built
            $0.revision += 1
        }
    }

    private func commit(_ packs: [UserPack]) {
        publish(packs)
        storage.encodeCompressed(packs, forKey: Self.storageKey)
    }

    func pack(id: String) -> UserPack? { userPacks.first { $0.id == id } }

    // MARK: - Packs

    private var reservedNames: Set<String> {
        Set(packsNIV84.map(\.name) + packsNIV11.map(\.name) + [FavoritesStore.packName])
    }

    func availableName(_ proposed: String, excluding id: String? = nil) -> String {
        let base = proposed.trimmingCharacters(in: .whitespacesAndNewlines)
        let root = base.isEmpty ? UserPack.defaultName : base
        let taken = reservedNames.union(userPacks.filter { $0.id != id }.map(\.name))
            .map { $0.lowercased() }
        guard taken.contains(root.lowercased()) else { return root }
        var n = 2
        while taken.contains("\(root) \(n)".lowercased()) { n += 1 }
        return "\(root) \(n)"
    }

    @discardableResult
    func createPack(name: String, color: String, verses: [UserVerse] = []) -> UserPack {
        let pack = UserPack(id: UserVerse.newID(), name: availableName(name), color: color, verses: verses)
        commit(userPacks + [pack])
        return pack
    }

    func updatePack(id: String, name: String, color: String) {
        guard let i = userPacks.firstIndex(where: { $0.id == id }) else { return }
        var packs = userPacks
        let oldName = packs[i].name
        let newName = availableName(name, excluding: id)
        packs[i].name = newName
        packs[i].color = color
        commit(packs)
        if oldName != newName {
            PackPreferencesStore.shared.renamePack(from: oldName, to: newName)
            SRSStore.shared.renamePack(from: oldName, to: newName)
            PackPositions.renamePack(from: oldName, to: newName)
        }
    }

    func deletePack(id: String) {
        commit(userPacks.filter { $0.id != id })
    }

    // MARK: - Verses

    func addVerse(_ verse: UserVerse, to packID: String) {
        mutate(packID) { $0.verses.append(verse) }
    }

    func updateVerse(_ verse: UserVerse, in packID: String) {
        mutate(packID) { pack in
            guard let i = pack.verses.firstIndex(where: { $0.id == verse.id }) else { return }
            pack.verses[i] = verse
        }
    }

    func deleteVerses(_ ids: Set<String>, in packID: String) {
        mutate(packID) { $0.verses.removeAll { ids.contains($0.id) } }
    }

    func moveVerses(in packID: String, from source: IndexSet, to destination: Int) {
        mutate(packID) { pack in
            let moving = source.sorted().map { pack.verses[$0] }
            for i in source.sorted(by: >) { pack.verses.remove(at: i) }
            let before = source.filter { $0 < destination }.count
            pack.verses.insert(contentsOf: moving, at: min(max(destination - before, 0), pack.verses.count))
        }
    }

    private func mutate(_ packID: String, _ change: (inout UserPack) -> Void) {
        guard let i = userPacks.firstIndex(where: { $0.id == packID }) else { return }
        var packs = userPacks
        change(&packs[i])
        commit(packs)
    }
}
