import Foundation

struct Pack: Hashable, Codable, Identifiable {
    var id: String { name }
    let name:       String
    let color:      String
    let accentText: String
    let verses:     [Verse]
    var userPackID: String? = nil

    var isUserMade: Bool { userPackID != nil }
}

struct Verse: Hashable, Codable, Identifiable {
    let id:        Int
    let title:     String
    let verse:     String
    let book:      String
    let reference: String
    let subpack:   String

    /// Translation this card is pinned to, when it differs from the edition the
    /// rest of the pack uses. A handful of DEP cards are printed in KJV whatever
    /// NIV edition surrounds them, and memorising the NIV wording for those would
    /// mean reciting something the printed card doesn't say. `nil` — the common
    /// case — means "whatever edition this file is".
    let version: String?

    /// Permanent, opaque card identity — the same value in every edition, and
    /// the thing all user progress is filed under.
    ///
    /// Deliberately not derived from anything on screen. The old key was
    /// `pack + book + reference`, which meant editorial tidying silently
    /// destroyed data: renaming a pack, or writing `Psalms` where it used to say
    /// `Psalm`, orphaned every bit of progress attached to it. Now that the
    /// catalog is editable from a web console that failure mode was one careless
    /// rename away.
    ///
    /// Optional only for verses built outside the catalog (previews, tests);
    /// those fall back to the legacy key via `srsKey`.
    let cardUid: String?

    var part: String = ""

    /// Owning pack's name. Not in the JSON (it's implied by nesting) — filled in
    /// by `VerseCatalog` after decode.
    var packName: String = ""

    private enum CodingKeys: String, CodingKey {
        case id, title, verse, book, reference, subpack, part, version, cardUid
    }

    /// The pinned translation, normalised — `nil` unless this card really does
    /// override the file's edition, so callers can branch on presence alone.
    var pinnedVersion: String? {
        guard let v = version?.trimmingCharacters(in: .whitespaces), !v.isEmpty else { return nil }
        return v.uppercased()
    }

    /// The title split into individual words.
    var titleWords: [String] { title.wordTokens }

    /// The verse body split into individual words.
    var verseWords: [String] { verse.wordTokens }

    /// What every store files this verse's progress under: learnt, pinned,
    /// starred, SRS scheduling.
    ///
    /// The `cardUid` when the verse came from the catalog, the legacy composite
    /// otherwise. The fallback covers verses constructed in previews and tests,
    /// never real cards — `IdentityMigration` has already rewritten anything
    /// stored under the old form by the time this is read.
    var srsKey: String { cardUid ?? legacyKey }

    /// The pre-`cardUid` identity: pack + canonical book + normalized reference.
    /// Kept solely so the one-time migration can look up what's on disk.
    var legacyKey: String {
        SRSKey.make(packName: packName, book: book, reference: reference)
    }

    var isPrintedDEP: Bool { packName.hasPrefix("DEP ") }
}

extension Verse {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(id: try c.decode(Int.self, forKey: .id),
                  title: try c.decode(String.self, forKey: .title),
                  verse: try c.decode(String.self, forKey: .verse),
                  book: try c.decode(String.self, forKey: .book),
                  reference: try c.decode(String.self, forKey: .reference),
                  subpack: try c.decode(String.self, forKey: .subpack),
                  version: try c.decodeIfPresent(String.self, forKey: .version),
                  cardUid: try c.decodeIfPresent(String.self, forKey: .cardUid),
                  part: try c.decodeIfPresent(String.self, forKey: .part) ?? "")
    }
}
