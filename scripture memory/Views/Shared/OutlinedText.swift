import SwiftUI

// MARK: - Outlined Text

/// Hollow lettering — the printed "242" on a DEP pack is an outline, not a solid.
///
/// SwiftUI can't stroke a `Text`, so this draws the glyphs eight times in the
/// stroke colour, nudged one width in each direction, then lays a solid copy in
/// the field colour on top. What's left visible is the rim.
struct OutlinedText: View {
    let text:   String
    let font:   Font
    let stroke: Color
    /// Must match whatever sits behind, since the fill is what hollows the glyph.
    let fill:   Color
    var width:  CGFloat = 1.6

    private static let directions: [(CGFloat, CGFloat)] = [
        (-1, -1), (0, -1), (1, -1),
        (-1,  0),          (1,  0),
        (-1,  1), (0,  1), (1,  1),
    ]

    var body: some View {
        ZStack {
            ForEach(Array(Self.directions.enumerated()), id: \.offset) { _, d in
                Text(text).font(font).foregroundStyle(stroke)
                    .offset(x: d.0 * width, y: d.1 * width)
            }
            Text(text).font(font).foregroundStyle(fill)
        }
        .fixedSize()
    }
}
