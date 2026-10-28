import SwiftUI

// MARK: - Results

/// Search results as `List` sections, one per pack, for the Search tab.
struct VerseSearchSections: View {
    let query:    String
    let results:  [VerseSearchResult]
    let onSelect: (VerseSearchResult) -> Void

    var body: some View {
        ForEach(VerseSearchGroup.grouping(results)) { group in
            Section(group.pack.name) {
                ForEach(group.results) { result in
                    Button { onSelect(result) } label: {
                        VerseSearchRow(result: result, query: query)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

/// The same results for a screen that owns a single `ScrollView` and swaps its
/// body for them (Packs, on iOS 17).
///
/// Deliberately *not* wrapped in its own `ScrollView`: two scroll views
/// alternating under one `.searchable` left the navigation bar attached to
/// whichever had been there first, which is what made a screen open already
/// scrolled past its own title.
struct VerseSearchResultsList: View {
    let query:    String
    let results:  [VerseSearchResult]
    let onSelect: (VerseSearchResult) -> Void

    var body: some View {
        LazyVStack(alignment: .leading, spacing: 0) {
            if results.isEmpty {
                VerseSearchNoResults(query: query)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 48)
            } else {
                ForEach(VerseSearchGroup.grouping(results)) { group in
                    Text(group.pack.name)
                        .font(.footnote)
                        .textCase(.uppercase)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, AppLayout.panelPadding)
                        .padding(.top, 22)
                        .padding(.bottom, 7)
                    VStack(spacing: 0) {
                        ForEach(group.results) { result in
                            Button { onSelect(result) } label: {
                                VerseSearchRow(result: result, query: query)
                                    .padding(.horizontal, AppLayout.panelPadding)
                                    .padding(.vertical, 11)
                            }
                            .buttonStyle(.plain)
                            if result.id != group.results.last?.id {
                                Divider().padding(.leading, AppLayout.panelPadding)
                            }
                        }
                    }
                    .background(Color(.secondarySystemGroupedBackground))
                    .roundedRect()
                }
            }
        }
        .padding(.horizontal, AppLayout.screenMargin)
        .padding(.bottom, 16)
        .readableColumn()
    }
}

struct VerseSearchNoResults: View {
    let query: String

    var body: some View {
        ContentUnavailableView {
            Label("No Results", systemImage: "magnifyingglass")
        } description: {
            Text("No verses match \u{201C}\(query)\u{201D}.")
        }
    }
}

private struct VerseSearchRow: View {
    let result: VerseSearchResult
    let query: String

    @ObservedObject private var favorites = FavoritesStore.shared

    var body: some View {
        VerseRowLabel(verse: result.verse, showsPreview: true, highlight: query) {
            if favorites.isFavorite(result.verse) {
                Image(systemName: "star.fill")
                    .font(.footnote)
                    .foregroundStyle(.yellow)
                    .accessibilityLabel("Favourite")
            }
            RowChevron()
        }
    }
}
