import SwiftUI

// MARK: - Verse Text Fitting

/// Measure-to-fit sizing for verse body text. Replaces the old word-count
/// heuristic: finds the largest font size whose *rendered* height fits the
/// space the card layout actually leaves, so short verses grow to fill the card
/// and long verses shrink just enough to never truncate.
enum VerseFit {
    /// Rendered height of `text` at `size` (serif) with `lineSpacing`, wrapped to `width`.
    static func height(_ text: String, width: CGFloat, size: CGFloat,
                       weight: UIFont.Weight = .regular, lineSpacing: CGFloat) -> CGFloat {
        guard width > 1 else { return .greatestFiniteMagnitude }
        var font = UIFont.systemFont(ofSize: size, weight: weight)
        if let d = font.fontDescriptor.withDesign(.serif) { font = UIFont(descriptor: d, size: size) }
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
    static func fontSize(_ text: String, width: CGFloat, height: CGFloat,
                         weight: UIFont.Weight = .regular, lineSpacing: CGFloat,
                         minSize: CGFloat, maxSize: CGFloat) -> CGFloat {
        guard width > 1, height > 1, !text.isEmpty else { return maxSize }
        if Self.height(text, width: width, size: maxSize, weight: weight, lineSpacing: lineSpacing) <= height { return maxSize }
        var lo = minSize, hi = maxSize
        for _ in 0..<12 {
            let mid = (lo + hi) / 2
            if Self.height(text, width: width, size: mid, weight: weight, lineSpacing: lineSpacing) <= height {
                lo = mid
            } else {
                hi = mid
            }
        }
        return (lo * 2).rounded(.down) / 2
    }
}

/// Renders verse body text at the largest size that fills its allotted space
/// without truncating. Measures its own allocated geometry, so it adapts to
/// whatever height the surrounding card layout leaves for it.
struct FittedVerseText: View {
    let text:        String
    let lineSpacing: CGFloat
    let minSize:     CGFloat
    let maxSize:     CGFloat

    var body: some View {
        GeometryReader { geo in
            let size = VerseFit.fontSize(text, width: geo.size.width, height: geo.size.height,
                                         lineSpacing: lineSpacing, minSize: minSize, maxSize: maxSize)
            Text(text)
                .font(.system(size: size, design: .serif))
                .lineSpacing(lineSpacing)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}
