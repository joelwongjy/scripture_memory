import SwiftUI

/// The Search tab: every visible verse, searched with the system field. On
/// iOS 26 the tab bar turns into that field at the bottom of the screen.
struct VerseSearchView: View {
    @AppStorage(BibleVersion.storageKey) private var bibleVersion: BibleVersion = .niv84
    @ObservedObject private var packPrefs = PackPreferencesStore.shared

    @State private var searchText = ""
    @State private var opened: OpenedVerse?

    private struct OpenedVerse: Identifiable {
        let pack: Pack
        let index: Int
        var id: String { "\(pack.id)-\(index)" }
    }

    private var visiblePacks: [Pack] { packPrefs.visible(from: bibleVersion.packs) }

    var body: some View {
        ScrollView {
            if searchText.isEmpty {
                ContentUnavailableView {
                    Label("Search Verses", systemImage: "magnifyingglass")
                } description: {
                    Text("Find a verse by its words, reference or title.")
                }
                .padding(.top, 48)
            } else {
                VerseSearchResultsList(
                    query: searchText,
                    results: VerseSearch.results(for: searchText, in: visiblePacks),
                    onSelect: { opened = OpenedVerse(pack: $0.pack, index: $0.verseIndex) }
                )
            }
        }
        .scrollDismissesKeyboard(.immediately)
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Search")
        .searchable(text: $searchText, prompt: "Search verses")
        .task { VerseSearch.prewarm(visiblePacks) }
        .fullScreenCover(item: $opened) { item in
            PouchView(pack: item.pack, startIndex: item.index)
                .presentationBackground(Color(.systemGroupedBackground))
        }
    }
}
