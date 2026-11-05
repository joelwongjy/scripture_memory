import SwiftUI

struct PackListView: View {
    @AppStorage(BibleVersion.storageKey) private var bibleVersion: BibleVersion = .niv84
    @ObservedObject private var packPrefs = PackPreferencesStore.shared
    @ObservedObject private var learning  = LearningStore.shared
    @ObservedObject private var favorites = FavoritesStore.shared
    @ObservedObject private var userPacks = UserPackStore.shared
    @State private var knownPackIDs: [String] = UserPackStore.shared.userPacks.map(\.id)

    @State private var opened:        OpenedPack?       = nil
    @State private var searchText:    String            = ""
    @State private var showOrganizer: Bool              = false
    @State private var tileFrames                       = TileFrames()
    @State private var editing:       EditedPack?       = nil
    @State private var importing:     Bool              = false
    @State private var createdPackID: String?           = nil

    private struct EditedPack: Identifiable {
        let packID: String?
        var addsVerse = false
        var id: String { packID ?? "new" }
    }

    /// Where each tile sits on screen.
    private final class TileFrames { var byPack: [String: CGRect] = [:] }

    /// The pack open full screen, from its tile or from a search result.
    private struct OpenedPack: Identifiable {
        let pack: Pack
        var index = 0
        /// Its tile's frame, to fly out of and back into.
        var origin: CGRect?
        var fromSearch = false
        var id: String { "\(pack.id)-\(index)" }
    }

    /// Visible packs in the user's custom order (hidden removed).
    private var visiblePacks: [Pack] { packPrefs.visible(from: bibleVersion.packs) }

    /// Name of the pack holding the current stopped verse — badged in the grid so
    /// the user can spot where to resume at a glance.
    private var currentPackName: String? { learning.currentVerse?.packName }

    /// Two columns on a phone; more on a wide window.
    private let columns = [GridItem(.adaptive(minimum: 160), spacing: AppLayout.spacing)]

    // MARK: - Body

    var body: some View {
        // One scroll view for the whole screen, with the grid and the search
        // results swapping *inside* it. Two alternating scroll views left
        // `.searchable` bound to whichever mounted first, so the screen opened
        // already scrolled past its own large title.
        MountAfterFirstFrame {
            ScrollViewReader { scroller in
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
                            opened = OpenedPack(pack: result.pack, index: result.verseIndex, fromSearch: true)
                        }
                    )
                }
            }
            .onChange(of: createdPackID) { _, id in
                guard let id else { return }
                withAnimation(.smooth(duration: 0.24)) { scroller.scrollTo(id, anchor: .center) }
                createdPackID = nil
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
                Button("Edit") { showOrganizer = true }
                    .accessibilityLabel("Edit packs")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        editing = EditedPack(packID: nil)
                    } label: {
                        Label("New Pack", systemImage: "rectangle.stack.badge.plus")
                    }
                    Button {
                        importing = true
                    } label: {
                        Label("Import from Anki", systemImage: "square.and.arrow.down")
                    }
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Add Pack")
            }
        }
        .sheet(item: $editing, onDismiss: revealNewPack) { item in
            PackEditorView(packID: item.packID, addsVerseOnOpen: item.addsVerse)
        }
        .sheet(isPresented: $importing, onDismiss: revealNewPack) {
            AnkiImportView()
        }
        .sheet(isPresented: $showOrganizer) {
            PackOrganizerView(allPacks: bibleVersion.packs)
        }
        .modifier(VerseSearchField(text: $searchText))
        // See `HomeView` — index built off the interaction path.
        .task { VerseSearch.prewarm(visiblePacks) }
        .fullScreenCover(item: $opened) { item in
            PouchView(pack: item.pack, startIndex: item.index,
                      shelf: item.origin.map { origin in { tileFrames.byPack[item.pack.id] ?? origin } },
                      animatesPouch: !item.fromSearch,
                      onPutBack: { withoutPresentationAnimation { opened = nil } })
                .presentationBackground(item.origin == nil ? AnyShapeStyle(Color(.systemGroupedBackground))
                                                            : AnyShapeStyle(Color.clear))
        }
    }

    /// The pack grid, with the favourites collection leading it when the user has
    /// starred anything. It's presented as a pack rather than a separate screen so
    /// everything a pack can do — read, review, shuffle — works on it unchanged.
    private var packGrid: some View {
        let packs = visiblePacks
        let split = packs.firstIndex(where: \.isUserMade)
            .flatMap { i in packs[i...].allSatisfy(\.isUserMade) ? i : nil }
        return LazyVGrid(columns: columns, spacing: AppLayout.spacing) {
            if let favorites = favorites.pack(in: packs) {
                packTile(favorites)
            }
            ForEach(packs[..<(split ?? packs.count)]) { pack in
                packTile(pack)
            }
            if let split {
                Section {
                    ForEach(packs[split...]) { pack in
                        packTile(pack)
                    }
                } header: {
                    Text("Your Packs")
                        .font(.title3.weight(.semibold))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, AppLayout.spacing)
                        .accessibilityAddTraits(.isHeader)
                }
            }
        }
        .padding(.horizontal, AppLayout.screenMargin)
        .padding(.vertical, 12)
    }

    private func revealNewPack() {
        let known = Set(knownPackIDs)
        knownPackIDs = userPacks.userPacks.map(\.id)
        guard let new = userPacks.userPacks.last(where: { !known.contains($0.id) }) else { return }
        createdPackID = new.name
    }

    private func packTile(_ pack: Pack) -> some View {
        Button {
            guard !pack.verses.isEmpty else {
                if let id = pack.userPackID { editing = EditedPack(packID: id, addsVerse: true) }
                return
            }
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
        .id(pack.id)
        .contextMenu {
            if let id = pack.userPackID {
                Button {
                    editing = EditedPack(packID: id, addsVerse: true)
                } label: {
                    Label("Add Verse", systemImage: "plus")
                }
                Button {
                    editing = EditedPack(packID: id)
                } label: {
                    Label("Edit Pack", systemImage: "pencil")
                }
            }
        }
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { tileFrames.byPack[pack.id] = $0 }
        .opacity(opened?.origin != nil && opened?.pack.id == pack.id ? 0 : 1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(pack.verses.count == 1 ? "\(pack.name), 1 card" : "\(pack.name), \(pack.verses.count) cards")
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
