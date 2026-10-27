import SwiftUI

// MARK: - Verse Text Fitting

/// Measure-to-fit sizing for verse body text. Replaces the old word-count
/// heuristic: finds the largest font size whose *rendered* height fits the
/// space the card layout actually leaves, so short verses grow to fill the card
/// and long verses shrink just enough to never truncate.
enum VerseFit {
    /// Rendered height of `text` at `size` in `style` with `lineSpacing`, wrapped to `width`.
    static func height(_ text: String, width: CGFloat, size: CGFloat,
                       style: CardFont.Style = .body, lineSpacing: CGFloat) -> CGFloat {
        guard width > 1 else { return .greatestFiniteMagnitude }
        let font = CardFont.uiFont(style, size: size)
        let para = NSMutableParagraphStyle()
        para.lineSpacing = lineSpacing
        let rect = (text as NSString).boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font, .paragraphStyle: para], context: nil)
        return ceil(rect.height)
    }

    /// Largest font size in [minSize, maxSize] whose text fits within `width × height`.
    /// Snaps to a 0.5pt grid. Returns `minSize` if even that overflows (so the
    /// floor governs readability; it won't go smaller).
    @MainActor
    static func fontSize(_ text: String, width: CGFloat, height: CGFloat,
                         style: CardFont.Style = .body, lineSpacing: CGFloat,
                         minSize: CGFloat, maxSize: CGFloat) -> CGFloat {
        guard width > 1, height > 1, !text.isEmpty else { return maxSize }
        let key = "\(style)|\(width)|\(height)|\(lineSpacing)|\(minSize)|\(maxSize)|\(text)"
        if let size = sizes[key] { return size }
        let size = search(text, width: width, height: height, style: style,
                          lineSpacing: lineSpacing, minSize: minSize, maxSize: maxSize)
        sizes[key] = size
        return size
    }

    /// Sizes already worked out: the same card at the same size always fits the
    /// same way, and a scrolling list asks again for every card it lays out.
    @MainActor private static var sizes: [String: CGFloat] = [:]

    private static func search(_ text: String, width: CGFloat, height: CGFloat,
                               style: CardFont.Style, lineSpacing: CGFloat,
                               minSize: CGFloat, maxSize: CGFloat) -> CGFloat {
        if Self.height(text, width: width, size: maxSize, style: style, lineSpacing: lineSpacing) <= height { return maxSize }
        var lo = minSize, hi = maxSize
        for _ in 0..<12 {
            let mid = (lo + hi) / 2
            if Self.height(text, width: width, size: mid, style: style, lineSpacing: lineSpacing) <= height {
                lo = mid
            } else {
                hi = mid
            }
        }
        return (lo * 2).rounded(.down) / 2
    }
}

/// Renders verse body text at the largest size that fills its allotted space
/// without truncating, closing up the line spacing before it shrinks the type. Measures its own allocated geometry, so it adapts to
/// whatever height the surrounding card layout leaves for it.
struct FittedVerseText: View {
    let text:        String
    let lineSpacing: CGFloat
    let minSize:     CGFloat
    let maxSize:     CGFloat
    var style:       CardFont.Style = .body
    var closingLine: String? = nil

    var body: some View {
        GeometryReader { geo in
            let tight = lineSpacing * 0.3
            let estimate = VerseFit.fontSize(text, width: geo.size.width, height: geo.size.height,
                                             style: style, lineSpacing: tight,
                                             minSize: minSize, maxSize: maxSize)
            ViewThatFits(in: .vertical) {
                verse(maxSize, lineSpacing).fixedSize(horizontal: false, vertical: true)
                ForEach(Array(stride(from: min(maxSize, estimate + 2), to: minSize, by: -0.5)), id: \.self) { size in
                    verse(size, tight).fixedSize(horizontal: false, vertical: true)
                }
                verse(minSize, tight).minimumScaleFactor(0.5)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private func verse(_ size: CGFloat, _ spacing: CGFloat) -> some View {
        VStack(alignment: .trailing, spacing: spacing) {
            Text(text)
                .lineSpacing(spacing)
                .frame(maxWidth: .infinity, alignment: .leading)
            if let closingLine { Text(closingLine) }
        }
        .font(CardFont.font(style, size: size))
    }
}
