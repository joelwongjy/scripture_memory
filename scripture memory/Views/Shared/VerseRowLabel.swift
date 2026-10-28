import SwiftUI

/// The one way a verse is named in a list: the quiz picker, the starting-point
/// picker, the pin picker and search all use it.
///
/// ```
/// Hebrews 11:6
/// E-9 · Faith
/// [optional verse preview]
/// ```
///
/// Accessories (a checkmark, a pin, a favourite star, a disclosure chevron) go
/// in `trailing`; a selection control goes in `leading`.
struct VerseRowLabel<Leading: View, Trailing: View>: View {
    let verse: Verse
    var showsPreview = false
    var highlight: String? = nil
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
                        .lineLimit(1)
                    if let pinned = verse.pinnedVersion {
                        Text(pinned)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                Text(subtitle)
                    .font(Self.titleFont)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                if showsPreview {
                    preview
                        .font(Self.previewFont)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .padding(.top, 2)
                }
            }
            Spacer(minLength: 0)
            trailing
        }
        .multilineTextAlignment(.leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private var subtitle: String {
        guard let code = VerseNumbering.code(for: verse) else { return verse.title }
        return "\(code) · \(verse.title)"
    }

    private var preview: Text {
        let text = verse.verse
        guard let query = highlight?.trimmingCharacters(in: .whitespacesAndNewlines), !query.isEmpty,
              let first = text.range(of: query, options: [.caseInsensitive, .diacriticInsensitive])
        else { return Text(text) }

        var shown = text
        if text.distance(from: text.startIndex, to: first.lowerBound) > 50 {
            var start = text.index(first.lowerBound, offsetBy: -24)
            while start > text.startIndex, !text[text.index(before: start)].isWhitespace {
                start = text.index(before: start)
            }
            shown = "\u{2026}" + text[start...]
        }

        var attributed = AttributedString(shown)
        var from = attributed.startIndex
        while from < attributed.endIndex,
              let match = attributed[from...].range(of: query, options: [.caseInsensitive, .diacriticInsensitive]) {
            attributed[match].foregroundColor = .primary
            attributed[match].font = Self.previewFont.weight(.semibold)
            from = match.upperBound
        }
        return Text(attributed)
    }

    // MARK: Type scale, shared with `PackRowLabel` so pack and verse rows align.

    static var referenceFont: Font { .body.weight(.semibold) }
    static var titleFont:     Font { .subheadline }
    static var previewFont:   Font { .subheadline }
    static var accessorySpacing: CGFloat { 12 }
}

extension VerseRowLabel where Leading == EmptyView, Trailing == EmptyView {
    init(verse: Verse, showsPreview: Bool = false, highlight: String? = nil) {
        self.init(verse: verse, showsPreview: showsPreview, highlight: highlight,
                  leading: { EmptyView() }, trailing: { EmptyView() })
    }
}

extension VerseRowLabel where Leading == EmptyView {
    init(verse: Verse, showsPreview: Bool = false, highlight: String? = nil,
         @ViewBuilder trailing: () -> Trailing) {
        self.init(verse: verse, showsPreview: showsPreview, highlight: highlight,
                  leading: { EmptyView() }, trailing: trailing)
    }
}
