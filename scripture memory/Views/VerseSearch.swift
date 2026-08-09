import SwiftUI

// MARK: - Result

/// A verse matched by a search, carrying enough context to open it in place:
/// which pack it lives in and its index there.
struct VerseSearchResult: Identifiable {
    var id: String { "\(pack.name)-\(verse.id)" }
    let verse:      Verse
    let pack:       Pack
    let verseIndex: Int
}

// MARK: - Matching

@MainActor
enum VerseSearch {

    /// Cap on rows returned. A short query like "the" matches most of the library,
    /// and this runs on every keystroke — without a ceiling the whole collection is
    /// walked and rendered for a result nobody scrolls to.
    static let resultLimit = 25

    /// One verse, pre-lowercased for matching.
    ///
    /// Lowercasing is why search felt like it had a debounce on it: the old
    /// matcher lowercased three fields of all ~490 verses on *every keystroke*,
    /// inside `body`, on the main thread — roughly 1,500 fresh strings per
    /// character typed, with the keystroke's frame waiting on all of it. Doing it
    /// once per catalogue instead leaves the per-keystroke cost at a substring
    /// scan over strings that already exist.
    private struct Entry {
        let reference: String     // "john 3:16"
        let title:     String
        let body:      String
        let packIndex: Int
        let verseIndex: Int
    }

    /// The built index, tagged with the pack set it was built from. Rebuilt only
    /// when the catalogue itself changes (translation switch, pack reorder or
    /// hide) — not when the query does.
    private static var cached: (token: Int, entries: [Entry])?

    /// Case-insensitive substring match over reference, title and verse body.
    ///
    /// Reference and title matches come first, then body matches, each group in
    /// pack order. Searching "john 3:16" should lead with John 3:16 itself, not
    /// with whichever verse happens to say "John" earliest in the library.
    static func results(for query: String, in packs: [Pack]) -> [VerseSearchResult] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return [] }

        let entries = index(for: packs)
        var primary:   [VerseSearchResult] = []
        var secondary: [VerseSearchResult] = []

        for entry in entries {
            let onReference = entry.reference.contains(q) || entry.title.contains(q)
            if onReference {
                primary.append(result(entry, in: packs))
                if primary.count == resultLimit { return primary }
            } else if secondary.count < resultLimit, entry.body.contains(q) {
                secondary.append(result(entry, in: packs))
            }
        }
        return Array((primary + secondary).prefix(resultLimit))
    }

    /// Drop the built index. Call when verse *content* changes under a pack set
    /// that still fingerprints the same — a remote catalog refresh, say, which can
    /// rewrite verse text without changing any pack's name or size.
    static func invalidate() { cached = nil }

    private static func result(_ entry: Entry, in packs: [Pack]) -> VerseSearchResult {
        let pack = packs[entry.packIndex]
        return VerseSearchResult(verse: pack.verses[entry.verseIndex],
                                 pack: pack, verseIndex: entry.verseIndex)
    }

    private static func index(for packs: [Pack]) -> [Entry] {
        let token = fingerprint(packs)
        if let cached, cached.token == token { return cached.entries }

        var entries: [Entry] = []
        entries.reserveCapacity(packs.reduce(0) { $0 + $1.verses.count })
        for (packIndex, pack) in packs.enumerated() {
            for (verseIndex, verse) in pack.verses.enumerated() {
                entries.append(Entry(
                    reference: "\(verse.book) \(verse.reference)".lowercased(),
                    title:     verse.title.lowercased(),
                    body:      verse.verse.lowercased(),
                    packIndex: packIndex,
                    verseIndex: verseIndex))
            }
        }
        cached = (token, entries)
        return entries
    }

    /// Cheap stand-in for "is this the same catalogue?" — pack names and sizes.
    /// Hashing ~15 short strings beats rebuilding ~490 lowercased entries, and the
    /// two things that change the pack set in practice (translation, pack
    /// order/visibility) both move it.
    private static func fingerprint(_ packs: [Pack]) -> Int {
        var hasher = Hasher()
        for pack in packs {
            hasher.combine(pack.name)
            hasher.combine(pack.verses.count)
        }
        return hasher.finalize()
    }
}

// MARK: - Results List

/// The verse-search results rows, shared by Home and Packs so both searches look
/// and behave identically.
///
/// Deliberately *not* wrapped in its own `ScrollView`: each screen owns a single
/// scroll view whose content swaps between the screen's normal body and these
/// rows. Two scroll views alternating under one `.searchable` left the navigation
/// bar attached to whichever had been there first, which is what made a screen
/// open already scrolled past its own title.
struct VerseSearchResultsList: View {
    let query:    String
    let results:  [VerseSearchResult]
    let onSelect: (VerseSearchResult) -> Void

    @ObservedObject private var favorites = FavoritesStore.shared

    var body: some View {
        LazyVStack(spacing: 0) {
            if results.isEmpty {
                ContentUnavailableView {
                    Label("No Results", systemImage: "magnifyingglass")
                } description: {
                    Text("No verses match \u{201C}\(query)\u{201D}.")
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 48)
            } else {
                ForEach(results) { result in
                    VStack(spacing: 0) {
                        Button { onSelect(result) } label: { row(result) }
                            .buttonStyle(.plain)
                        Divider().padding(.leading, 16)
                    }
                }
            }
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: AppLayout.cardRadius, style: .continuous))
        .padding(.horizontal, AppLayout.screenMargin)
        .padding(.top, 8)
    }

    private func row(_ result: VerseSearchResult) -> some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text("\(result.verse.book) \(result.verse.reference)")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.primary)
                    if let pinned = result.verse.pinnedVersion {
                        Text("(\(pinned))")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.secondary)
                    }
                }
                Text(result.verse.title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.primary)
                Text(result.verse.verse)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .multilineTextAlignment(.leading)
                Text(VerseNumbering.code(for: result.verse) ?? result.pack.name)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            if favorites.isFavorite(result.verse) {
                Image(systemName: "star.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.yellow)
                    .accessibilityLabel("Favourite")
            }
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, AppLayout.screenMargin)
        .padding(.vertical, 11)
        .contentShape(Rectangle())
    }
}
