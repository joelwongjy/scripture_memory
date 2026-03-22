import SwiftUI

struct TestSetupView: View {

    @AppStorage("bibleVersion") private var bibleVersion: BibleVersion = .niv84

    @State private var selectedVerseIds: Set<Int> = []
    @State private var testCount: Int = 15
    @State private var activeSession: TestSession? = nil

    private var selectedCount: Int { selectedVerseIds.count }
    private var clampedTestCount: Int { max(1, min(testCount, selectedCount)) }

    var body: some View {
        List {
            ForEach(bibleVersion.packs) { pack in
                Section {
                    ForEach(pack.verses) { verse in
                        Button {
                            toggleVerse(verse)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: selectedVerseIds.contains(verse.id)
                                      ? "checkmark.circle.fill"
                                      : "circle")
                                    .font(.system(size: 20))
                                    .foregroundColor(selectedVerseIds.contains(verse.id) ? .blue : .secondary)
                                    .animation(.spring(response: 0.25, dampingFraction: 0.7),
                                               value: selectedVerseIds.contains(verse.id))

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(verse.title)
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundColor(.primary)
                                    Text(verse.reference)
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    }
                } header: {
                    packSectionHeader(pack)
                }
            }
        }
        .navigationTitle("Review")
        .safeAreaInset(edge: .bottom) {
            if !selectedVerseIds.isEmpty {
                bottomBar
            }
        }
        .fullScreenCover(item: $activeSession) { session in
            NavigationStack {
                TestSessionView(session: session)
                    .toolbar(.hidden, for: .navigationBar)
            }
        }
    }

    // MARK: - Pack Section Header

    private func packSectionHeader(_ pack: Pack) -> some View {
        let packVerseIds = Set(pack.verses.map(\.id))
        let selectedInPack = packVerseIds.intersection(selectedVerseIds).count
        let allSelected = selectedInPack == pack.verses.count && !pack.verses.isEmpty

        return HStack {
            Text(pack.name)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)

            if selectedInPack > 0 {
                Text("(\(selectedInPack))")
                    .font(.system(size: 12))
                    .foregroundColor(.blue)
            }

            Spacer()

            Button {
                if allSelected {
                    deselectAll(in: pack)
                } else {
                    selectAll(in: pack)
                }
            } label: {
                Text(allSelected ? "Deselect All" : "Select All")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.blue)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        HStack(spacing: 16) {
            // Left: selected count
            Text("\(selectedCount) \(selectedCount == 1 ? "verse" : "verses")")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
                .frame(minWidth: 70, alignment: .leading)

            Spacer()

            // Center: test count stepper
            HStack(spacing: 8) {
                Text("Test")
                    .font(.system(size: 14, weight: .medium))

                Button {
                    if testCount > 1 { testCount -= 1 }
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 12, weight: .semibold))
                        .frame(width: 28, height: 28)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .buttonStyle(.plain)
                .disabled(clampedTestCount <= 1)
                .opacity(clampedTestCount <= 1 ? 0.4 : 1)

                Text("\(clampedTestCount)")
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .frame(minWidth: 28)

                Button {
                    if testCount < selectedCount { testCount += 1 }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .semibold))
                        .frame(width: 28, height: 28)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .buttonStyle(.plain)
                .disabled(clampedTestCount >= selectedCount)
                .opacity(clampedTestCount >= selectedCount ? 0.4 : 1)
            }

            Spacer()

            // Right: start button
            Button {
                startSession()
            } label: {
                Text("Start")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
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

    private func toggleVerse(_ verse: Verse) {
        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
            if selectedVerseIds.contains(verse.id) {
                selectedVerseIds.remove(verse.id)
            } else {
                selectedVerseIds.insert(verse.id)
            }
        }
    }

    private func selectAll(in pack: Pack) {
        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
            for verse in pack.verses { selectedVerseIds.insert(verse.id) }
        }
    }

    private func deselectAll(in pack: Pack) {
        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
            for verse in pack.verses { selectedVerseIds.remove(verse.id) }
        }
    }

    private func startSession() {
        // Collect verses from all packs in order, preserving within-pack order
        var selectedVerses: [Verse] = []
        for pack in bibleVersion.packs {
            for verse in pack.verses {
                if selectedVerseIds.contains(verse.id) {
                    selectedVerses.append(verse)
                }
            }
        }
        // Shuffle and take the first clampedTestCount
        let shuffled = selectedVerses.shuffled()
        let count = min(clampedTestCount, shuffled.count)
        let sessionVerses = Array(shuffled.prefix(count))
        activeSession = TestSession(verses: sessionVerses)
    }
}

#Preview {
    NavigationStack { TestSetupView() }
}
