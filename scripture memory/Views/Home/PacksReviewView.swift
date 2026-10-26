import SwiftUI

// MARK: - Packs in Review

/// Dedicated screen for choosing which packs are included in Daily Review.
/// Every pack is on by default; this is the rarely-needed place to turn some off.
/// Each pack shows what it has waiting, like Anki's deck list.
struct PacksReviewView: View {
    @AppStorage(BibleVersion.storageKey) private var bibleVersion: BibleVersion = .niv84
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
                        HStack(spacing: 8) {
                            PackRowLabel(pack: pack)
                            Spacer(minLength: 4)
                            waiting(in: pack)
                        }
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

    /// Learn (red) and Due (green): due cards plus verses you know that haven't
    /// had a review yet. Nothing shows for a pack with nothing waiting.
    @ViewBuilder
    private func waiting(in pack: Pack) -> some View {
        let due = store.dueCards(in: pack.verses)
        let learn = due.filter { store.state(for: $0)?.phase == .learning }.count
        let review = due.count - learn
            + SRSQueueBuilder.NewCardPolicy.current.known(in: pack.verses, store: store).count
        HStack(spacing: 10) {
            if learn > 0 { Text("\(learn)").foregroundStyle(ReviewColor.learn) }
            if review > 0 { Text("\(review)").foregroundStyle(ReviewColor.due) }
        }
        .font(.system(size: 15, weight: .semibold, design: .rounded))
        .monospacedDigit()
        .opacity(store.isActive(pack.name) ? 1 : 0.4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(learn + review == 0 ? "Nothing waiting" : "\(learn) learning, \(review) due")
    }
}
