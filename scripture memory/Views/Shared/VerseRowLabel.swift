import SwiftUI

/// The one way a verse is named in a list.
///
/// Every place that lists verses to pick from — the quiz picker, the starting-
/// point picker, the pin picker, search — used to draw its own row, and they
/// disagreed about which line led (reference or title), type sizes, and where
/// the card number went. This is the single layout they all use now:
///
/// ```
/// 5A-1   1 John 5:11-12
/// Assurance of Salvation
/// [optional one-line verse preview]
/// ```
///
/// The card's printed number leads, in monospace and its own column: picking
/// from a list, the number is what you're looking for — you remember which
/// card you were on, not which passage was printed on it. The reference names
/// it; the title says what it's about. Accessories (a checkmark, a pin, a
/// favourite star, a disclosure chevron) go in `trailing`; a selection control
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
                HStack(alignment: .center, spacing: 8) {
                    // The card's printed number leads: it's what you're looking
                    // for in a list you're picking from — you remember the card,
                    // not which passage was on it. A minimum width keeps the
                    // references flush down the list; a longer code widens it.
                    if let code = VerseNumbering.code(for: verse) {
                        Text(code)
                            .font(Self.codeFont)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .fixedSize()
                            .frame(minWidth: Self.codeColumnWidth, alignment: .leading)
                    }
                    Text("\(verse.book) \(verse.reference)")
                        .font(Self.referenceFont)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    if let pinned = verse.pinnedVersion {
                        Text("(\(pinned))")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
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

    /// Minimum width of the leading card-number column, so references align.
    /// A longer code (TMS 60's "TMS 60 A-10") pushes past it rather than being
    /// squeezed — alignment matters within a pack, where codes are equal length.
    static var codeColumnWidth: CGFloat { 44 }

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
