import SwiftUI

// MARK: - List Item

private enum PackListItem: Identifiable {
    case packHeader(Pack)
    case verse(Verse, packId: String)

    var id: String {
        switch self {
        case .packHeader(let p): return "pack_\(p.id)"
        case .verse(let v, _):  return "verse_\(v.id)"
        }
    }
}

// MARK: - View

struct TestSetupView: View {

    @AppStorage("bibleVersion") private var bibleVersion: BibleVersion = .niv84
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

    /// Typed-entry state for the card count. Stepping one at a time is fine for a
    /// nudge but painful for "make it 40", so the number itself is tappable and
    /// swaps to a number-pad field.
    @State private var countDraft = ""
    @FocusState private var countFieldFocused: Bool
    /// The value the field is showing that a keystroke should *replace* rather than
    /// extend — set whenever the count arrives from somewhere other than typing
    /// (focus, +/-, Max), cleared once a digit has replaced it.
    ///
    /// The field used to blank itself on focus to get the same effect, which left it
    /// showing nothing while the stepper still held a value, so any +/- tap made
    /// with the keypad up looked like it did nothing at all.
    @State private var countReplaceAnchor: String? = nil

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
                    items.append(.verse(verse, packId: pack.id))
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

                    case .verse(let verse, _):
                        verseRow(verse)
                            .listRowInsets(EdgeInsets(top: 4, leading: 52, bottom: 4, trailing: 16))
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
        .onTapGesture { activeSession = savedSession }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                dismissSavedSession()
            } label: {
                Label("End", systemImage: "trash")
            }
        }
    }

    // MARK: - Shortcuts
    //
    // Picking a quiz almost always means one of a few spans, and reaching them by
    // hand is the tedious part: "everything I've learnt so far" is a hundred-odd
    // taps, or one pack checkbox plus un-ticking the tail of the pack you're in.

    /// The two smart presets, as visible rows.
    ///
    /// These stay on screen rather than folding into a menu: they're for use
    /// *while* choosing verses, and a control you need mid-task has to be in
    /// sight — a `⋯` menu is where occasional commands go, not the ones you're
    /// reaching for. They sit in their own group above the packs, so they read as
    /// shortcuts rather than as two more packs.
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

    /// Clearing the selection, in the navigation bar — where Mail and Files put
    /// it. It acts on the whole selection rather than adding a span to it, so as
    /// a list row it had to appear the moment you picked something, shoving every
    /// pack down under a finger already moving toward one.
    @ViewBuilder
    private var deselectAllButton: some View {
        if !selectedVerseIds.isEmpty {
            Button("Deselect All") {
                selectedVerseIds = []
                HapticEngine.light()
            }
        }
    }

    /// A plain title-and-value row, the shape iOS uses for exactly this. No icon:
    /// coloured glyphs down the left edge implied unrelated kinds of thing, when
    /// these are just two ways of filling the same selection.
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
    //
    // Three distinct zones:
    //   ① Checkbox button  — select/deselect all verses in this pack
    //   ② Pack name        — tap to expand/collapse
    //   ③ Chevron          — same as ②, just the affordance for it
    //
    // Tapping the row used to select the whole pack, which put "select 55 verses"
    // and "look inside" one mis-tap apart, with only the checkbox distinguishing
    // them. Now the row does the reversible thing and the checkbox does the
    // committal one — the same split the verse rows use.

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

    /// One line: tick, card number, title, reference. Nothing to open.
    ///
    /// A verse row has exactly one job here — in or out of the quiz — so the
    /// whole row does it. It used to expand to a panel holding the verse text and
    /// two more buttons, which meant every row carried a disclosure chevron for a
    /// drawer nobody wants open while picking a quiz. "Select all up to here"
    /// moved to a swipe action: still one gesture away, costs no pixels.
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
            .padding(.trailing, 34)
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
    /// catalogue rather than just this pack. Reaching, say, DEP 1 card 12 means
    /// "everything I've covered so far" — the span you most want, and the most
    /// tedious to tick by hand.
    ///
    /// A visible control because the swipe action alone was undiscoverable —
    /// nobody finds a gesture they haven't been told about. Kept to a single
    /// tertiary glyph at the trailing edge: on a list this long, anything with a
    /// label would be thirty copies of the same sentence running down the page.
    private func upToHereButton(_ verse: Verse) -> some View {
        Button {
            select(versesUpTo(verse))
            HapticEngine.light()
        } label: {
            Image(systemName: "arrow.up.to.line")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.tertiary)
                .frame(width: 34, height: 36)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Select all verses up to \(verse.title)")
    }

    /// Applies a two-finger drag to whichever verse row is under the finger.
    ///
    /// The first row decides the direction for the whole drag — start on an
    /// unselected verse and the run selects, start on a selected one and it
    /// clears. Toggling each row on its own terms would leave a dragged-over run
    /// alternating, which is never what anyone means.
    ///
    /// `dragVisited` stops a row flipping again when the finger wobbles back
    /// over it.
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

    /// Replaces the selection rather than adding to it.
    ///
    /// These read as "quiz me on X", so tapping Favourites after Up to Current
    /// Verse has to leave you with the favourites — not with both sets unioned
    /// and no indication that's what happened. Composing them was defensible in
    /// the abstract and wrong in the hand: the shortcut appears to do nothing
    /// when everything it would add is already selected, and there's no way to
    /// subtract one preset back out again.
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

            VStack(spacing: 4) {
                HStack(spacing: 10) {
                    Button {
                        setCount(clampedCount - 1)
                    } label: {
                        Image(systemName: "minus")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.accentColor)
                            .frame(width: 32, height: 32)
                            .background(Color(.secondarySystemBackground), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .disabled(clampedCount <= 1)
                    .opacity(clampedCount <= 1 ? 0.35 : 1)
                    .accessibilityLabel("Fewer cards to quiz")

                    countField

                    Button {
                        setCount(clampedCount + 1)
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.accentColor)
                            .frame(width: 32, height: 32)
                            .background(Color(.secondarySystemBackground), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .disabled(clampedCount >= selectedCount)
                    .opacity(clampedCount >= selectedCount ? 0.35 : 1)
                    .accessibilityLabel("More cards to quiz")
                }
                // "Max" is the one count that's tedious to reach by stepping and
                // annoying to type — quizzing everything you just selected.
                HStack(spacing: 6) {
                    Text("cards to quiz")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.secondary)
                    Button {
                        setCount(selectedCount)
                        HapticEngine.light()
                    } label: {
                        Text("Max")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color.accentColor)
                    }
                    .buttonStyle(.plain)
                    .disabled(clampedCount >= selectedCount)
                    .opacity(clampedCount >= selectedCount ? 0.35 : 1)
                    .accessibilityLabel("Quiz all \(selectedCount) selected verses")
                }
            }

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

    /// The card count, tappable to type a value directly instead of stepping there
    /// one press at a time. Always a `TextField` (rather than a label that swaps for
    /// one on tap) so tapping it focuses an already-mounted responder and the keypad
    /// opens on the first tap. It renders the live count whether or not it has
    /// focus, so the +/- buttons and Max keep working with the keypad up.
    private var countField: some View {
        TextField("", text: $countDraft)
            .keyboardType(.numberPad)
            .multilineTextAlignment(.center)
            .font(.system(size: 22, weight: .bold, design: .monospaced))
            .focused($countFieldFocused)
            // Fixed size: the field sits between the two stepper circles, and
            // letting it grow with the digit count shunted them sideways every
            // time the number crossed 10 or 100.
            .frame(width: 58, height: 32)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            // Sanitise and commit on every keystroke, so what the field shows is
            // always exactly what Start will use.
            //
            // Two things this guards against. `.numberPad` only limits what the
            // on-screen keyboard *offers* — a hardware keyboard, dictation or paste
            // can still put letters in, so non-digits are stripped as they arrive.
            // And committing only when editing ended wasn't enough: tapping a pack
            // row doesn't resign focus, so the field could sit there reading "999"
            // while the session quietly still used the old number.
            .onChange(of: countDraft) { oldValue, newValue in
                // First digit typed after the count arrived from elsewhere replaces
                // it rather than extending it: tap the field showing 15, type "8",
                // get 8 — not 158. Gated on the anchor still being what's on screen,
                // so a +/- or Max tap made mid-edit isn't mistaken for that keystroke.
                var incoming = newValue
                if let anchor = countReplaceAnchor, oldValue == anchor,
                   newValue.count > anchor.count, newValue.hasPrefix(anchor) {
                    incoming = String(newValue.dropFirst(anchor.count))
                    countReplaceAnchor = nil
                }
                var digits = String(incoming.filter(\.isNumber).prefix(4))
                if let typed = Int(digits) {
                    let clamped = max(1, min(typed, max(1, selectedCount)))
                    // Rewrite the field too, so it can never display a count that's
                    // out of range for the current selection.
                    if clamped != typed { digits = "\(clamped)" }
                    quizCount = clamped
                }
                // An empty field mid-edit is fine — `commitCountEdit` restores a
                // valid number when focus leaves.
                if digits != newValue { countDraft = digits }
            }
            .onChange(of: countFieldFocused) { _, focused in
                if focused {
                    // Keep the number visible while editing (it's what +/- and Max
                    // drive); the next keystroke swaps it out.
                    countDraft = "\(clampedCount)"
                    countReplaceAnchor = "\(clampedCount)"
                } else {
                    countReplaceAnchor = nil
                    commitCountEdit()
                }
            }
            .onChange(of: clampedCount) { _, newValue in
                // Any count change that didn't come from typing — +/-, Max, or the
                // selection shrinking under it. The field tracks it even while
                // focused, so what's displayed is always what Start will use.
                guard countDraft != "\(newValue)" else { return }
                countDraft = "\(newValue)"
                if countFieldFocused { countReplaceAnchor = "\(newValue)" }
            }
            .onAppear { countDraft = "\(clampedCount)" }
            // Just "Done" — a number pad has no return key, so something has to
            // dismiss it. "Max" used to sit here too, duplicating the one in the
            // bar below: that one deliberately keeps working with the keypad up
            // (the field tracks the count whether or not it has focus), so the
            // toolbar copy only ever covered the row it was copying.
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { countFieldFocused = false }
                }
            }
            .accessibilityLabel("Cards to quiz")
            .accessibilityValue("\(clampedCount)")
            .accessibilityHint("Tap to type a number")
    }

    // MARK: - Actions

    /// Single write path for the card count from anything that isn't typing (+/-,
    /// Max). Pushes the clamped value into the field too, so the number on screen
    /// and the number Start will use never drift apart — including while the
    /// keypad is up.
    private func setCount(_ value: Int) {
        let clamped = max(1, min(value, max(1, selectedCount)))
        quizCount  = clamped
        countDraft = "\(clamped)"
        countReplaceAnchor = countFieldFocused ? "\(clamped)" : nil
    }

    /// Applies a typed card count, clamped to 1...selected. An empty or unparseable
    /// draft (tapped in, then out) falls back to the count already in effect.
    private func commitCountEdit() {
        let digits = countDraft.filter(\.isNumber)
        if let typed = Int(digits), typed >= 1 {
            quizCount = max(1, min(typed, max(1, selectedCount)))
        }
        countDraft = "\(clampedCount)"
    }

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

    /// Discard saved in-progress session (swipe or equivalent).
    private func dismissSavedSession() {
        savedSession = nil
        UserDefaults.standard.removeObject(forKey: Self.savedSessionKey)
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
        quizCount = max(1, min(quizCount, selectedVerseIds.count))
    }
}

#Preview {
    NavigationStack { TestSetupView() }
}
