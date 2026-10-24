import SwiftUI

struct PackListView: View {
    @AppStorage(BibleVersion.storageKey) private var bibleVersion: BibleVersion = .niv84
    @ObservedObject private var packPrefs = PackPreferencesStore.shared
    @ObservedObject private var learning  = LearningStore.shared
    @ObservedObject private var favorites = FavoritesStore.shared

    @State private var opened:        OpenedPack?       = nil
    @State private var searchText:    String            = ""
    @State private var showOrganizer: Bool              = false

    /// What's open full screen: a pack from the grid, or a verse from search.
    /// One cover, since two `.fullScreenCover`s on one view conflict.
    private struct OpenedPack: Identifiable {
        let pack: Pack
        var index = 0
        var id: String { "\(pack.id)-\(index)" }
    }

    /// Visible packs in the user's custom order (hidden removed).
    private var visiblePacks: [Pack] { packPrefs.visible(from: bibleVersion.packs) }

    /// Name of the pack holding the current stopped verse — badged in the grid so
    /// the user can spot where to resume at a glance.
    private var currentPackName: String? { learning.currentVerse?.packName }

    /// Two columns on a phone; more on a wide window (iPhone Duo's inner display).
    private let columns = [GridItem(.adaptive(minimum: 160), spacing: AppLayout.spacing)]

    // MARK: - Body

    var body: some View {
        // One scroll view for the whole screen, with the grid and the search
        // results swapping *inside* it. Two alternating scroll views left
        // `.searchable` bound to whichever mounted first, so the screen opened
        // already scrolled past its own large title.
        MountAfterFirstFrame {
            ScrollView {
                if searchText.isEmpty {
                    packGrid
                } else {
                    VerseSearchResultsList(
                        query:   searchText,
                        results: VerseSearch.results(for: searchText, in: visiblePacks),
                        onSelect: { opened = OpenedPack(pack: $0.pack, index: $0.verseIndex) }
                    )
                }
            }
        }
        // Start at the top, explicitly.
        //
        // A `.navigationBarDrawer(displayMode: .always)` search field is laid out
        // as part of the scroll content, and SwiftUI's initial content offset
        // sometimes lands *below* it — the screen opens with the search bar under
        // the status bar and the large title already scrolled away. Naming the
        // anchor removes the guess; it's inert when the offset was right anyway.
        .defaultScrollAnchor(.top)
        .scrollDismissesKeyboard(.immediately)
        .animation(nil, value: searchText.isEmpty)
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Packs")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showOrganizer = true
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                }
                .accessibilityLabel("Organize packs")
            }
        }
        .sheet(isPresented: $showOrganizer) {
            PackOrganizerView(allPacks: bibleVersion.packs)
        }
        .searchable(
            text: $searchText,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: "Search verses"
        )
        // See `HomeView` — index built off the interaction path.
        .task { VerseSearch.prewarm(visiblePacks) }
        .fullScreenCover(item: $opened) { item in
            CardStudyCover(packName: item.pack.name, verses: item.pack.verses, initialIndex: item.index)
        }
    }

    /// The pack grid, with the favourites collection leading it when the user has
    /// starred anything. It's presented as a pack rather than a separate screen so
    /// everything a pack can do — read, review, shuffle — works on it unchanged.
    private var packGrid: some View {
        LazyVGrid(columns: columns, spacing: AppLayout.spacing) {
            if let favorites = favorites.pack(in: visiblePacks) {
                packTile(favorites)
            }
            ForEach(visiblePacks) { pack in
                packTile(pack)
            }
        }
        .padding(.horizontal, AppLayout.screenMargin)
        .padding(.vertical, 12)
    }

    private func packTile(_ pack: Pack) -> some View {
        Button {
            guard !pack.verses.isEmpty else { return }
            opened = OpenedPack(pack: pack, index: PackPositions.startIndex(for: pack, currentKey: learning.currentKey))
        } label: {
            PackCover(pack: pack, isCurrentPack: pack.name == currentPackName)
        }
        .buttonStyle(CardButtonStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(pack.name), \(pack.verses.count) cards")
        .accessibilityAddTraits(.isButton)
    }
}

#Preview {
    NavigationStack { PackListView() }
}
