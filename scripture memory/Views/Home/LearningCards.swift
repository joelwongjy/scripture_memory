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

    var body: some View {
        let v = spot.verse
        VStack(alignment: .leading, spacing: 10) {
            // Header sits outside the practise button so the menu's taps don't
            // fight the card tap.
            HStack(spacing: 6) {
                if spot.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                Text(spot.isPinned ? "Pinned" : "Continue Learning")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Spacer()
                Text("\(spot.indexInPack + 1) of \(spot.pack.verses.count)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                pinMenu
            }

            Button(action: onOpen) {
                VStack(alignment: .leading, spacing: 10) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(v.title)
                            .font(.system(size: 16, weight: .bold, design: .serif))
                            .foregroundStyle(Color.primary)
                            .multilineTextAlignment(.leading)
                        Text("\(v.book) \(v.reference)")
                            .font(.system(size: 14, design: .serif))
                            .foregroundStyle(Color.secondary)
                        Text(v.verse)
                            .font(.system(size: 15, design: .serif))
                            .foregroundStyle(Color.primary)
                            .lineSpacing(4)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    HStack(spacing: 5) {
                        Text(spot.pack.name)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        Spacer()
                        Text(startMode.ctaLabel)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.accentColor)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.accentColor)
                    }
                    .padding(.top, 2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(CardButtonStyle())
            .accessibilityLabel("\(startMode.ctaLabel) \(v.book) \(v.reference)")
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: AppLayout.groupedRadius, style: .continuous)
                .fill(flashcardBackground)
                .shadow(color: .black.opacity(0.13), radius: 14, x: 0, y: 7)
                .shadow(color: .black.opacity(0.05), radius: 2,  x: 0, y: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppLayout.groupedRadius, style: .continuous)
                .strokeBorder(Color(.separator).opacity(0.4), lineWidth: 0.5)
        )
    }

    private var pinMenu: some View {
        Menu {
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
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.secondary)
                .contentShape(Rectangle())
        }
        .accessibilityLabel("Verse options")
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
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
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
        .padding(20)
        .frame(maxWidth: .infinity)
        .groupedPanel()
    }
}
