import SwiftUI

// MARK: - Color

extension Color {
    /// Initialises a Color from a 6-digit hex string, with or without a leading `#`.
    init?(hex: String) {
        var h = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if h.hasPrefix("#") { h.removeFirst() }
        guard h.count == 6, let val = UInt64(h, radix: 16) else { return nil }
        self.init(
            red:   Double((val >> 16) & 0xFF) / 255,
            green: Double((val >> 8)  & 0xFF) / 255,
            blue:  Double( val        & 0xFF) / 255
        )
    }

    /// The same hue, darker. Unlike `muted` this keeps the saturation, so it
    /// reads as a shadow of the colour rather than a wash of it — for bands and
    /// panels that sit on a coloured field.
    func darkened(by amount: Double) -> Color {
        let uic = UIColor(self)
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uic.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return Color(hue: Double(h), saturation: Double(s),
                     brightness: Double(b) * (1 - amount))
    }

    /// The same hue mixed `amount` of the way toward white — a print "tint" of
    /// the colour. Unlike raising brightness this drops saturation too, so a
    /// deep violet lightens to periwinkle rather than to a glowing lilac.
    func lightened(by amount: Double) -> Color {
        let uic = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uic.getRed(&r, green: &g, blue: &b, alpha: &a)
        let t = CGFloat(max(0, min(1, amount)))
        return Color(red:   Double(r + (1 - r) * t),
                     green: Double(g + (1 - g) * t),
                     blue:  Double(b + (1 - b) * t))
    }

    /// A desaturated, darker variant suitable for muted pack-cover backgrounds.
    var muted: Color {
        let uic = UIColor(self)
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uic.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return Color(hue: Double(h), saturation: Double(s * 0.55), brightness: Double(b * 0.7))
    }
}
