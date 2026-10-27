import SwiftUI

struct PackListView: View {
    @AppStorage(BibleVersion.storageKey) private var bibleVersion: BibleVersion = .niv84
    @ObservedObject private var packPrefs = PackPreferencesStore.shared
    @ObservedObject private var learning  = LearningStore.shared
    @ObservedObject private var favorites = FavoritesStore.shared

    @State private var opened:        OpenedPack?       = nil
    @State private var searchText:    String            = ""
    @State private var showOrganizer: Bool              = false
    @State private var tileFrames                       = TileFrames()

    /// Where each tile sits on screen.
    private final class TileFrames { var byPack: [String: CGRect] = [:] }

    /// The pack open full screen, from its tile or from a search result.
    private struct OpenedPack: Identifiable {
        let pack: Pack
        var index = 0
        /// Its tile's frame, to fly out of and back into.
        var origin: CGRect?
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
                    let results = VerseSearch.results(for: searchText, in: visiblePacks)
                    VerseSearchResultsList(
                        query:   searchText,
                        results: results,
                        onSelect: { result in
                            VerseSearch.logOpened(result, in: results)
                            opened = OpenedPack(pack: result.pack, index: result.verseIndex)
                        }
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
        .analyticsScreen(.packs)
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
        .modifier(VerseSearchField(text: $searchText))
        // See `HomeView` — index built off the interaction path.
        .task { VerseSearch.prewarm(visiblePacks) }
        .fullScreenCover(item: $opened) { item in
            PouchView(pack: item.pack, startIndex: item.index, shelf: item.origin,
                      onPutBack: { withoutPresentationAnimation { opened = nil } })
                .presentationBackground(item.origin == nil ? AnyShapeStyle(Color(.systemGroupedBackground))
                                                            : AnyShapeStyle(Color.clear))
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
            let index = PackPositions.startIndex(for: pack, currentKey: learning.currentKey)
            Analytics.log(.packOpened(pack: pack.name, from: .shelf))
            guard !AppMotion.reduceMotion,
                  let origin = tileFrames.byPack[pack.id] else {
                opened = OpenedPack(pack: pack, index: index)
                return
            }
            withoutPresentationAnimation {
                opened = OpenedPack(pack: pack, index: index, origin: origin)
            }
        } label: {
            PackCover(pack: pack, isCurrentPack: pack.name == currentPackName)
        }
        .buttonStyle(CardButtonStyle())
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { tileFrames.byPack[pack.id] = $0 }
        .opacity(opened?.origin != nil && opened?.pack.id == pack.id ? 0 : 1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(pack.name), \(pack.verses.count) cards")
        .accessibilityAddTraits(.isButton)
    }
}

/// Presents or dismisses a full-screen cover without the system's slide, for a
/// cover that animates its own way in and out.
private func withoutPresentationAnimation(_ body: () -> Void) {
    var t = Transaction()
    t.disablesAnimations = true
    withTransaction(t, body)
}

#Preview {
    NavigationStack { PackListView() }
}

/// Search lives in its own tab from iOS 18; before that, it's pinned under the
/// Packs title.
private struct VerseSearchField: ViewModifier {
    @Binding var text: String

    func body(content: Content) -> some View {
        if #available(iOS 18, *) {
            content
        } else {
            content.searchable(text: $text, placement: .navigationBarDrawer(displayMode: .always),
                               prompt: "Search verses")
        }
    }
}
