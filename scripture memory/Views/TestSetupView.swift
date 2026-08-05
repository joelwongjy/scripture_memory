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

    @State private var selectedVerseIds:  Set<Int>    = []
    @State private var expandedPackIds:   Set<String> = []
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

    // Flat items for packs + their expanded verses — driven by expandedPackIds
    private var packItems: [PackListItem] {
        var items: [PackListItem] = []
        for pack in packPrefs.visible(from: bibleVersion.packs) {
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
        .listStyle(.insetGrouped)
        .listSectionSpacing(savedSession == nil ? 12 : 22)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: expandedPackIds)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: savedSession != nil)
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Quiz")
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
        .safeAreaInset(edge: .bottom) {
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
                    .foregroundColor(.primary)
                Text("\(session.verses.count) cards · \(packsText)")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)
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

    // MARK: - Pack Header Row
    //
    // Three distinct zones:
    //   ① Checkbox button  — select/deselect all verses in this pack
    //   ② Pack name text   — non-interactive (tapping does nothing)
    //   ③ Chevron button   — the ONLY thing that expands/collapses
    //
    // Removing the auto-select-on-expand so the chevron only expands.

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
            } label: {
                Image(systemName: allSelected  ? "checkmark.circle.fill"
                                 : someSelected ? "minus.circle.fill"
                                 : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(someSelected ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.secondary))
                    .frame(width: 44, height: 50)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(allSelected ? "Deselect all verses in \(pack.name)" : "Select all verses in \(pack.name)")

            // ② Pack name — tapping selects/deselects all verses (does NOT expand)
            Button {
                if allSelected {
                    for verse in pack.verses { selectedVerseIds.remove(verse.id) }
                } else {
                    for verse in pack.verses { selectedVerseIds.insert(verse.id) }
                }
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(pack.name)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.primary)
                        Text(selectedInPack > 0
                             ? "\(selectedInPack) of \(pack.verses.count) verses"
                             : "\(pack.verses.count) verses")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // ③ Chevron — only expansion trigger, no selection side-effect
            Button {
                if isExpanded {
                    expandedPackIds.remove(pack.id)
                } else {
                    expandedPackIds.insert(pack.id)
                }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary)
                    .rotationEffect(isExpanded ? .degrees(90) : .zero)
                    .frame(width: 44, height: 50)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isExpanded ? "Collapse \(pack.name)" : "Expand \(pack.name) to pick individual verses")
        }
    }

    // MARK: - Verse Row

    private func verseRow(_ verse: Verse) -> some View {
        let isSelected = selectedVerseIds.contains(verse.id)
        return Button {
            if isSelected { selectedVerseIds.remove(verse.id) }
            else          { selectedVerseIds.insert(verse.id) }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 19))
                    .foregroundStyle(isSelected ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.secondary))

                VStack(alignment: .leading, spacing: 2) {
                    Text(verse.title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    Text("\(verse.book) \(verse.reference)")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
            .contentShape(Rectangle())
            .padding(.vertical, 2)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(verse.title), \(verse.book) \(verse.reference)")
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 1) {
                Text("\(selectedCount)")
                    .font(.system(size: 22, weight: .bold, design: .monospaced))
                Text("verses")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
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
                        .foregroundColor(.secondary)
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
        .padding(.horizontal, AppLayout.screenMargin)
        .padding(.vertical, 14)
        .background(Color(.systemBackground))
        .overlay(Rectangle().fill(Color(.separator).opacity(0.4)).frame(height: 0.5), alignment: .top)
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
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Button("Max (\(selectedCount))") {
                        setCount(selectedCount)
                        HapticEngine.light()
                    }
                    .disabled(selectedCount == 0)
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
