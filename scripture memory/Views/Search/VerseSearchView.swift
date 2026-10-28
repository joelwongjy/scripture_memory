import SwiftUI

/// The Search tab: every visible verse, searched with the system field. On
/// iOS 26 the tab bar turns into that field at the bottom of the screen.
struct VerseSearchView: View {
    @AppStorage(BibleVersion.storageKey) private var bibleVersion: BibleVersion = .niv84
    @ObservedObject private var packPrefs = PackPreferencesStore.shared

    let searchText: String
    @State private var opened: OpenedVerse?

    private struct OpenedVerse: Identifiable {
        let pack: Pack
        let index: Int
        var id: String { "\(pack.id)-\(index)" }
    }

    private var visiblePacks: [Pack] { packPrefs.visible(from: bibleVersion.packs) }

    var body: some View {
        let results = VerseSearch.results(for: searchText, in: visiblePacks)
        List {
            VerseSearchSections(query: searchText, results: results) {
                VerseSearch.logOpened($0, in: results)
                opened = OpenedVerse(pack: $0.pack, index: $0.verseIndex)
            }
        }
        .overlay {
            if searchText.isEmpty {
                ContentUnavailableView {
                    Label("Search Verses", systemImage: "magnifyingglass")
                } description: {
                    Text("Find a verse by its words, reference or title.")
                }
            } else if results.isEmpty {
                VerseSearchNoResults(query: searchText)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color(.systemGroupedBackground))
        .scrollDismissesKeyboard(.immediately)
        .navigationTitle("Search")
        .analyticsScreen(.search)
        .task(id: searchText) {
            guard !searchText.isEmpty else { return }
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled, results.isEmpty else { return }
            Analytics.log(.searchFoundNothing)
        }
        .task { VerseSearch.prewarm(visiblePacks) }
        .fullScreenCover(item: $opened) { item in
            PouchView(pack: item.pack, startIndex: item.index, animatesPouch: false)
                .presentationBackground(Color(.systemGroupedBackground))
        }
    }
}
