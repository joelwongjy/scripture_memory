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

    @State private var selectedVerseIds:  Set<Int>    = []
    @State private var expandedPackIds:   Set<String> = []
    @State private var quizCount:         Int         = 15
    @State private var activeSession:     TestSession? = nil
    @State private var savedSession:      TestSession? = nil
    @State private var showOverwriteAlert = false

    private static let savedSessionKey = "lastTestSessionVerseIds"

    private var selectedCount: Int { selectedVerseIds.count }
    private var clampedCount:  Int { max(1, min(quizCount, selectedCount)) }

    // Flat items for packs + their expanded verses — driven by expandedPackIds
    private var packItems: [PackListItem] {
        var items: [PackListItem] = []
        for pack in bibleVersion.packs {
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
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: expandedPackIds)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: savedSession != nil)
        .navigationTitle("Review")
        .onAppear { loadSavedSession() }
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
        HStack(spacing: 12) {
            Image(systemName: "play.circle.fill")
                .font(.system(size: 24))
                .foregroundColor(.blue)

            VStack(alignment: .leading, spacing: 1) {
                Text("Session in Progress")
                    .font(.system(size: 14, weight: .semibold))
                Text("\(session.verses.count) cards")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button { activeSession = savedSession } label: {
                Text("Resume")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(Color.blue, in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 6)
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
                    .foregroundColor(someSelected ? .blue : .secondary)
                    .animation(.spring(response: 0.2), value: allSelected)
                    .animation(.spring(response: 0.2), value: someSelected)
                    .frame(width: 44, height: 50)
            }
            .buttonStyle(.plain)

            // ② Pack name — plain, non-tappable
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

            // ③ Chevron — only expansion trigger, no selection side-effect
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    if isExpanded {
                        expandedPackIds.remove(pack.id)
                    } else {
                        expandedPackIds.insert(pack.id)
                    }
                }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary)
                    .rotationEffect(isExpanded ? .degrees(90) : .zero)
                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isExpanded)
                    .frame(width: 44, height: 50)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Verse Row

    private func verseRow(_ verse: Verse) -> some View {
        let isSelected = selectedVerseIds.contains(verse.id)
        return HStack(spacing: 10) {
            Button {
                if isSelected { selectedVerseIds.remove(verse.id) }
                else          { selectedVerseIds.insert(verse.id) }
            } label: {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 19))
                    .foregroundColor(isSelected ? .blue : .secondary)
                    .animation(.spring(response: 0.2), value: isSelected)
            }
            .buttonStyle(.plain)

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
        .padding(.vertical, 2)
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
                        if quizCount > 1 { quizCount -= 1 }
                    } label: {
                        Image(systemName: "minus")
                            .font(.system(size: 13, weight: .semibold))
                            .frame(width: 32, height: 32)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .disabled(clampedCount <= 1)
                    .opacity(clampedCount <= 1 ? 0.35 : 1)

                    Text("\(clampedCount)")
                        .font(.system(size: 22, weight: .bold, design: .monospaced))
                        .frame(minWidth: 36)

                    Button {
                        if quizCount < selectedCount { quizCount += 1 }
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 13, weight: .semibold))
                            .frame(width: 32, height: 32)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .disabled(clampedCount >= selectedCount)
                    .opacity(clampedCount >= selectedCount ? 0.35 : 1)
                }
                Text("cards to quiz")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button {
                if savedSession != nil { showOverwriteAlert = true }
                else                   { launchNewSession() }
            } label: {
                Text("Start")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 11)
                    .background(Color.blue, in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(.ultraThickMaterial)
        .overlay(Rectangle().fill(Color(.separator).opacity(0.4)).frame(height: 0.5), alignment: .top)
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
}

#Preview {
    NavigationStack { TestSetupView() }
}
