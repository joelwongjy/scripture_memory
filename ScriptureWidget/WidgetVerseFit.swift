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
/// The base sizes are the *designed* sizes for the family: a widget is glanceable
/// UI, not a poster, so the block is only ever scaled **down**, never up. A short
/// verse renders at the same type scale as a long one and simply leaves the slack
/// as whitespace — which is what keeps a two-line verse and a sixty-word verse
/// looking like the same widget. Every size and gap moves by one factor so the
/// title never ends up reading as a caption on its own body text.
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
    /// Ceiling on the scale factor.
    ///
    /// 1.0 — never grow — left a two-line verse sitting in half a card of empty
    /// space, which is its own kind of hard to read. 1.55 is what made the type
    /// read as a poster. 1.2 lets a short verse take the room it's given without
    /// the title outgrowing `title2`, the largest style that still looks like
    /// widget furniture rather than a headline.
    var maxScale:    CGFloat = 1.2

    /// Floor on the scale, expressed as a *point size* rather than a ratio.
    ///
    /// A fixed ratio was wrong: 0.78 of the small family's verse size is 9.4pt,
    /// under the 11pt Apple gives as the smallest legible size at arm's length.
    /// Stated this way the floor means the same thing on every family, and a
    /// verse too long to fit at 11pt truncates rather than shrinking past it.
    var minPointSize: CGFloat = 11

    private var minScale: CGFloat { min(maxScale, minPointSize / baseVerse) }

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
                    .font(.system(size: baseRef * k, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1).minimumScaleFactor(0.8)
                Spacer().frame(height: gap2 * k)
                Text(verse)
                    .font(.system(size: baseVerse * k, design: .serif))
                    .foregroundStyle(.primary)
                    .lineSpacing(lineSpacing * k)
                    // Past the shrink floor, truncate rather than keep scaling —
                    // the HIG asks for legible text, not complete text.
                    .minimumScaleFactor(0.9)
                    .truncationMode(.tail)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private func scale(width: CGFloat, height: CGFloat) -> CGFloat {
        guard width > 1, height > 1 else { return 1 }
        if totalHeight(scale: maxScale, width: width) <= height { return maxScale }
        var lo = minScale, hi = maxScale
        for _ in 0..<12 {
            let mid = (lo + hi) / 2
            if totalHeight(scale: mid, width: width) <= height { lo = mid } else { hi = mid }
        }
        return lo
    }
}
