import SwiftUI

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
        VerseRowLabel(verse: result.verse, showsPreview: true) {
            if favorites.isFavorite(result.verse) {
                Image(systemName: "star.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.yellow)
                    .accessibilityLabel("Favourite")
            }
            RowChevron()
        }
        .padding(.horizontal, AppLayout.screenMargin)
        .padding(.vertical, 11)
    }
}
