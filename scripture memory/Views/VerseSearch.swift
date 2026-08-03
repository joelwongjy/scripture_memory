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

enum VerseSearch {

    /// Cap on rows returned. A short query like "the" matches most of the library,
    /// and this runs on every keystroke — without a ceiling the whole collection is
    /// walked and rendered for a result nobody scrolls to.
    static let resultLimit = 25

    /// Case-insensitive substring match over reference, title and verse body,
    /// scanned in pack order so results stay in the same sequence the user browses.
    static func results(for query: String, in packs: [Pack]) -> [VerseSearchResult] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return [] }

        var results: [VerseSearchResult] = []
        for pack in packs {
            for (index, verse) in pack.verses.enumerated() {
                let ref = "\(verse.book) \(verse.reference)".lowercased()
                if ref.contains(q)
                    || verse.title.lowercased().contains(q)
                    || verse.verse.lowercased().contains(q) {
                    results.append(VerseSearchResult(verse: verse, pack: pack, verseIndex: index))
                    if results.count == resultLimit { return results }
                }
            }
        }
        return results
    }
}

// MARK: - Results List

/// The verse-search results list, shared by Home and Packs so both searches look
/// and behave identically.
struct VerseSearchResultsList: View {
    let query:    String
    let results:  [VerseSearchResult]
    let onSelect: (VerseSearchResult) -> Void

    var body: some View {
        ScrollView {
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
    }

    private func row(_ result: VerseSearchResult) -> some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text("\(result.verse.book) \(result.verse.reference)")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary)
                Text(result.verse.title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.primary)
                Text(result.verse.verse)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .multilineTextAlignment(.leading)
                Text(result.pack.name)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, AppLayout.screenMargin)
        .padding(.vertical, 11)
        .contentShape(Rectangle())
    }
}
