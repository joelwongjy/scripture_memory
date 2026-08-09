import SwiftUI
import UIKit

/// Measure-to-fit sizing for widget verse text.
///
/// The widget set every verse at a fixed point size with a `minimumScaleFactor`,
/// which only ever shrinks — so a long verse squeezed down to fit while a short
/// one stayed small with half the widget empty around it. This finds the largest
/// size that still fits the space the layout actually leaves, so short verses
/// grow into it. Same approach as `VerseFit` in the app, which is what the
/// flashcards use.
///
/// Duplicated rather than shared because the widget is a separate target with
/// its own bundle and can't see the app's sources — the same reason
/// `WidgetVerse` restates `Verse`.
enum WidgetVerseFit {

    /// Rendered height of `text` at `size` (serif) with `lineSpacing`, wrapped to `width`.
    static func height(_ text: String, width: CGFloat, size: CGFloat, lineSpacing: CGFloat) -> CGFloat {
        guard width > 1 else { return .greatestFiniteMagnitude }
        var font = UIFont.systemFont(ofSize: size)
        if let d = font.fontDescriptor.withDesign(.serif) { font = UIFont(descriptor: d, size: size) }
        let para = NSMutableParagraphStyle()
        para.lineSpacing = lineSpacing
        let rect = (text as NSString).boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font, .paragraphStyle: para], context: nil)
        return ceil(rect.height)
    }

    /// Largest size in `min...max` whose text fits `width × height`.
    static func fontSize(_ text: String, width: CGFloat, height: CGFloat,
                         lineSpacing: CGFloat, minSize: CGFloat, maxSize: CGFloat) -> CGFloat {
        guard width > 1, height > 1, !text.isEmpty else { return maxSize }
        if Self.height(text, width: width, size: maxSize, lineSpacing: lineSpacing) <= height { return maxSize }
        var lo = minSize, hi = maxSize
        for _ in 0..<12 {
            let mid = (lo + hi) / 2
            if Self.height(text, width: width, size: mid, lineSpacing: lineSpacing) <= height {
                lo = mid
            } else {
                hi = mid
            }
        }
        return (lo * 2).rounded(.down) / 2
    }
}

/// Height of a bold serif line (the title), wrapped and capped to `maxLines`.
private func measuredTitleHeight(_ text: String, width: CGFloat, size: CGFloat, maxLines: Int) -> CGFloat {
    var font = UIFont.systemFont(ofSize: size, weight: .bold)
    if let d = font.fontDescriptor.withDesign(.serif) { font = UIFont(descriptor: d, size: size) }
    let rect = (text as NSString).boundingRect(
        with: CGSize(width: width, height: .greatestFiniteMagnitude),
        options: [.usesLineFragmentOrigin, .usesFontLeading],
        attributes: [.font: font], context: nil)
    return ceil(min(rect.height, font.lineHeight * CGFloat(maxLines)))
}

/// Height of a plain line (the reference).
private func measuredLineHeight(_ size: CGFloat) -> CGFloat {
    ceil(UIFont.systemFont(ofSize: size).lineHeight)
}

/// The whole verse block — title, reference and body — scaled as one.
///
/// Sizing only the verse was half a fix: a three-word verse grew to fill the
/// widget while its own title and reference stayed put, so the block came out
/// bottom-heavy and the heading looked like a caption on its own text. Every
/// size and gap here moves by a single factor, chosen so the composed block
/// fills the height it's given — which is what keeps the proportions the same
/// as the flashcard whether the verse is three words or sixty.
struct FittedVerseBlock: View {
    let title:       String
    let reference:   String
    let verse:       String
    let baseTitle:   CGFloat
    let baseRef:     CGFloat
    let baseVerse:   CGFloat
    let gap1:        CGFloat
    let gap2:        CGFloat
    let lineSpacing: CGFloat
    let titleLines:  Int
    /// Ceiling on the scale factor. Without one a very short verse pushes the
    /// type to a size that reads as a poster rather than a widget.
    var maxScale:    CGFloat = 1.55

    // Broken into statements rather than one expression: as a single chained sum
    // of five calls the type checker gives up on it.
    private func totalHeight(scale k: CGFloat, width: CGFloat) -> CGFloat {
        let t: CGFloat = measuredTitleHeight(title, width: width, size: baseTitle * k, maxLines: titleLines)
        let r: CGFloat = measuredLineHeight(baseRef * k)
        let v: CGFloat = WidgetVerseFit.height(verse, width: width,
                                               size: baseVerse * k,
                                               lineSpacing: lineSpacing * k)
        let gaps: CGFloat = (gap1 * k) + (gap2 * k)
        return t + r + v + gaps
    }

    var body: some View {
        GeometryReader { geo in
            let k = scale(width: geo.size.width, height: geo.size.height)
            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(.system(size: baseTitle * k, weight: .bold, design: .serif))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineLimit(titleLines)
                    .minimumScaleFactor(0.8)
                Spacer().frame(height: gap1 * k)
                Text(reference)
                    .font(.system(size: baseRef * k))
                    .foregroundStyle(.primary)
                    .lineLimit(1).minimumScaleFactor(0.8)
                Spacer().frame(height: gap2 * k)
                Text(verse)
                    .font(.system(size: baseVerse * k, design: .serif))
                    .foregroundStyle(.primary)
                    .lineSpacing(lineSpacing * k)
                    .minimumScaleFactor(0.6)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private func scale(width: CGFloat, height: CGFloat) -> CGFloat {
        guard width > 1, height > 1 else { return 1 }
        if totalHeight(scale: maxScale, width: width) <= height { return maxScale }
        var lo: CGFloat = 0.6, hi = maxScale
        for _ in 0..<12 {
            let mid = (lo + hi) / 2
            if totalHeight(scale: mid, width: width) <= height { lo = mid } else { hi = mid }
        }
        return lo
    }
}
