import SwiftUI

/// The one way a verse is named in a list.
///
/// Every place that lists verses to pick from — the quiz picker, the starting-
/// point picker, the pin picker, search — used to draw its own row, and they
/// disagreed about which line led (reference or title), type sizes, and where
/// the card number went. This is the single layout they all use now:
///
/// ```
/// 1 John 5:11-12              5A-1
/// Assurance of Salvation
/// [optional one-line verse preview]
/// ```
///
/// Reference leads because it's how a verse is *named* — it's what you scan a
/// list for. The card's printed number sits at the trailing edge of that line
/// in monospace, where a code reads as a code. Accessories (a checkmark, a pin,
/// a favourite star, a disclosure chevron) go in `trailing`; a selection control
/// goes in `leading`.
struct VerseRowLabel<Leading: View, Trailing: View>: View {
    let verse: Verse
    /// Show a one-line preview of the verse text under the title.
    var showsPreview = false
    @ViewBuilder var leading:  Leading
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: Self.accessorySpacing) {
            leading
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(verse.book) \(verse.reference)")
                        .font(Self.referenceFont)
                        .foregroundStyle(.primary)
                    if let pinned = verse.pinnedVersion {
                        Text("(\(pinned))")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 4)
                    if let code = VerseNumbering.code(for: verse) {
                        Text(code)
                            .font(Self.codeFont)
                            .foregroundStyle(.secondary)
                    }
                }
                Text(verse.title)
                    .font(Self.titleFont)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                if showsPreview {
                    Text(verse.verse)
                        .font(Self.previewFont)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            trailing
        }
        .multilineTextAlignment(.leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    // MARK: Type scale — shared with `PackRowLabel` so pack and verse rows align.

    static var referenceFont: Font { .system(size: 15, weight: .semibold) }
    static var titleFont:     Font { .system(size: 13) }
    static var previewFont:   Font { .system(size: 12) }
    static var codeFont:      Font { .system(size: 11, weight: .bold, design: .monospaced) }
    static var accessorySpacing: CGFloat { 12 }
}

extension VerseRowLabel where Leading == EmptyView, Trailing == EmptyView {
    init(verse: Verse, showsPreview: Bool = false) {
        self.init(verse: verse, showsPreview: showsPreview, leading: { EmptyView() }, trailing: { EmptyView() })
    }
}

extension VerseRowLabel where Leading == EmptyView {
    init(verse: Verse, showsPreview: Bool = false, @ViewBuilder trailing: () -> Trailing) {
        self.init(verse: verse, showsPreview: showsPreview, leading: { EmptyView() }, trailing: trailing)
    }
}

/// A pack named in a list: name, then how many verses it holds. The trailing
/// slot carries whatever the list is for — a chosen verse, a pin, a toggle.
struct PackRowLabel<Trailing: View>: View {
    let pack: Pack
    /// Replaces the verse count — e.g. "3 of 12 verses" while picking.
    var detail: String? = nil
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: VerseRowLabel<EmptyView, EmptyView>.accessorySpacing) {
            VStack(alignment: .leading, spacing: 2) {
                Text(pack.name)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Text(detail ?? Self.verseCount(pack.verses.count))
                    .font(VerseRowLabel<EmptyView, EmptyView>.titleFont)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            trailing
        }
        .contentShape(Rectangle())
    }

    static func verseCount(_ n: Int) -> String { "\(n) \(n == 1 ? "verse" : "verses")" }
}

extension PackRowLabel where Trailing == EmptyView {
    init(pack: Pack, detail: String? = nil) {
        self.init(pack: pack, detail: detail, trailing: { EmptyView() })
    }
}

// MARK: - Row accessories

/// The tick that marks the chosen row in a single-choice list.
struct SelectionCheckmark: View {
    var body: some View {
        Image(systemName: "checkmark")
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(Color.accentColor)
            .accessibilityLabel("Selected")
    }
}

/// The circle-tick that marks an included row in a multi-choice list. `mixed`
/// is the "some of this group" state a pack header shows.
struct SelectionCircle: View {
    var isSelected: Bool
    var mixed = false
    var size: CGFloat = 20

    var body: some View {
        Image(systemName: isSelected ? "checkmark.circle.fill" : mixed ? "minus.circle.fill" : "circle")
            .font(.system(size: size))
            .foregroundStyle(isSelected || mixed ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.secondary))
            .accessibilityHidden(true)
    }
}

/// The disclosure chevron a tappable row ends with.
struct RowChevron: View {
    var body: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.tertiary)
            .accessibilityHidden(true)
    }
}
