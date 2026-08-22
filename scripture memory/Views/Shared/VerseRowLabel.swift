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
