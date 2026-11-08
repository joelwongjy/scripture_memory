import Foundation

struct OwnPackDocument: Codable, Equatable {
    var savedAt: Date
    var packs: [UserPack]
    var states: [String: SRSCardState]
    var removedPackIDs: Set<String>

    static let empty = OwnPackDocument(savedAt: .distantPast, packs: [], states: [:], removedPackIDs: [])

    static func merge(_ a: OwnPackDocument, _ b: OwnPackDocument) -> OwnPackDocument {
        let (older, newer) = a.savedAt <= b.savedAt ? (a, b) : (b, a)
        let removed = older.removedPackIDs.union(newer.removedPackIDs)
        var packs = newer.packs.filter { !removed.contains($0.id) }
        let kept = Set(packs.map(\.id))
        for pack in older.packs where !kept.contains(pack.id) && !removed.contains(pack.id) {
            packs.append(pack)
        }
        var states = older.states
        for (key, state) in newer.states {
            if let other = states[key], (other.lastReviewed ?? .distantPast) > (state.lastReviewed ?? .distantPast) {
                continue
            }
            states[key] = state
        }
        return OwnPackDocument(savedAt: newer.savedAt, packs: packs, states: states, removedPackIDs: removed)
    }

    func sameContent(as other: OwnPackDocument) -> Bool {
        packs == other.packs && states == other.states && removedPackIDs == other.removedPackIDs
    }
}

@MainActor
final class OwnPackFile {

    static let shared = OwnPackFile()
    static let didChange = Notification.Name("scripture.ownPackFile.didChange")
    static let containerIdentifier = "iCloud.joel.scripture-memory"
    private static let filename = "ownPacks.json"
    private static let syncedKey = "ownPackFile.hasSynced.v1"

    private(set) var document: OwnPackDocument?
    private let localURL: URL?
    private var cloudURL: URL?
    private var query: NSMetadataQuery?
    private let writer = DispatchQueue(label: "scripture.ownPackFile.writer", qos: .utility)

    private init() {
        localURL = try? FileManager.default
            .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent(Self.filename)
        document = localURL.flatMap(Self.read)
        DispatchQueue.global(qos: .utility).async {
            let url = FileManager.default.url(forUbiquityContainerIdentifier: Self.containerIdentifier)?
                .appendingPathComponent(Self.filename)
            Task { @MainActor in self.connect(url) }
        }
    }

    var ownKeys: Set<String> {
        Set((document?.packs ?? []).flatMap { $0.verses.map(\.id) })
    }

    func adopt(_ legacy: OwnPackDocument) {
        save(OwnPackDocument.merge(document ?? .empty, legacy))
    }

    func savePacks(_ packs: [UserPack]) {
        var next = document ?? .empty
        let gone = Set(next.packs.map(\.id)).subtracting(packs.map(\.id))
        next.removedPackIDs.formUnion(gone)
        next.packs = packs
        save(next)
    }

    func saveStates(_ states: [String: SRSCardState]) {
        var next = document ?? .empty
        guard next.states != states else { return }
        next.states = states
        save(next)
    }

    private func save(_ next: OwnPackDocument) {
        if let document, document.sameContent(as: next) { return }
        var stamped = next
        stamped.savedAt = Date()
        document = stamped
        if let localURL { write(stamped, to: localURL, coordinated: false) }
        if let cloudURL { write(stamped, to: cloudURL, coordinated: true) }
    }

    // MARK: - iCloud

    private func connect(_ url: URL?) {
        guard let url else { return }
        cloudURL = url
        let query = NSMetadataQuery()
        query.searchScopes = [NSMetadataQueryUbiquitousDataScope]
        query.predicate = NSPredicate(format: "%K == %@", NSMetadataItemFSNameKey, Self.filename)
        NotificationCenter.default.addObserver(self, selector: #selector(queryUpdated),
                                               name: .NSMetadataQueryDidFinishGathering, object: query)
        NotificationCenter.default.addObserver(self, selector: #selector(queryUpdated),
                                               name: .NSMetadataQueryDidUpdate, object: query)
        self.query = query
        query.start()
    }

    @objc private func queryUpdated() {
        guard let query, let cloudURL else { return }
        query.disableUpdates()
        defer { query.enableUpdates() }
        guard query.results.first is NSMetadataItem else {
            reconcile(with: nil, rewrite: false)
            return
        }
        let item = query.results.first as! NSMetadataItem
        let status = item.value(forAttribute: NSMetadataUbiquitousItemDownloadingStatusKey) as? String
        guard status == NSMetadataUbiquitousItemDownloadingStatusCurrent else {
            try? FileManager.default.startDownloadingUbiquitousItem(at: cloudURL)
            return
        }
        writer.async {
            let (remote, hadConflicts) = Self.coordinatedRead(cloudURL)
            Task { @MainActor in self.reconcile(with: remote, rewrite: hadConflicts) }
        }
    }

    private func reconcile(with remote: OwnPackDocument?, rewrite: Bool) {
        guard let cloudURL else { return }
        guard let remote else {
            if let document, !document.packs.isEmpty || !document.states.isEmpty {
                write(document, to: cloudURL, coordinated: true)
            }
            return
        }
        let local = document ?? .empty
        let merged: OwnPackDocument
        if UserDefaults.standard.bool(forKey: Self.syncedKey), !rewrite {
            merged = remote.savedAt > local.savedAt ? remote : local
        } else {
            merged = OwnPackDocument.merge(local, remote)
            UserDefaults.standard.set(true, forKey: Self.syncedKey)
        }
        if document.map({ !$0.sameContent(as: merged) }) ?? true {
            document = merged
            if let localURL { write(merged, to: localURL, coordinated: false) }
            NotificationCenter.default.post(name: Self.didChange, object: self)
        }
        if rewrite || !remote.sameContent(as: merged) {
            write(merged, to: cloudURL, coordinated: true)
        }
    }

    // MARK: - Files

    private func write(_ document: OwnPackDocument, to url: URL, coordinated: Bool) {
        guard let data = try? JSONEncoder().encode(document) else { return }
        writer.async {
            guard coordinated else {
                try? data.write(to: url, options: .atomic)
                return
            }
            var error: NSError?
            NSFileCoordinator(filePresenter: nil).coordinate(writingItemAt: url, options: .forReplacing, error: &error) { target in
                try? data.write(to: target, options: .atomic)
            }
        }
    }

    nonisolated private static func read(_ url: URL) -> OwnPackDocument? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(OwnPackDocument.self, from: data)
    }

    nonisolated private static func coordinatedRead(_ url: URL) -> (OwnPackDocument?, Bool) {
        var result: OwnPackDocument?
        var error: NSError?
        NSFileCoordinator(filePresenter: nil).coordinate(readingItemAt: url, options: [], error: &error) { target in
            result = read(target)
        }
        let conflicts = NSFileVersion.unresolvedConflictVersionsOfItem(at: url) ?? []
        guard !conflicts.isEmpty else { return (result, false) }
        for version in conflicts {
            if let other = read(version.url) {
                result = OwnPackDocument.merge(result ?? .empty, other)
            }
            version.isResolved = true
        }
        try? NSFileVersion.removeOtherVersionsOfItem(at: url)
        return (result, true)
    }
}
