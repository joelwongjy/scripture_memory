import SwiftUI

// MARK: - Packs in Review

/// Dedicated screen for choosing which packs are included in Daily Review.
/// Every pack is on by default; this is the rarely-needed place to turn some off.
struct PacksReviewView: View {
    @AppStorage("bibleVersion") private var bibleVersion: BibleVersion = .niv84
    @ObservedObject private var store     = SRSStore.shared
    @ObservedObject private var packPrefs = PackPreferencesStore.shared

    private var packs: [Pack] { packPrefs.visible(from: bibleVersion.packs) }

    var body: some View {
        List {
            Section {
                ForEach(packs) { pack in
                    Toggle(isOn: Binding(
                        get: { store.isActive(pack.name) },
                        set: { store.setActive(pack.name, $0) }
                    )) {
                        PackRowLabel(pack: pack)
                    }
                    .tint(.accentColor)
                }
            } header: {
                // Top, not footer — the tip is useless after a 15-pack scroll.
                // Footnote/secondary so it reads as a caption, not a heading.
                Text("All packs are reviewed by default. Turn one off to skip its verses in Daily Review.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .textCase(nil)
            }
        }
        .navigationTitle("Packs in Review")
        .navigationBarTitleDisplayMode(.inline)
    }
}
