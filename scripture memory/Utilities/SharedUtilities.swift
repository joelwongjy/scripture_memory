import SwiftUI

// MARK: - String

extension String {
    /// Splits into non-empty words on single spaces, matching verse storage format.
    var wordTokens: [String] {
        components(separatedBy: " ").filter { !$0.isEmpty }
    }
}

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

    /// A desaturated, darker variant suitable for muted pack-cover backgrounds.
    var muted: Color {
        let uic = UIColor(self)
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uic.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return Color(hue: Double(h), saturation: Double(s * 0.55), brightness: Double(b * 0.7))
    }
}

// MARK: - Flashcard Style

extension View {
    /// Applies the standard card appearance: parchment background, rounded corners, shadows.
    func flashcardStyle() -> some View {
        self
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(flashcardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color(.separator).opacity(0.5), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.12), radius: 16, x: 0, y: 8)
            .shadow(color: .black.opacity(0.05), radius: 2,  x: 0, y: 1)
            .contentShape(RoundedRectangle(cornerRadius: 10))
    }
}

/// Adaptive parchment-style background shared by all card types.
let flashcardBackground = Color(uiColor: UIColor { tc in
    tc.userInterfaceStyle == .dark
        ? UIColor(white: 0.13, alpha: 1)
        : UIColor(red: 0.98, green: 0.965, blue: 0.94, alpha: 1)
})

// MARK: - Study chrome (top bar + scrubber)

extension Image {
    /// Neutral glass circle — close, list, reset, etc.
    func studyChromeCircleButton() -> some View {
        self
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.secondary)
            .frame(width: 36, height: 36)
            .background(.ultraThinMaterial, in: Circle())
            .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 2)
    }

    /// Prev/next chevrons beside the verse scrubber track.
    func studyScrubberChevronButton() -> some View {
        self
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.primary.opacity(0.7))
            .frame(width: 36, height: 36)
            .background(.ultraThinMaterial, in: Circle())
            .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 2)
    }

    /// Toggle controls (shuffle, layout) — blue when active.
    func studyChromeToggle(isOn: Bool) -> some View {
        self
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(isOn ? AnyShapeStyle(.white) : AnyShapeStyle(.secondary))
            .frame(width: 36, height: 36)
            .background(
                isOn ? AnyShapeStyle(Color.blue) : AnyShapeStyle(.ultraThinMaterial),
                in: Circle()
            )
            .shadow(
                color: isOn ? Color.blue.opacity(0.35) : Color.black.opacity(0.08),
                radius: isOn ? 8 : 6, x: 0, y: 2
            )
    }
}

// MARK: - Card Button Style

/// Press-to-scale feedback for tappable pack cards.
struct CardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}
