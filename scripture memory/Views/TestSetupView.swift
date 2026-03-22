import SwiftUI

struct TestSetupView: View {

    @AppStorage("bibleVersion") private var bibleVersion: BibleVersion = .niv84

    @State private var selectedVerseIds: Set<Int>    = []
    @State private var expandedPackIds:  Set<String> = []
    @State private var quizCount:        Int         = 15
    @State private var activeSession:      TestSession? = nil
    @State private var savedSession:       TestSession? = nil
    @State private var showOverwriteAlert: Bool         = false

    private static let savedSessionKey = "lastTestSessionVerseIds"

    private var selectedCount: Int { selectedVerseIds.count }
    private var clampedCount:  Int { max(1, min(quizCount, selectedCount)) }

    var body: some View {
        VStack(spacing: 0) {
            // Resume banner — visually separate from the list
            if let session = savedSession, activeSession == nil {
                resumeBanner(session)
            }

            List {
            ForEach(bibleVersion.packs) { pack in
                DisclosureGroup(isExpanded: expansionBinding(for: pack)) {
                    ForEach(pack.verses) { verse in
                        verseRow(verse)
                    }
                } label: {
                    packLabel(pack)
                }
            }
        }
        .listStyle(.insetGrouped)
        }
        .navigationTitle("Review")
        .onAppear { loadSavedSession() }
        .alert("Existing Session", isPresented: $showOverwriteAlert) {
            Button("Keep Session", role: .cancel) { }
            Button("Start New", role: .destructive) { launchNewSession() }
        } message: {
            Text("You have an unfinished session. Starting a new one will overwrite it.")
        }
        .safeAreaInset(edge: .bottom) {
            if !selectedVerseIds.isEmpty {
                bottomBar
            }
        }
        .fullScreenCover(item: $activeSession) { session in
            NavigationStack {
                TestSessionView(session: session, onSessionEnded: clearSession)
                    .toolbar(.hidden, for: .navigationBar)
            }
        }
    }

    // MARK: - Resume Banner

    private func resumeBanner(_ session: TestSession) -> some View {
        HStack(spacing: 14) {
            Image(systemName: "play.circle.fill")
                .font(.system(size: 32))
                .foregroundColor(.blue)

            VStack(alignment: .leading, spacing: 3) {
                Text("Session in Progress")
                    .font(.system(size: 15, weight: .semibold))
                Text("\(session.verses.count) cards")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button {
                activeSession = savedSession
            } label: {
                Text("Resume")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.blue, in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(Color.blue.opacity(0.08))
        .overlay(Rectangle().fill(Color.blue.opacity(0.15)).frame(height: 1), alignment: .bottom)
    }

    // MARK: - Expansion Binding

    private func expansionBinding(for pack: Pack) -> Binding<Bool> {
        Binding(
            get: { expandedPackIds.contains(pack.id) },
            set: { isExpanded in
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    if isExpanded {
                        expandedPackIds.insert(pack.id)
                        // Auto-select all verses when expanding a pack for the first time
                        let packIds = Set(pack.verses.map(\.id))
                        if packIds.intersection(selectedVerseIds).isEmpty {
                            for verse in pack.verses { selectedVerseIds.insert(verse.id) }
                        }
                    } else {
                        expandedPackIds.remove(pack.id)
                    }
                }
            }
        )
    }

    // MARK: - Pack Label

    private func packLabel(_ pack: Pack) -> some View {
        let packVerseIds   = Set(pack.verses.map(\.id))
        let selectedInPack = packVerseIds.intersection(selectedVerseIds).count
        let allSelected    = selectedInPack == pack.verses.count && !pack.verses.isEmpty
        let someSelected   = selectedInPack > 0

        return HStack(spacing: 12) {
            // Checkbox — tap toggles select-all / deselect-all independently of expansion
            Button {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                    if allSelected {
                        for verse in pack.verses { selectedVerseIds.remove(verse.id) }
                    } else {
                        for verse in pack.verses { selectedVerseIds.insert(verse.id) }
                    }
                }
            } label: {
                Image(systemName: allSelected  ? "checkmark.circle.fill"
                                 : someSelected ? "minus.circle.fill"
                                 : "circle")
                    .font(.system(size: 22))
                    .foregroundColor(someSelected ? .blue : .secondary)
                    .animation(.spring(response: 0.2), value: someSelected)
                    .animation(.spring(response: 0.2), value: allSelected)
            }
            .buttonStyle(.plain)

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
        }
        .padding(.vertical, 4)
    }

    // MARK: - Verse Row

    private func verseRow(_ verse: Verse) -> some View {
        let isSelected = selectedVerseIds.contains(verse.id)
        return HStack(spacing: 12) {
            // Only the checkbox is the tap target
            Button {
                withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                    if isSelected { selectedVerseIds.remove(verse.id) }
                    else          { selectedVerseIds.insert(verse.id) }
                }
            } label: {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundColor(isSelected ? .blue : .secondary)
                    .animation(.spring(response: 0.2), value: isSelected)
                    .padding(.vertical, 4)
                    .padding(.trailing, 4)
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
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        HStack(spacing: 12) {
            // Selected count
            VStack(alignment: .leading, spacing: 1) {
                Text("\(selectedCount)")
                    .font(.system(size: 22, weight: .bold, design: .monospaced))
                    .foregroundColor(.primary)
                Text("verses")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .frame(minWidth: 55, alignment: .leading)

            Spacer()

            // Cards-to-quiz stepper
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

            // Start button
            Button {
                if savedSession != nil {
                    showOverwriteAlert = true
                } else {
                    launchNewSession()
                }
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
        var verses: [Verse] = []
        for pack in bibleVersion.packs {
            for verse in pack.verses where selectedVerseIds.contains(verse.id) {
                verses.append(verse)
            }
        }
        let shuffled = verses.shuffled()
        let session  = TestSession(verses: Array(shuffled.prefix(clampedCount)))
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
        let ids = session.verses.map(\.id)
        UserDefaults.standard.set(ids, forKey: Self.savedSessionKey)
    }

    private func loadSavedSession() {
        guard savedSession == nil,
              let ids = UserDefaults.standard.array(forKey: Self.savedSessionKey) as? [Int],
              !ids.isEmpty else { return }
        let idSet = Set(ids)
        var byId: [Int: Verse] = [:]
        for pack in bibleVersion.packs {
            for verse in pack.verses where idSet.contains(verse.id) {
                byId[verse.id] = verse
            }
        }
        let ordered = ids.compactMap { byId[$0] }
        if !ordered.isEmpty {
            savedSession = TestSession(verses: ordered)
        }
    }
}

#Preview {
    NavigationStack { TestSetupView() }
}
