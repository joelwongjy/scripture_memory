import SwiftUI

/// The Home tab: streak, the verse you're learning, and today's review.
struct HomeView: View {

    @AppStorage(BibleVersion.storageKey)       private var bibleVersion: BibleVersion = .niv84
    @AppStorage(HomeVerseStartMode.storageKey) private var homeVerseStartMode: HomeVerseStartMode = .read

    @ObservedObject private var store     = SRSStore.shared
    @ObservedObject private var packPrefs = PackPreferencesStore.shared
    @ObservedObject private var learning  = LearningStore.shared

    @State private var cover: ActiveCover?
    @State private var showPinPicker = false
    @State private var searchText    = ""

    /// One full-screen presentation at a time (two `.fullScreenCover`s on one
    /// view conflict): a review session, the learning session, or a verse opened
    /// from search.
    private enum ActiveCover: Identifiable {
        case review(TestSession)
        case learning(forceCurrent: Bool)
        case verse(VerseSearchResult)
        var id: String {
            switch self {
            case .review(let s):       return "review-\(s.id)"
            case .learning(let force): return force ? "learning-current" : "learning"
            case .verse(let r):        return "verse-\(r.id)"
            }
        }
    }

    private var packs:       [Pack] { packPrefs.visible(from: bibleVersion.packs) }
    private var activePacks: [Pack] { store.activePacks(packs) }

    /// All visible verses in pack order: the learning sequence.
    private var ordered: [Verse] { Catalogue.verses(in: packs) }

    /// The verse Home features: the pinned one, else the learning cursor.
    private var featured: LearningSpot? {
        guard let d = learning.displayed(in: ordered) else { return nil }
        return spot(for: d.verse, isPinned: d.isPinned)
    }

    /// The learning cursor, ignoring any pin.
    private var current: LearningSpot? {
        guard let c = learning.current(in: ordered) else { return nil }
        return spot(for: c.verse, isPinned: false)
    }

    private func spot(for verse: Verse, isPinned: Bool) -> LearningSpot? {
        guard let pack  = packs.first(where: { $0.name == verse.packName }),
              let index = pack.verses.firstIndex(where: { $0.srsKey == verse.srsKey })
        else { return nil }
        return LearningSpot(verse: verse, pack: pack, indexInPack: index, isPinned: isPinned)
    }

    /// The pack before/after `name`, so a learning session can roll into the next
    /// (or previous) pack when stepping past a boundary.
    private func adjacentPack(after name: String, forward: Bool) -> (name: String, verses: [Verse])? {
        guard let i = packs.firstIndex(where: { $0.name == name }) else { return nil }
        let j = forward ? i + 1 : i - 1
        guard packs.indices.contains(j) else { return nil }
        return (packs[j].name, packs[j].verses)
    }

    // MARK: - Body

    var body: some View {
        // One scroll view for the whole screen; see `PackListView.body`.
        MountAfterFirstFrame {
            ScrollView {
                if searchText.isEmpty {
                    dashboard
                } else {
                    VerseSearchResultsList(
                        query:   searchText,
                        results: VerseSearch.results(for: searchText, in: packs),
                        onSelect: { cover = .verse($0) }
                    )
                }
            }
        }
        // See `PackListView`: pins the initial offset above the search field.
        .defaultScrollAnchor(.top)
        .scrollDismissesKeyboard(.immediately)
        .animation(nil, value: searchText.isEmpty)
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Home")
        .navigationBarTitleDisplayMode(.large)
        .searchable(
            text: $searchText,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: "Search verses"
        )
        // Build the search index before the field is tapped, so the first
        // keystroke doesn't pay for it.
        .task { VerseSearch.prewarm(packs) }
        .fullScreenCover(item: $cover) { c in
            switch c {
            case .review(let s): TestSessionView(session: s, onSessionEnded: { cover = nil })
            case .learning(let force): learningSession(forceCurrent: force)
            case .verse(let r):
                // Read mode in its own pack, like tapping the verse from Packs.
                CardStudyCover(packName: r.pack.name, verses: r.pack.verses, initialIndex: r.verseIndex)
            }
        }
        .sheet(isPresented: $showPinPicker) {
            PinVersePicker(packs: packs, pinnedKey: learning.pinnedKey) { learning.pin($0) }
        }
    }

    private var dashboard: some View {
        VStack(spacing: AppLayout.spacing) {
            NavigationLink { StreakView() } label: { HomeStreakCard() }
                .buttonStyle(CardButtonStyle())
            learningCards
            Text("Daily Review")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 4)
                .padding(.top, 4)
            DailyReviewCard(activePacks: activePacks) { cover = .review($0) }
            packsReviewLink
        }
        .padding(.horizontal, AppLayout.screenMargin)
        .padding(.top, 8)
        .padding(.bottom, 24)
        .readableColumn()
    }

    // MARK: - Learning

    @ViewBuilder
    private var learningCards: some View {
        if let spot = featured {
            ContinueLearningCard(
                spot: spot,
                startMode: homeVerseStartMode,
                onOpen: { cover = .learning(forceCurrent: false) },
                onChangePin: { showPinPicker = true },
                onUnpin: { learning.unpin() }
            )
            if spot.isPinned, !learning.isCurrent(spot.verse), let cursor = current {
                GoToCurrentVerseCard(verse: cursor.verse) {
                    cover = .learning(forceCurrent: true)
                }
            }
        } else if !ordered.isEmpty {
            AllLearntCard()
        }
    }

    /// `forceCurrent` opens the learning cursor even while another verse is
    /// pinned (the "Go to current verse" shortcut).
    @ViewBuilder
    private func learningSession(forceCurrent: Bool) -> some View {
        if let spot = forceCurrent ? current : featured {
            // A pinned verse is a spotlight, not a step in the sequence, so it
            // gets neither cross-pack stepping nor marking complete.
            CardStudyCover(
                packName: spot.pack.name,
                verses: spot.pack.verses,
                initialIndex: spot.indexInPack,
                initialReviewMode: homeVerseStartMode.opensInReview,
                adjacentPack: spot.isPinned ? nil : { name, forward in adjacentPack(after: name, forward: forward) },
                onMarkLearnt: spot.isPinned ? nil : { learning.markLearnt($0) }
            )
        }
    }

    // MARK: - Packs Link

    /// Low-emphasis link to "Packs in Review". Every pack is reviewed by default,
    /// so this is rarely changed and doesn't warrant a section of its own.
    private var packsReviewLink: some View {
        NavigationLink {
            PacksReviewView()
        } label: {
            HStack(spacing: 4) {
                Text(packsLinkLabel)
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
            }
            .font(.system(size: 13))
            .foregroundStyle(.secondary)
            // Leading-aligned, where a grouped-list footer sits.
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 4)
            .padding(.vertical, 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Packs in review, \(packsLinkLabel)")
    }

    private var packsLinkLabel: String {
        let active = activePacks.count
        let total  = packs.count
        return active == total
            ? "Reviewing all \(total) packs"
            : "Reviewing \(active) of \(total) packs"
    }
}
