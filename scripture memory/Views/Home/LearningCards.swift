import SwiftUI

/// A verse resolved to its place in the visible packs.
struct LearningSpot {
    let verse: Verse
    let pack: Pack
    let indexInPack: Int
    /// Featured because the user pinned it, rather than being the learning cursor.
    let isPinned: Bool
}

/// Home's featured verse: the pinned one, else the current learning verse.
/// Tapping the verse opens it to practise.
struct ContinueLearningCard: View {
    let spot: LearningSpot
    let startMode: HomeVerseStartMode
    let onOpen: () -> Void
    let onChangePin: () -> Void
    let onUnpin: () -> Void

    @ObservedObject private var learning = LearningStore.shared

    var body: some View {
        let v = spot.verse
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                if spot.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 15, weight: .bold))
                }
                Text(spot.isPinned ? "Pinned" : "Continue Learning")
                    .font(.title3.weight(.bold))
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Text("\(spot.indexInPack + 1) of \(spot.pack.verses.count)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                pinButton
            }
            .padding(.horizontal, 20)

            Button(action: onOpen) {
                GeometryReader { geo in
                    PouchVerseCard(verse: v, isLearnt: learning.isLearnt(v), width: geo.size.width) {
                        HStack(spacing: 3) {
                            Text(startMode.ctaLabel)
                                .fontWeight(.semibold)
                            Image(systemName: "chevron.right")
                                .imageScale(.small)
                                .fontWeight(.semibold)
                        }
                        .foregroundStyle(Color.accentColor)
                    }
                    .paperAppearance()
                }
                .aspectRatio(AppLayout.cardAspect, contentMode: .fit)
                .listCardShadow()
            }
            .buttonStyle(CardButtonStyle())
            .contentShape(.contextMenuPreview, RoundedRectangle(cornerRadius: 2, style: .continuous))
            .contextMenu { pinActions }
            .accessibilityLabel("\(startMode.ctaLabel) \(v.book) \(v.reference)")
        }
        .frame(maxWidth: 600)
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var pinActions: some View {
        if spot.isPinned {
            Button(action: onChangePin) {
                Label("Change verse", systemImage: "pin")
            }
            Button {
                onUnpin()
                HapticEngine.light()
            } label: {
                Label("Unpin verse", systemImage: "pin.slash")
            }
        } else {
            Button(action: onChangePin) {
                Label("Pin a verse", systemImage: "pin")
            }
        }
    }

    private var pinButton: some View {
        Button(action: onChangePin) {
            Text(spot.isPinned ? "Change" : "Pin")
                .font(.system(size: 15))
                .foregroundStyle(Color.accentColor)
                .frame(minWidth: 44, minHeight: 44, alignment: .trailing)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.vertical, -12)
        .accessibilityLabel(spot.isPinned ? "Change pinned verse" : "Pin a verse")
    }
}

/// Shortcut back to the learning cursor, shown under the card while a different
/// verse is pinned, so it reads as its own action.
struct GoToCurrentVerseCard: View {
    let verse: Verse
    let onOpen: () -> Void

    var body: some View {
        Button {
            onOpen()
            HapticEngine.light()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "arrow.turn.down.right")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Go to current verse")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text("\(verse.book) \(verse.reference)")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                RowChevron()
            }
            .padding(.horizontal, AppLayout.panelPadding)
            .padding(.vertical, AppLayout.panelRowPadding)
            .frame(maxWidth: .infinity)
            .groupedPanel()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Go to current verse, \(verse.book) \(verse.reference)")
    }
}

/// Replaces the learning card once every verse is learnt.
struct AllLearntCard: View {
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 26))
                .foregroundStyle(.green)
            VStack(alignment: .leading, spacing: 2) {
                Text("Every verse learnt")
                    .font(.system(size: 16, weight: .semibold))
                Text("Keep them sharp in Daily Review below.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(AppLayout.cardPadding)
        .frame(maxWidth: .infinity)
        .groupedPanel()
    }
}
