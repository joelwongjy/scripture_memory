import SwiftUI

// MARK: - Packs in Review

/// Dedicated screen for choosing which packs are included in Daily Review.
/// Every pack is on by default; this is the rarely-needed place to turn some off.
/// Each pack shows what it has waiting, like Anki's deck list.
struct PacksReviewView: View {
    @AppStorage(BibleVersion.storageKey) private var bibleVersion: BibleVersion = .niv84
    @ObservedObject private var store     = SRSStore.shared
    @ObservedObject private var packPrefs = PackPreferencesStore.shared
    @AppStorage(NewCardCap.amountKey) private var newCapAmount: Int        = NewCardCap.fallback.amount
    @AppStorage(NewCardCap.unitKey)   private var newCapUnit:   NewCapUnit = NewCardCap.fallback.unit
    @AppStorage(NewCardCap.dailyReviewCapKey) private var dailyReviewCap: Int = NewCardCap.dailyReviewCapDefault

    private static let columnWidth: CGFloat = 36

    private var packs: [Pack] { packPrefs.visible(from: bibleVersion.packs) }

    var body: some View {
        List {
            let today = todaysReview
            Section {
                columnHeadings
                ForEach(packs) { pack in
                    Toggle(isOn: Binding(
                        get: { store.isActive(pack.name) },
                        set: { store.setActive(pack.name, $0) }
                    )) {
                        HStack(spacing: 8) {
                            PackRowLabel(pack: pack, titleLineLimit: 2)
                            Spacer(minLength: 0)
                            waiting(in: pack, today: today)
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

    /// New, Learn and Due over the pack rows' numbers, like the column titles
    /// on Anki's deck list. A hidden switch keeps the columns lined up.
    private var columnHeadings: some View {
        HStack(spacing: 8) {
            Spacer(minLength: 0)
            HStack(spacing: 0) {
                ForEach(["New", "Learn", "Due"], id: \.self) { title in
                    Text(title).frame(width: Self.columnWidth)
                }
            }
            Toggle("", isOn: .constant(true)).labelsHidden().hidden()
        }
        .font(.caption.weight(.medium))
        .foregroundStyle(.secondary)
        .frame(height: 12)
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(top: 10, leading: 20, bottom: 0, trailing: 20))
        .accessibilityHidden(true)
    }

    /// New (blue), Learn (red) and Due (green), with zeros greyed as on Home.
    /// Each pack shows its share of today's actual review, so the rows add up
    /// to Home's counts and a switched-off pack shows nothing.
    private func waiting(in pack: Pack, today: [Verse]) -> some View {
        let keys = Set(pack.verses.map(\.srsKey))
        let mine = today.filter { keys.contains($0.srsKey) }
        let learnt = LearningStore.shared.learntKeys
        let new = mine.filter { store.state(for: $0) == nil && !learnt.contains($0.srsKey) }.count
        let learn = mine.filter { store.state(for: $0)?.phase == .learning }.count
        let review = mine.count - new - learn
        return HStack(spacing: 0) {
            column(new, ReviewColor.new)
            column(learn, ReviewColor.learn)
            column(review, ReviewColor.due)
        }
        .font(.system(size: 15, weight: .semibold, design: .rounded))
        .monospacedDigit()
        .opacity(store.isActive(pack.name) ? 1 : 0.4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(new) new, \(learn) learning, \(review) due")
    }

    private var todaysReview: [Verse] {
        SRSQueueBuilder.buildAllPacksSession(
            packs: store.activePacks(packs), store: store,
            newCap: NewCardCap(amount: newCapAmount, unit: newCapUnit),
            dailyReviewCap: dailyReviewCap)
    }

    private func column(_ value: Int, _ color: Color) -> some View {
        Text("\(value)")
            .foregroundStyle(value > 0 ? color : Color(.tertiaryLabel))
            .frame(width: Self.columnWidth)
    }
}
