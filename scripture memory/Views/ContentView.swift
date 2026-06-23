import SwiftUI

struct ContentView: View {
    @AppStorage("hasOnboardedLearning.v1") private var hasOnboarded = false
    @AppStorage("bibleVersion")            private var bibleVersion: BibleVersion = .niv84
    @AppStorage("srs.dailyNewCap")         private var dailyNewCap    = 1
    @AppStorage("srs.dailyReviewCap")      private var dailyReviewCap = 5
    @ObservedObject private var learning  = LearningStore.shared
    @ObservedObject private var packPrefs = PackPreferencesStore.shared
    @Environment(\.scenePhase) private var scenePhase

    /// One cover, enum-driven — two `.fullScreenCover` modifiers on a single view
    /// conflict, so onboarding and widget deep-links share this.
    @State private var cover: ActiveCover?

    private enum ActiveCover: Identifiable {
        case onboarding(showsWelcome: Bool)
        case read(pack: Pack, index: Int)
        case review(TestSession)
        var id: String {
            switch self {
            case .onboarding:         return "onboarding"
            case .read(let p, let i): return "read-\(p.id)-\(i)"
            case .review(let s):      return "review-\(s.id)"
            }
        }
    }

    var body: some View {
        TabView {
            NavigationStack {
                SRSDashboardView()
            }
            .tabItem {
                Image(systemName: "house.fill")
                Text("Home")
            }

            NavigationStack {
                PackListView()
            }
            .tabItem {
                Image(systemName: "rectangle.stack.fill")
                Text("Packs")
            }

            NavigationStack {
                TestSetupView()
            }
            .tabItem {
                Image(systemName: "checkmark.circle.fill")
                Text("Quiz")
            }

            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Image(systemName: "gearshape")
                Text("Settings")
            }
        }
        .fullScreenCover(item: $cover) { c in
            switch c {
            case .onboarding(let showsWelcome):
                LearningSetupView(isOnboarding: true,
                                  showsWelcome: showsWelcome,
                                  onComplete: { hasOnboarded = true })
            case .read(let pack, let index):
                // Open the verse in Read mode, in its pack (chrome hidden so the
                // card's own top bar shows; NavigationStack lets its keyboard work).
                NavigationStack {
                    CardStudyView(packName: pack.name, verses: pack.verses, initialIndex: index)
                        .toolbar(.hidden, for: .navigationBar)
                }
            case .review(let session):
                TestSessionView(session: session, onSessionEnded: { cover = nil })
            }
        }
        .onAppear {
            syncWidget()
            if !hasOnboarded {
                // Already-studying users skip the "Welcome to the app" hero and
                // just set their starting point; fresh installs get the full intro.
                cover = .onboarding(showsWelcome: SRSStore.shared.states.isEmpty)
            }
        }
        .onChange(of: learning.learntKeys) { _, _ in syncWidget() }
        .onChange(of: learning.pinnedKey)  { _, _ in syncWidget() }
        .onChange(of: bibleVersion)        { _, _ in syncWidget() }
        .onChange(of: hasOnboarded)        { _, _ in syncWidget() }
        // Refresh the widget snapshot when leaving/returning — catches streak and
        // due-count changes made during a review session.
        .onChange(of: scenePhase) { _, phase in
            if phase == .active || phase == .background { syncWidget() }
        }
        .onOpenURL { handleDeepLink($0) }
    }

    /// Mirror the current learning verse + streak + due-count + week into the App Group.
    private func syncWidget() {
        let visible   = packPrefs.visible(from: bibleVersion.packs)
        let displayed = learning.displayed(in: visible.flatMap(\.verses))
        let week      = StreakStore.shared.thisWeek().map {
            WidgetBridge.WeekDay(letter: $0.initial, done: $0.done, today: $0.isToday)
        }
        WidgetBridge.update(verse: displayed?.verse,
                            isPinned: displayed?.isPinned ?? false,
                            streak: StreakStore.shared.current,
                            dueToday: dailyQueueSize(packs: visible),
                            learned: learning.learntKeys.count,
                            week: week)
    }

    /// Cards due today across active packs — the same number Home shows.
    private func dailyQueueSize(packs: [Pack]) -> Int {
        let store = SRSStore.shared
        let now = Date()
        var learning = 0, review = 0, candidates = 0
        for pack in packs where store.isActive(pack.name) {
            let c = SRSQueueBuilder.counts(packName: pack.name, allVerses: pack.verses, store: store, now: now)
            learning += c.learning; review += c.review; candidates += c.newCandidates
        }
        let newRemaining = SRSQueueBuilder.globalNewRemaining(store: store, dailyNewCap: dailyNewCap, now: now)
        return learning + review + min(newRemaining, candidates)
    }

    private func handleDeepLink(_ url: URL) {
        guard url.scheme == "scripturememory" else { return }
        switch url.host {
        case "read":   openRead(url)
        case "review": openReview()
        default:       break
        }
    }

    /// `scripturememory://read?pack=&book=&ref=` — opens that verse in Read mode.
    private func openRead(_ url: URL) {
        guard let comps = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return }
        let q = comps.queryItems ?? []
        func val(_ n: String) -> String? { q.first(where: { $0.name == n })?.value }
        guard let packName = val("pack"),
              let pack = packPrefs.visible(from: bibleVersion.packs).first(where: { $0.name == packName })
        else { return }
        let idx = pack.verses.firstIndex { $0.book == val("book") && $0.reference == val("ref") } ?? 0
        cover = .read(pack: pack, index: idx)
    }

    /// `scripturememory://review` — starts today's review across active packs.
    private func openReview() {
        let active = packPrefs.visible(from: bibleVersion.packs).filter { SRSStore.shared.isActive($0.name) }
        let verses = SRSQueueBuilder.buildAllPacksSession(
            packs: active, store: SRSStore.shared,
            dailyNewCap: dailyNewCap, dailyReviewCap: dailyReviewCap, now: Date()
        )
        guard !verses.isEmpty else { return }
        TestSessionViewModel.clearPersistedProgress()
        cover = .review(TestSession(verses: verses, kind: .srs))
    }
}
