import Foundation

/// Where the app's verses come from.
///
/// The bundled JSON is the floor: it's always present, always complete, and is
/// what a fresh install reads. On top of that sits an optional Supabase-hosted
/// catalog, so a typo or a missing verse can be corrected without shipping a
/// build through review.
///
/// **Updates land on the next launch, not mid-session.** Pack membership and
/// ordering are baked into things computed once and held for the life of the
/// process — printed card numbers (`VerseNumbering`), the search index, an
/// in-flight quiz's verse list, the learning cursor's position in the
/// catalogue. Swapping the catalogue underneath all of that while a session is
/// open would renumber cards mid-quiz for a payoff nobody is waiting on. So the
/// refresh writes to a cache file and stops; the next cold start picks it up.
enum VerseCatalog {

    // MARK: - Reading

    /// Packs for one edition, from the newest catalog available on disk.
    static func packs(edition: String, bundledFile: String) -> [Pack] {
        if let cached = cachedDocument(), let packs = cached.editions[edition], !packs.isEmpty {
            return withPackNames(packs)
        }
        return withPackNames(bundledPacks(bundledFile))
    }

    /// Back-fills `Verse.packName`, which isn't in the JSON (it's implied by
    /// nesting) but is half of every `srsKey`.
    private static func withPackNames(_ packs: [Pack]) -> [Pack] {
        packs.map { pack in
            Pack(name: pack.name, color: pack.color, accentText: pack.accentText,
                 verses: pack.verses.map { verse in
                     var copy = verse
                     copy.packName = pack.name
                     return copy
                 })
        }
    }

    private static func bundledPacks(_ filename: String) -> [Pack] {
        guard let url = Bundle.main.url(forResource: filename, withExtension: nil) else {
            fatalError("Couldn't find \(filename) in main bundle.")
        }
        do {
            return try JSONDecoder().decode([Pack].self, from: Data(contentsOf: url))
        } catch {
            fatalError("Couldn't parse \(filename):\n\(error)")
        }
    }

    // MARK: - Cache

    /// A whole catalog: every edition, plus the version it was published at.
    struct Document: Codable {
        /// Shape of this file, not the content's publication number.
        ///
        /// Bumped whenever the app needs fields an older cache can't have. A
        /// cache written before `cardUid` existed looked perfectly valid and
        /// decoded fine — it just quietly shadowed the bundled JSON with verses
        /// that had no identity, which disabled the migration and left every
        /// card falling back to the old key. Requiring this field means such a
        /// file fails to decode and gets discarded, which is the behaviour we
        /// wanted all along.
        let schema: Int
        let catalogVersion: Int
        let editions: [String: [Pack]]
    }

    /// Raise when a release needs something older caches don't carry.
    static let currentSchema = 2

    private static let cacheFilename = "verseCatalog.json"

    /// In the shared App Group, not the app's private container.
    ///
    /// The widget is a separate process with its own bundle, so it can't read
    /// the app's Application Support — which is why it fell back to its own
    /// copy of the bundled JSON for the verse picker and went stale the moment
    /// a pack changed remotely. Both targets already share this group for the
    /// live snapshot; putting the catalog beside it means one downloaded file
    /// serves both.
    private static var cacheURL: URL? {
        let shared = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: WidgetBridge.appGroup)?
            .appendingPathComponent(cacheFilename)

        // Move a cache written by an earlier build to the new home, so the first
        // launch after updating doesn't throw away a good catalog and fall back
        // to the bundle until the next refresh.
        if let shared, !FileManager.default.fileExists(atPath: shared.path),
           let legacy = legacyCacheURL, FileManager.default.fileExists(atPath: legacy.path) {
            try? FileManager.default.moveItem(at: legacy, to: shared)
        }
        return shared ?? legacyCacheURL
    }

    private static var legacyCacheURL: URL? {
        guard let dir = try? FileManager.default.url(for: .applicationSupportDirectory,
                                                     in: .userDomainMask,
                                                     appropriateFor: nil, create: true)
        else { return nil }
        return dir.appendingPathComponent(cacheFilename)
    }

    /// Parsed once per launch. A corrupt or truncated cache is discarded rather
    /// than crashed on — the bundle is always there to fall back to, and a bad
    /// download must never be able to brick the app.
    private static let cachedDocumentOnce: Document? = {
        guard let url = cacheURL, let data = try? Data(contentsOf: url) else { return nil }
        do {
            let document = try JSONDecoder().decode(Document.self, from: data)
            guard document.schema == currentSchema else {
                try? FileManager.default.removeItem(at: url)
                return nil
            }
            return document
        } catch {
            try? FileManager.default.removeItem(at: url)
            return nil
        }
    }()

    private static func cachedDocument() -> Document? { cachedDocumentOnce }

    /// Version written by a refresh during this session, if any.
    ///
    /// `cachedDocumentOnce` is parsed once per launch and deliberately doesn't
    /// re-read the file — the running session must keep the catalog it started
    /// with. But that makes it the wrong thing to ask "have I already got this?":
    /// after a download it still reports the *old* version, so the next check
    /// would decide it was out of date and fetch the whole catalog again. With
    /// the refresh now also running on every resume, that repeated for the life
    /// of the session.
    private static var downloadedVersion: Int?

    /// Version of the catalog on disk — what the refresh compares against to
    /// decide whether there's anything to download. Distinct from the version
    /// *in use*, which is whatever was read at launch.
    static var installedVersion: Int {
        downloadedVersion ?? cachedDocument()?.catalogVersion ?? 0
    }

    // MARK: - Refresh

    /// Pull a newer catalog if there is one. Safe to call on every launch: it
    /// asks for a single row first, and downloads nothing when already current.
    /// Silent on every failure — an unreachable server means the user keeps the
    /// catalog they already have, which is a complete and working one.
    static func refreshIfNeeded() async {
        guard let client = SupabaseCatalogClient() else { return }
        do {
            // `!=`, not `>`. A version that moves backwards is a real scenario —
            // reseeding a fresh project restarts at 1, as does restoring a
            // backup — and under `>` every client holding a higher number would
            // silently never update again. There's one server, so "different"
            // is the right test for "not what I have".
            guard let remoteVersion = try await client.catalogVersion(),
                  remoteVersion != installedVersion else { return }
            let document = try await client.fetchCatalog(version: remoteVersion)
            // Reject anything that isn't a complete, fully-identified catalog.
            // A verse with no `cardUid` has no identity to file progress under,
            // and caching one would shadow the bundled JSON — which does have
            // them — with a strictly worse copy. Keeping what we have is always
            // the safer failure.
            //
            // A pack with no verses is the tell-tale of a half-written catalog:
            // seeding deletes everything and re-inserts in several statements,
            // each of which publishes, so a refresh landing mid-run can see
            // packs that exist but aren't populated yet. Such a fetch is
            // discarded; the seed's final publish moves the version again, so
            // the next launch picks up the complete one.
            guard !document.editions.isEmpty,
                  document.editions.values.allSatisfy({ packs in
                      !packs.isEmpty && packs.allSatisfy { pack in
                          !pack.verses.isEmpty
                              && pack.verses.allSatisfy { $0.cardUid?.isEmpty == false }
                      }
                  })
            else { return }
            guard let url = cacheURL else { return }
            try JSONEncoder().encode(document).write(to: url, options: .atomic)
            downloadedVersion = remoteVersion
        } catch {
            return
        }
    }
}

// MARK: - Supabase

/// Minimal PostgREST client — two GETs, no dependency.
///
/// Reads its configuration from the app's Info.plist; absent or blank
/// configuration means there is no remote catalog and the initialiser fails, so
/// every remote path in the app becomes a no-op rather than a network error.
struct SupabaseCatalogClient {

    private let baseURL: URL
    private let anonKey: String

    init?() {
        let info = Bundle.main.infoDictionary
        guard let urlString = (info?["SupabaseURL"] as? String)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
              let key = (info?["SupabaseAnonKey"] as? String)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
              !urlString.isEmpty, !key.isEmpty,
              let url = URL(string: urlString)
        else { return nil }
        self.baseURL = url
        self.anonKey = key
    }

    /// The one row of `catalog_meta`. Cheap enough to ask for on every launch.
    func catalogVersion() async throws -> Int? {
        struct Row: Decodable { let version: Int }
        let rows: [Row] = try await get("catalog_meta", query: [
            URLQueryItem(name: "select", value: "version"),
            URLQueryItem(name: "limit", value: "1"),
        ])
        return rows.first?.version
    }

    /// Every pack with its verses, nested by PostgREST's embedded-resource
    /// syntax so the whole catalog arrives in one request.
    func fetchCatalog(version: Int) async throws -> VerseCatalog.Document {
        let rows: [PackRow] = try await get("packs", query: [
            URLQueryItem(name: "select",
                         value: "edition,name,color,accent_text,sort_index,"
                              + "verses(verse_id,card_uid,sort_index,title,verse,book,reference,subpack,version)"),
            URLQueryItem(name: "order", value: "sort_index.asc"),
        ])

        var editions: [String: [Pack]] = [:]
        for row in rows.sorted(by: { $0.sort_index < $1.sort_index }) {
            let verses = row.verses
                .sorted { $0.sort_index < $1.sort_index }
                .map { Verse(id: $0.verse_id, title: $0.title, verse: $0.verse,
                             book: $0.book, reference: $0.reference,
                             subpack: $0.subpack, version: $0.version,
                             cardUid: $0.card_uid) }
            editions[row.edition, default: []].append(
                Pack(name: row.name, color: row.color,
                     accentText: row.accent_text, verses: verses))
        }
        return VerseCatalog.Document(schema: VerseCatalog.currentSchema,
                                     catalogVersion: version, editions: editions)
    }

    // MARK: Transport

    private struct PackRow: Decodable {
        let edition: String
        let name: String
        let color: String
        let accent_text: String
        let sort_index: Int
        let verses: [VerseRow]
    }

    private struct VerseRow: Decodable {
        let verse_id: Int
        let card_uid: String?
        let sort_index: Int
        let title: String
        let verse: String
        let book: String
        let reference: String
        let subpack: String
        let version: String?
    }

    private func get<T: Decodable>(_ table: String, query: [URLQueryItem]) async throws -> T {
        guard var components = URLComponents(
            url: baseURL.appendingPathComponent("rest/v1/\(table)"),
            resolvingAgainstBaseURL: false) else { throw URLError(.badURL) }
        components.queryItems = query
        guard let url = components.url else { throw URLError(.badURL) }

        var request = URLRequest(url: url)
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 20

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(T.self, from: data)
    }
}
