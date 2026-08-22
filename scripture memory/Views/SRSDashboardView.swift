import SwiftUI

/// Daily review dashboard.
///
/// One primary action — Start Review across all active packs. Per-pack rows
/// show progress and an Active toggle on the right (iOS standard placement).
/// New cards are gated by a single GLOBAL daily cap shared across active packs.
struct SRSDashboardView: View {

    @AppStorage("bibleVersion")       private var bibleVersion:   BibleVersion = .niv84
    @AppStorage(NewCardCap.amountKey) private var newCapAmount:  Int          = NewCardCap.fallback.amount
    @AppStorage(NewCardCap.unitKey)   private var newCapUnit:    NewCapUnit   = NewCardCap.fallback.unit
    /// The two stored halves as the one value the queue builder takes.
    private var newCap: NewCardCap { NewCardCap(amount: newCapAmount, unit: newCapUnit) }
    @AppStorage(NewCardCap.dailyReviewCapKey) private var dailyReviewCap: Int  = NewCardCap.dailyReviewCapDefault
    @AppStorage("homeVerseStartMode.v1") private var homeVerseStartMode: HomeVerseStartMode = .read
    /// Read here so the counts re-render when the Settings toggle flips.
    @AppStorage(SRSQueueBuilder.NewCardPolicy.reviewsKnownKey)
    private var reviewsKnownVerses = SRSQueueBuilder.NewCardPolicy.reviewsKnownDefault

    @ObservedObject private var store     = SRSStore.shared
    @ObservedObject private var packPrefs = PackPreferencesStore.shared
    @ObservedObject private var learning  = LearningStore.shared
    @ObservedObject private var streak    = StreakStore.shared

    @State private var cover: ActiveCover?
    @State private var showPinPicker = false
    @State private var searchText    = ""

    /// One full-screen presentation at a time — review session, the linear learning
    /// session, or a verse opened from search. (Two separate `.fullScreenCover`
    /// modifiers on one view conflict in SwiftUI, so they're unified here.)
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

    // MARK: - Design Tokens (iOS-standard continuous corners + 8/12/16 spacing)

    private static let cardPadding:    CGFloat = 20
    private static let rowPaddingH:    CGFloat = 16
    private static let sectionSpacing: CGFloat = 16

    private var packs:        [Pack] { packPrefs.visible(from: bibleVersion.packs) }
    private var activePacks:  [Pack] { packs.filter { store.isActive($0.name) } }
    private var now:          Date   { Date() }

    /// All visible verses flattened in pack order — the linear "learning" sequence.
    private var ordered:      [Verse] { Catalogue.verses(in: packs) }

    /// The verse to feature on Home — the pinned one if the user pinned one, else
    /// the current learning verse — resolved to its pack + index, plus whether
    /// it's pinned (so the card and practice session can adapt).
    private func displayedLearning() -> (verse: Verse, pack: Pack, indexInPack: Int, isPinned: Bool)? {
        guard let d = learning.displayed(in: ordered),
              let pack = packs.first(where: { $0.name == d.verse.packName }),
              let idx  = pack.verses.firstIndex(where: { $0.srsKey == d.verse.srsKey })
        else { return nil }
        return (d.verse, pack, idx, d.isPinned)
    }

    /// The pack before/after `name` — lets a Continue session roll into the next
    /// (or previous) pack when stepping past a boundary.
    private func adjacentPack(after name: String, forward: Bool) -> (name: String, verses: [Verse])? {
        guard let i = packs.firstIndex(where: { $0.name == name }) else { return nil }
        let j = forward ? i + 1 : i - 1
        guard packs.indices.contains(j) else { return nil }
        return (packs[j].name, packs[j].verses)
    }

    private var globalNewRemaining: Int {
        SRSQueueBuilder.globalNewRemaining(store: store, newCap: newCap, now: now)
    }

    /// New cards projected per active pack, with the GLOBAL cap dripped across
    /// packs in list order. Without this, every pack independently shows the
    /// full remaining cap (e.g. three packs each reading "2 new" when only 2
    /// new cards will actually be served today).
    private var projectedNewByPack: [String: Int] {
        SRSQueueBuilder.projectedNewByPack(
            orderedActivePacks: activePacks,
            store: store,
            newCap: newCap,
            now: now
        )
    }

    var body: some View {
        // One scroll view for the whole screen — see `PackListView.body`. Two
        // alternating scroll views under one `.searchable` is what made Home open
        // scrolled past its own large title.
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
        // See `PackListView` — pins the initial offset above the search field.
        .defaultScrollAnchor(.top)
        .scrollDismissesKeyboard(.immediately)
        // Swapping the whole screen shouldn't animate — matches Packs.
        .animation(nil, value: searchText.isEmpty)
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Home")
        .navigationBarTitleDisplayMode(.large)
        .searchable(
            text: $searchText,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: "Search verses"
        )
        // Build the match index before the field is ever tapped, so the first
        // character typed isn't the one that pays for it.
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
        VStack(spacing: Self.sectionSpacing) {
            streakCard
            continueLearningCard
            goToCurrentVerseCard
            // Title Case at 17pt semibold, not 13pt uppercase — the grouped-list
            // header iOS Settings actually uses now. The small all-caps form is
            // the older style and reads as a label stuck above a card rather than
            // as the section's own heading.
            Text("Daily Review")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 4)
                .padding(.top, 4)
            heroCard
            packsReviewLink
        }
        .padding(.horizontal, AppLayout.screenMargin)
        .padding(.top, 8)
        .padding(.bottom, 24)
    }

    // MARK: - Streak

    private var streakCard: some View {
        let count = streak.current
        let week  = streak.thisWeek()
        return HStack(spacing: 10) {
            Image(systemName: "flame.fill")
                .font(.system(size: 20))
                .foregroundStyle(count > 0 ? Color.orange : Color(.systemGray3))
                .symbolEffect(.bounce, options: .nonRepeating, value: count)
            Text(count == 1 ? "1 day streak" : "\(count) day streak")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.primary)
                .contentTransition(.numericText())
            Spacer(minLength: 8)
            HStack(spacing: 5) {
                ForEach(Array(week.enumerated()), id: \.offset) { _, day in
                    ZStack {
                        Circle()
                            .fill(day.done ? Color.orange : Color(.systemGray5))
                            .frame(width: 17, height: 17)
                        if day.done {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(.white)
                        } else if day.isToday {
                            Circle().strokeBorder(Color.orange, lineWidth: 1.5).frame(width: 17, height: 17)
                        }
                    }
                    .opacity(day.isFuture ? 0.35 : 1)
                }
            }
        }
        .padding(.horizontal, Self.rowPaddingH)
        .padding(.vertical, 11)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: AppLayout.groupedRadius, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(count) day streak")
    }

    // MARK: - Continue Learning

    @ViewBuilder
    private var continueLearningCard: some View {
        if let cur = displayedLearning() {
            let v = cur.verse
            VStack(alignment: .leading, spacing: 10) {
                // Header: mode label + position + pin/reset menu. Kept OUTSIDE the
                // practice button so the Menu's taps don't fight the card tap.
                HStack(spacing: 6) {
                    if cur.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                    Text(cur.isPinned ? "Pinned" : "Continue Learning")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                    Spacer()
                    Text("\(cur.indexInPack + 1) of \(cur.pack.verses.count)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                    Menu {
                        if cur.isPinned {
                            Button { showPinPicker = true } label: {
                                Label("Change verse", systemImage: "pin")
                            }
                            Button { learning.unpin(); HapticEngine.light() } label: {
                                Label("Unpin verse", systemImage: "pin.slash")
                            }
                        } else {
                            Button { showPinPicker = true } label: {
                                Label("Pin a verse", systemImage: "pin")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel("Verse options")
                }

                // Body: tap the verse to practice it.
                Button {
                    cover = .learning(forceCurrent: false)
                } label: {
                    VStack(alignment: .leading, spacing: 10) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(v.title)
                                .font(.system(size: 16, weight: .bold, design: .serif))
                                .foregroundStyle(Color.primary)
                                .multilineTextAlignment(.leading)
                            Text("\(v.book) \(v.reference)")
                                .font(.system(size: 14, design: .serif))
                                .foregroundStyle(Color.secondary)
                            Text(v.verse)
                                .font(.system(size: 15, design: .serif))
                                .foregroundStyle(Color.primary)
                                .lineSpacing(4)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        HStack(spacing: 5) {
                            Text(cur.pack.name)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                            Spacer()
                            Text(homeVerseStartMode.ctaLabel)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Color.accentColor)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(Color.accentColor)
                        }
                        .padding(.top, 2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(CardButtonStyle())
                .accessibilityLabel("\(homeVerseStartMode.ctaLabel) \(v.book) \(v.reference)")
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: AppLayout.groupedRadius, style: .continuous)
                    .fill(flashcardBackground)
                    .shadow(color: .black.opacity(0.13), radius: 14, x: 0, y: 7)
                    .shadow(color: .black.opacity(0.05), radius: 2,  x: 0, y: 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppLayout.groupedRadius, style: .continuous)
                    .strokeBorder(Color(.separator).opacity(0.4), lineWidth: 0.5)
            )
        } else if !ordered.isEmpty {
            allLearntCard
        }
    }

    /// Standalone shortcut back to the live cursor verse, shown as its own card
    /// below the pinned card when a *different* verse is pinned — so it reads as a
    /// distinct action, not part of the pinned verse.
    @ViewBuilder
    private var goToCurrentVerseCard: some View {
        if let cur = displayedLearning(), cur.isPinned,
           !learning.isCurrent(cur.verse), let c = currentLearning() {
            Button {
                cover = .learning(forceCurrent: true)
                HapticEngine.light()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "arrow.turn.down.right")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Go to current verse")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.primary)
                        Text("\(c.verse.book) \(c.verse.reference)")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 8)
                    RowChevron()
                }
                .padding(.horizontal, Self.rowPaddingH)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: AppLayout.groupedRadius, style: .continuous)
                        .fill(Color(.secondarySystemGroupedBackground))
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Go to current verse, \(c.verse.book) \(c.verse.reference)")
        }
    }

    private var allLearntCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 26))
                .foregroundStyle(.green)
            VStack(alignment: .leading, spacing: 2) {
                Text("Every verse learnt")
                    .font(.system(size: 16, weight: .semibold))
                Text("Keep them sharp in Daily Review below.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(Self.cardPadding)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: AppLayout.groupedRadius, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    @ViewBuilder
    private func learningSession(forceCurrent: Bool) -> some View {
        // `forceCurrent` opens the live cursor even while a different verse is
        // pinned (the "Go to current verse" shortcut); otherwise open whatever
        // Home features (the pinned verse, else the cursor).
        if let cur = forceCurrent ? currentLearning() : displayedLearning() {
            // A pinned verse is a spotlight, not a progression step, so it gets
            // neither cross-pack stepping nor "Mark as Learnt".
            CardStudyCover(
                packName: cur.pack.name,
                verses: cur.pack.verses,
                initialIndex: cur.indexInPack,
                initialReviewMode: homeVerseStartMode.opensInReview,
                adjacentPack: cur.isPinned ? nil : { name, forward in adjacentPack(after: name, forward: forward) },
                onMarkLearnt: cur.isPinned ? nil : { learning.markLearnt($0) }
            )
        }
    }

    /// The live cursor verse (ignoring any pin) resolved to pack + index — backs
    /// the "Go to current verse" shortcut. `isPinned` is always false here.
    private func currentLearning() -> (verse: Verse, pack: Pack, indexInPack: Int, isPinned: Bool)? {
        guard let c = learning.current(in: ordered),
              let pack = packs.first(where: { $0.name == c.verse.packName }),
              let idx  = pack.verses.firstIndex(where: { $0.srsKey == c.verse.srsKey })
        else { return nil }
        return (c.verse, pack, idx, false)
    }

    // MARK: - Hero Card

    @ViewBuilder
    private var heroCard: some View {
        let agg = aggregate()
        VStack(spacing: 16) {
            if activePacks.isEmpty {
                heroNoActivePacks
            } else if agg.queueSize > 0 {
                heroQueue(agg: agg)
            } else {
                heroCaughtUp(agg: agg)
            }
        }
        .frame(maxWidth: .infinity)
        // A one-line row doesn't need the 20pt inset a tall stack did.
        .padding(.vertical, 14)
        .padding(.horizontal, Self.rowPaddingH)
        .background(
            RoundedRectangle(cornerRadius: AppLayout.groupedRadius, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    private var heroNoActivePacks: some View {
        HStack(spacing: 12) {
            Image(systemName: "square.stack.3d.up.slash")
                .font(.system(size: 26))
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text("No active packs")
                    .font(.system(size: 16, weight: .semibold))
                Text("Turn on a pack to start your daily review.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }

    /// One row: what's due, and the button to do it.
    ///
    /// This was a stack — a 48pt numeral, a full-width Start button, then the
    /// breakdown — roughly 200pt tall to say "1 card due today". iOS puts a
    /// summary like this on one line with the action trailing (Software Update,
    /// the App Store's Update All, a Reminders smart list): the count reads at a
    /// glance, the button is still the most prominent thing in the row, and the
    /// rest of Home moves up to meet it.
    private func heroQueue(agg: Aggregate) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    // Rounded for the numeral only — the label beside it stays on
                    // the standard face.
                    Text("\(agg.queueSize)")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .contentTransition(.numericText())
                    Text(agg.queueSize == 1 ? "card due today" : "cards due today")
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)

                HStack(spacing: 10) {
                    breakdownChip(label: "Learning", value: agg.learning,     color: .orange)
                    breakdownChip(label: "Review",   value: agg.review,       color: .blue)
                    breakdownChip(label: "New",      value: agg.newProjected, color: .green)
                }
            }

            Spacer(minLength: 8)

            Button {
                startSession(forPacks: activePacks)
            } label: {
                Text("Start")
                    .font(.system(size: 15, weight: .semibold))
                    .padding(.horizontal, 6)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
            .buttonBorderShape(.capsule)
            .tint(.accentColor)
            .accessibilityLabel("Start review")
        }
    }

    /// Same row shape as the queue state, so the card doesn't resize as you
    /// finish a session.
    private func heroCaughtUp(agg: Aggregate) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 26))
                .foregroundStyle(.green)
                .symbolEffect(.bounce, options: .nonRepeating)
            VStack(alignment: .leading, spacing: 2) {
                Text("All caught up")
                    .font(.system(size: 16, weight: .semibold))
                Text(caughtUpMessage(agg: agg))
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }

    /// The honest "what's next" line for the caught-up state. The old copy only
    /// read review due-dates, so it announced "next card in 3 days" even though a
    /// new verse drips in at tomorrow's midnight reset — misleading. This surfaces
    /// whichever is genuinely soonest.
    private func caughtUpMessage(agg: Aggregate) -> String {
        let next         = nextDueAcrossActivePacks()
        let newVerseDrip = agg.newCandidates > 0 && newCap.amount > 0
        let tomorrow     = Calendar.current.startOfDay(for: now).addingTimeInterval(SRSStore.secondsPerDay)

        // A card (often a learning step) is still due before midnight.
        if let next, next < tomorrow {
            return "Your next review is in \(formatRelative(next))."
        }
        // New verses for this period are done. When they come back depends on the
        // period: a weekly cap doesn't reset at midnight, and saying it does is
        // the kind of small lie that teaches people to stop believing the screen.
        if newVerseDrip {
            let n    = min(newCap.amount, agg.newCandidates)   // how many actually drip in
            let when = newCap.unit == .day ? "tomorrow" : "next week"
            return n == 1
                ? "Come back \(when) for a new verse."
                : "Come back \(when) for \(n) new verses."
        }
        // Nothing new left to add — just spaced reviews ahead.
        if let next {
            return "Your next review is in \(formatRelative(next))."
        }
        // New verses remain, but the daily new-verse limit is off.
        if agg.newCandidates > 0 {
            return "Raise your daily new verses in Settings to keep going."
        }
        return "You've reviewed every verse in your active packs."
    }

    private func breakdownChip(label: String, value: Int, color: Color) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text("\(value) \(label)")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Packs Section

    /// Low-emphasis link to the dedicated "Packs in Review" screen. Every pack is
    /// reviewed by default (users learn them in order), so which packs are on is
    /// rarely adjusted — it doesn't warrant a section on Home.
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
            // Leading, not centred. This sits where a grouped-list *footer* sits,
            // and iOS aligns those to the section's leading edge — centred, it
            // read as a standalone button floating under the card.
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

    // MARK: - Session Launch

    private func startSession(forPacks targetPacks: [Pack]) {
        let verses = SRSQueueBuilder.buildAllPacksSession(
            packs: targetPacks,
            store: store,
            newCap: newCap,
            dailyReviewCap: dailyReviewCap,
            now: now
        )
        guard !verses.isEmpty else { return }
        TestSessionViewModel.clearPersistedProgress()
        cover = .review(TestSession(verses: verses, kind: .srs))
    }

    // MARK: - Aggregates

    private struct Aggregate {
        var learning:      Int = 0
        var review:        Int = 0
        var newProjected:  Int = 0
        var newCandidates: Int = 0   // full unscheduled pool (future days), not just today's drip
        var queueSize: Int { learning + review + newProjected }
    }

    private func aggregate() -> Aggregate {
        var agg = Aggregate()
        var totalCandidates = 0
        for pack in activePacks {
            let c = SRSQueueBuilder.counts(
                packName: pack.name,
                allVerses: pack.verses,
                store: store,
                now: now
            )
            agg.learning    += c.learning
            agg.review      += c.reviewServed(cap: dailyReviewCap)
            totalCandidates += c.newCandidates
        }
        agg.newProjected  = min(globalNewRemaining, totalCandidates)
        agg.newCandidates = totalCandidates
        return agg
    }

    private func nextDueAcrossActivePacks() -> Date? {
        activePacks.flatMap { $0.verses }
            .compactMap { store.state(for: $0)?.due }
            .filter { $0 > now }
            .min()
    }

    private func formatRelative(_ date: Date) -> String {
        let dt = date.timeIntervalSince(Date())
        if dt <= 0 { return "now" }
        if dt < 60 { return "<1m" }
        if dt < 3_600 { return "\(Int(dt / 60))m" }
        if dt < SRSStore.secondsPerDay { return "\(Int(dt / 3_600))h" }
        let days = Int(dt / SRSStore.secondsPerDay)
        return days == 1 ? "1 day" : "\(days) days"
    }
}
