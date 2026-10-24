import SwiftUI

// MARK: - List Item

private enum PackListItem: Identifiable {
    case packHeader(Pack)
    case verse(Verse)

    var id: String {
        switch self {
        case .packHeader(let p): return "pack_\(p.id)"
        case .verse(let v):     return "verse_\(v.id)"
        }
    }
}

// MARK: - View

struct TestSetupView: View {

    @AppStorage(BibleVersion.storageKey) private var bibleVersion: BibleVersion = .niv84
    @ObservedObject private var packPrefs = PackPreferencesStore.shared
    @ObservedObject private var learning  = LearningStore.shared
    @ObservedObject private var favorites = FavoritesStore.shared

    @State private var selectedVerseIds:  Set<Int>    = []
    @State private var expandedPackIds:   Set<String> = []

    /// Live row positions, and the state of an in-flight two-finger drag.
    @State private var dragFrames = DragSelectFrames()
    /// What the drag is doing: `true` selects everything it crosses, `false`
    /// clears. Decided by the first row touched, so a run never alternates.
    @State private var dragSelects = true
    /// Rows already handled by this drag — re-entering one mustn't flip it back.
    @State private var dragVisited: Set<Int> = []
    @State private var quizCount:         Int         = 15
    @State private var activeSession:     TestSession? = nil
    @State private var savedSession:      TestSession? = nil
    @State private var showOverwriteAlert = false

    private static let savedSessionKey = "lastTestSessionVerseIds"
    private static let quizCountKey    = "reviewSetupQuizCount"

    private var selectedCount: Int { selectedVerseIds.count }
    private var clampedCount:  Int { max(1, min(quizCount, selectedCount)) }

    private var visiblePacks: [Pack] { packPrefs.visible(from: bibleVersion.packs) }

    /// Every visible verse in catalogue order — the sequence the learning cursor
    /// walks, and what "everything before this one" means.
    private var catalogue: [Verse] { Catalogue.verses(in: visiblePacks) }

    // Flat items for packs + their expanded verses — driven by expandedPackIds
    private var packItems: [PackListItem] {
        var items: [PackListItem] = []
        for pack in visiblePacks {
            items.append(.packHeader(pack))
            if expandedPackIds.contains(pack.id) {
                for verse in pack.verses {
                    items.append(.verse(verse))
                }
            }
        }
        return items
    }

    var body: some View {
        List {
            // Resume card — separate section so it stands apart
            if let session = savedSession {
                Section {
                    resumeRow(session)
                }
            }

            Section {
                shortcutRows
            }

            // All packs in one compact section
            Section {
                ForEach(packItems) { item in
                    switch item {
                    case .packHeader(let pack):
                        packHeaderRow(pack)
                            .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 8))

                    case .verse(let verse):
                        verseRow(verse)
                            .listRowInsets(EdgeInsets(top: 4, leading: 40, bottom: 4, trailing: 8))
                    }
                }
            }
        }
        // Two-finger drag anywhere over the list to select a run of verses.
        // Zero-sized and non-interactive: it only exists to find the enclosing
        // scroll view and hang a gesture off it.
        .background(
            TwoFingerDragSelect(
                onDrag: { point, isFirst in handleDragSelect(at: point, isFirst: isFirst) },
                onEnd:  { dragVisited.removeAll() }
            )
            .frame(width: 0, height: 0)
        )
        .listStyle(.insetGrouped)
        .listSectionSpacing(savedSession == nil ? 12 : 22)
        .animation(AppMotion.content, value: expandedPackIds)
        .animation(AppMotion.content, value: savedSession != nil)
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Quiz")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { deselectAllButton }
        }
        .onAppear {
            loadPersistedQuizCount()
            loadSavedSession()
        }
        .onChange(of: selectedVerseIds) { _, _ in
            reconcileQuizCountWithSelection()
        }
        .onChange(of: quizCount) { _, _ in
            UserDefaults.standard.set(quizCount, forKey: Self.quizCountKey)
        }
        .alert("Existing Session", isPresented: $showOverwriteAlert) {
            Button("Keep Session", role: .cancel) { }
            Button("Start New", role: .destructive) { launchNewSession() }
        } message: {
            Text("You have an unfinished session. Starting a new one will overwrite it.")
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if !selectedVerseIds.isEmpty { bottomBar }
        }
        .fullScreenCover(item: $activeSession) { session in
            NavigationStack {
                TestSessionView(session: session, onSessionEnded: clearSession)
                    .toolbar(.hidden, for: .navigationBar)
            }
        }
    }

    // MARK: - Resume Row

    private func resumeRow(_ session: TestSession) -> some View {
        let sessionIds   = Set(session.verses.map(\.id))
        let packNames    = bibleVersion.packs
            .filter { pack in pack.verses.contains { sessionIds.contains($0.id) } }
            .map(\.name)
        let packsText    = packNames.joined(separator: ", ")

        return HStack(spacing: 10) {
            Image(systemName: "play.circle.fill")
                .font(.system(size: 22))
                .foregroundStyle(Color.accentColor)

            VStack(alignment: .leading, spacing: 1) {
                Text("Session in Progress")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.primary)
                Text("\(session.verses.count) cards · \(packsText)")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            RowChevron()
        }
        .padding(.vertical, 3)
        .listRowInsets(EdgeInsets(top: 2, leading: 16, bottom: 2, trailing: 14))
        .contentShape(Rectangle())
        .onTapGesture { activeSession = session }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                dismissSavedSession()
            } label: {
                Label("End", systemImage: "trash")
            }
        }
    }

    // MARK: - Shortcuts

    /// Presets for the spans people actually quiz on ("everything I've learnt so
    /// far" would otherwise be a hundred-odd taps). Visible rows rather than a
    /// menu, since they're used while choosing verses.
    @ViewBuilder
    private var shortcutRows: some View {
        let upToCurrent = versesUpToCurrent()
        if !upToCurrent.isEmpty {
            shortcutRow(
                title: "Up to current verse",
                detail: learning.currentVerse.flatMap { VerseNumbering.code(for: $0) }
                    ?? Wording.verses(upToCurrent.count)
            ) { select(upToCurrent) }
        }

        let starred = favorites.verses(in: visiblePacks)
        if !starred.isEmpty {
            shortcutRow(title: "Favourites", detail: "\(starred.count)") { select(starred) }
        }
    }

    /// Clearing the selection, in the navigation bar where Mail and Files put it.
    @ViewBuilder
    private var deselectAllButton: some View {
        if !selectedVerseIds.isEmpty {
            Button("Deselect All") {
                selectedVerseIds = []
                HapticEngine.light()
            }
        }
    }

    /// A plain title-and-value row.
    private func shortcutRow(title: String, detail: String,
                             action: @escaping () -> Void) -> some View {
        Button {
            action()
            HapticEngine.light()
        } label: {
            HStack {
                Text(title)
                    .font(.system(size: 16))
                    .foregroundStyle(Color.accentColor)
                Spacer()
                Text(detail)
                    .font(.system(size: 15))
                    .foregroundStyle(Color.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Pack Header Row

    /// The checkbox selects the whole pack; the rest of the row expands it. The
    /// row does the reversible thing and the checkbox the committal one.
    private func packHeaderRow(_ pack: Pack) -> some View {
        let packVerseIds   = Set(pack.verses.map(\.id))
        let selectedInPack = packVerseIds.intersection(selectedVerseIds).count
        let allSelected    = selectedInPack == pack.verses.count && !pack.verses.isEmpty
        let someSelected   = selectedInPack > 0
        let isExpanded     = expandedPackIds.contains(pack.id)

        return HStack(spacing: 0) {
            // ① Checkbox
            Button {
                if allSelected {
                    for verse in pack.verses { selectedVerseIds.remove(verse.id) }
                } else {
                    for verse in pack.verses { selectedVerseIds.insert(verse.id) }
                }
                HapticEngine.light()
            } label: {
                SelectionCircle(isSelected: allSelected, mixed: someSelected && !allSelected, size: 22)
                    .frame(width: 44, height: 50)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(allSelected ? "Deselect all verses in \(pack.name)" : "Select all verses in \(pack.name)")

            // ② + ③ Name and chevron — one expand target
            Button {
                if isExpanded { expandedPackIds.remove(pack.id) }
                else          { expandedPackIds.insert(pack.id) }
            } label: {
                PackRowLabel(pack: pack,
                             detail: selectedInPack > 0 ? "\(selectedInPack) of \(pack.verses.count) verses" : nil) {
                    RowChevron()
                        .rotationEffect(isExpanded ? .degrees(90) : .zero)
                        .frame(width: 44, height: 50)
                }
                .frame(maxHeight: .infinity)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isExpanded ? "Collapse \(pack.name)" : "Expand \(pack.name) to pick individual verses")
        }
    }

    // MARK: - Verse Row

    /// One line: tick, card number, title, reference. Tapping the row toggles it
    /// in or out of the quiz; the trailing arrow selects everything up to here.
    private func verseRow(_ verse: Verse) -> some View {
        let isSelected = selectedVerseIds.contains(verse.id)
        return Button {
            if isSelected { selectedVerseIds.remove(verse.id) }
            else          { selectedVerseIds.insert(verse.id) }
            HapticEngine.light()
        } label: {
            VerseRowLabel(verse: verse, leading: {
                SelectionCircle(isSelected: isSelected)
            }, trailing: {})
            .padding(.vertical, 2)
            // Room for the "up to here" control overlaid at the trailing edge.
            .padding(.trailing, 30)
        }
        .buttonStyle(.plain)
        .overlay(alignment: .trailing) { upToHereButton(verse) }
        .dragSelectRow(id: verse.id, in: dragFrames)
        .accessibilityLabel("\(verse.title), \(verse.book) \(verse.reference)")
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    // MARK: - Span selection

    /// Every visible verse up to and including `verse`, in catalogue order.
    private func versesUpTo(_ verse: Verse) -> [Verse] {
        let all = catalogue
        guard let i = all.firstIndex(where: { $0.id == verse.id }) else { return [] }
        return Array(all[...i])
    }

    /// Everything up to and including the learning cursor. Once every verse is
    /// learnt there is no cursor, and the span is the whole catalogue.
    private func versesUpToCurrent() -> [Verse] {
        guard let current = learning.currentVerse else { return catalogue }
        let all = catalogue
        guard let i = all.firstIndex(where: { $0.srsKey == current.srsKey }) else { return [] }
        return Array(all[...i])
    }

    /// Selects everything up to and including this verse, across the whole
    /// catalogue rather than just this pack. A bare glyph rather than a labelled button: on a list this long a label
    /// would be thirty copies of the same sentence.
    private func upToHereButton(_ verse: Verse) -> some View {
        Button {
            select(versesUpTo(verse))
            HapticEngine.light()
        } label: {
            Image(systemName: "arrow.up.to.line")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.tertiary)
                .frame(width: 30, height: 36)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Select all verses up to \(verse.title)")
    }

    /// Applies a two-finger drag to whichever verse row is under the finger. The
    /// first row decides the direction for the whole drag (select or clear), and
    /// `dragVisited` stops a row flipping again when the finger wobbles back.
    private func handleDragSelect(at point: CGPoint, isFirst: Bool) {
        guard let id = dragFrames.row(at: point) else { return }
        if isFirst {
            dragVisited.removeAll()
            dragSelects = !selectedVerseIds.contains(id)
        }
        guard !dragVisited.contains(id) else { return }
        dragVisited.insert(id)
        if dragSelects { selectedVerseIds.insert(id) } else { selectedVerseIds.remove(id) }
        HapticEngine.light()
    }

    /// Replaces the selection rather than adding to it: the shortcuts read as
    /// "quiz me on X", so Favourites after Up to Current leaves just the favourites.
    private func select(_ verses: [Verse]) {
        selectedVerseIds = Set(verses.map(\.id))
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        BottomActionBar { bottomBarContent }
    }

    private var bottomBarContent: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 1) {
                Text("\(selectedCount)")
                    .font(.system(size: 22, weight: .bold, design: .monospaced))
                Text("verses")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.secondary)
            }
            .frame(minWidth: 55, alignment: .leading)

            Spacer()

            QuizCountStepper(count: $quizCount, maximum: selectedCount)

            Spacer()

            Button {
                if savedSession != nil { showOverwriteAlert = true }
                else                   { launchNewSession() }
            } label: {
                Text("Start").font(.headline)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .buttonBorderShape(.capsule)
            .tint(.accentColor)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Actions

    private func launchNewSession() {
        // Wipe any stale progress so the new session starts clean
        TestSessionViewModel.clearPersistedProgress()

        var verses: [Verse] = []
        for pack in bibleVersion.packs {
            for verse in pack.verses where selectedVerseIds.contains(verse.id) {
                verses.append(verse)
            }
        }
        let session = TestSession(verses: Array(verses.shuffled().prefix(clampedCount)))
        persistSession(session)
        savedSession  = session
        activeSession = session
    }

    private func clearSession() {
        savedSession = nil
        UserDefaults.standard.removeObject(forKey: Self.savedSessionKey)
    }

    /// Discards the saved in-progress session and its progress.
    private func dismissSavedSession() {
        clearSession()
        TestSessionViewModel.clearPersistedProgress()
    }

    // MARK: - Persistence

    private func persistSession(_ session: TestSession) {
        UserDefaults.standard.set(session.verses.map(\.id), forKey: Self.savedSessionKey)
    }

    private func loadSavedSession() {
        guard savedSession == nil,
              let ids = UserDefaults.standard.array(forKey: Self.savedSessionKey) as? [Int],
              !ids.isEmpty else { return }
        let idSet = Set(ids)
        var byId: [Int: Verse] = [:]
        for pack in bibleVersion.packs {
            for verse in pack.verses where idSet.contains(verse.id) { byId[verse.id] = verse }
        }
        let ordered = ids.compactMap { byId[$0] }
        if !ordered.isEmpty { savedSession = TestSession(verses: ordered) }
    }

    private func loadPersistedQuizCount() {
        if let saved = UserDefaults.standard.object(forKey: Self.quizCountKey) as? Int, saved >= 1 {
            quizCount = saved
        }
        reconcileQuizCountWithSelection()
    }

    private func reconcileQuizCountWithSelection() {
        guard !selectedVerseIds.isEmpty else { return }
        quizCount = clampedCount
    }
}

#Preview {
    NavigationStack { TestSetupView() }
}
