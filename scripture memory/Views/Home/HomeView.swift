import SwiftUI

/// The Home tab: streak, today's review, and the verse you're learning.
struct HomeView: View {

    @AppStorage(BibleVersion.storageKey)       private var bibleVersion: BibleVersion = .niv84
    @AppStorage(HomeVerseStartMode.storageKey) private var homeVerseStartMode: HomeVerseStartMode = .read

    @ObservedObject private var store     = SRSStore.shared
    @ObservedObject private var packPrefs = PackPreferencesStore.shared
    @ObservedObject private var learning  = LearningStore.shared

    @State private var cover: ActiveCover?
    @State private var showPinPicker = false

    /// One full-screen presentation at a time (two `.fullScreenCover`s on one
    /// view conflict): the daily review, a pack's practice, or a pack.
    private enum ActiveCover: Identifiable {
        case review(TestSession)
        case practice(TestSession)
        case pack(Pack, index: Int)
        var id: String {
            switch self {
            case .review(let s):          return "review-\(s.id)"
            case .practice(let s):        return "practice-\(s.id)"
            case .pack(let p, let index): return "pack-\(p.id)-\(index)"
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

    // MARK: - Body

    var body: some View {
        MountAfterFirstFrame {
            ScrollView { dashboard }
        }
        .defaultScrollAnchor(.top)
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Home")
        .navigationBarTitleDisplayMode(.large)
        .fullScreenCover(item: $cover) { c in
            switch c {
            case .review(let s): DailyReviewScreen(session: s, onFinished: { cover = nil })
            case .practice(let s): TestSessionView(session: s, onSessionEnded: { cover = nil })
            case .pack(let pack, let index): PouchView(pack: pack, startIndex: index)
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
            Text("Daily Review")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 4)
                .padding(.top, 4)
            DailyReviewCard(activePacks: activePacks) { cover = .review($0) }
            packsReviewLink
            learningCards
                .padding(.top, 8)
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
                onOpen: { openLearning(forceCurrent: false) },
                onChangePin: { showPinPicker = true },
                onUnpin: { learning.unpin() }
            )
            if spot.isPinned, !learning.isCurrent(spot.verse), let cursor = current {
                GoToCurrentVerseCard(verse: cursor.verse) {
                    openLearning(forceCurrent: true)
                }
            }
        } else if !ordered.isEmpty {
            AllLearntCard()
        }
    }

    /// `forceCurrent` opens the learning cursor even while another verse is
    /// pinned (the "Go to current verse" shortcut).
    private func openLearning(forceCurrent: Bool) {
        guard let spot = forceCurrent ? current : featured else { return }
        if homeVerseStartMode.opensInReview {
            if let session = TestSession.practice(spot.pack.verses, from: spot.indexInPack) {
                cover = .practice(session)
            }
        } else {
            cover = .pack(spot.pack, index: spot.indexInPack)
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
