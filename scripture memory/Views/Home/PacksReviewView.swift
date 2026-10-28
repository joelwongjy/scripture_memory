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
    /// New and Due are what the pack would serve today, so neither passes the
    /// shared daily limits, as on Anki's deck list. Due includes learnt verses
    /// that haven't had a first review yet.
    private func waiting(in pack: Pack) -> some View {
        let policy = SRSQueueBuilder.NewCardPolicy.current
        let due = store.dueCards(in: pack.verses)
        let learn = due.filter { store.state(for: $0)?.phase == .learning }.count
        let reviewLeft = max(0, dailyReviewCap - store.reviewedToday(now: Date()))
        let review = min(due.count - learn + policy.known(in: pack.verses, store: store).count, reviewLeft)
        let remaining = SRSQueueBuilder.globalNewRemaining(
            store: store, newCap: NewCardCap(amount: newCapAmount, unit: newCapUnit))
        let new = min(policy.fresh(in: pack.verses, store: store).count, remaining)
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

    private func column(_ value: Int, _ color: Color) -> some View {
        Text("\(value)")
            .foregroundStyle(value > 0 ? color : Color(.tertiaryLabel))
            .frame(width: Self.columnWidth)
    }
}
