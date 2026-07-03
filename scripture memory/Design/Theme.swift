import SwiftUI

/// The "Illuminated" design language — ink, parchment, lapis and gold leaf.
/// See docs/DESIGN.md for the intent behind each token. Views should reach for
/// these semantic names instead of raw `.red` / `.green` / `.blue` / `.orange`.
enum Theme {

    // MARK: - Palette

    /// Gold leaf — streaks and celebration only. Never used for navigation
    /// or interactive tint; gold marks achievement.
    static let gold = dynamic(light: (0.659, 0.502, 0.165), dark: (0.886, 0.765, 0.388))

    /// The hotter top of the streak-flame gradient.
    static let flame = dynamic(light: (0.851, 0.478, 0.180), dark: (0.929, 0.627, 0.314))

    /// Correct words, completed sections, the Good grade.
    static let success = dynamic(light: (0.184, 0.561, 0.353), dark: (0.341, 0.784, 0.549))

    /// Wrong words, the Again grade, destructive moments.
    static let error = dynamic(light: (0.769, 0.271, 0.227), dark: (0.922, 0.447, 0.392))

    /// The Hard grade and other caution states.
    static let warning = dynamic(light: (0.710, 0.478, 0.118), dark: (0.910, 0.659, 0.259))

    /// The sheen color swept across gold moments by the `giltSheen` shader —
    /// pre-multiplied intent: rgb is the sheen tint, alpha its peak strength.
    static let sheen = Color(red: 1.0, green: 0.94, blue: 0.78).opacity(0.55)

    // MARK: - Gradients

    /// Primary-action fill. A gentle top-lit falloff of the accent color so
    /// big buttons feel dimensional instead of flat-poster.
    static let accentGradient = LinearGradient(
        colors: [Color.accentColor.lightened(by: 0.10), Color.accentColor.lightened(by: -0.06)],
        startPoint: .top, endPoint: .bottom
    )

    /// Streak flame: hot orange falling into gold leaf.
    static let flameGradient = LinearGradient(
        colors: [flame, gold],
        startPoint: .top, endPoint: .bottom
    )

    /// Success-action fill (Mark as Complete and friends).
    static let successGradient = LinearGradient(
        colors: [success.lightened(by: 0.06), success.lightened(by: -0.06)],
        startPoint: .top, endPoint: .bottom
    )

    // MARK: - Helpers

    /// A dynamic color from light/dark sRGB triplets.
    private static func dynamic(light: (Double, Double, Double),
                                dark: (Double, Double, Double)) -> Color {
        Color(uiColor: UIColor { tc in
            let c = tc.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: c.0, green: c.1, blue: c.2, alpha: 1)
        })
    }
}

extension Color {
    /// Nudges brightness up (positive) or down (negative) — used to build
    /// gradient stops from a single semantic color so light/dark variants
    /// stay in step automatically.
    func lightened(by amount: Double) -> Color {
        let base = UIColor(self)
        return Color(uiColor: UIColor { tc in
            var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            base.resolvedColor(with: tc).getHue(&h, saturation: &s, brightness: &b, alpha: &a)
            return UIColor(hue: h, saturation: s,
                           brightness: min(1, max(0, b + CGFloat(amount))), alpha: a)
        })
    }
}

// MARK: - Parchment surface

/// The flashcard surface: warm parchment with a faint top-lit gradient and a
/// Metal paper-grain layer. One shared view so every card in the app (study,
/// review, submit, peek, Home spotlight) is cut from the same sheet.
struct ParchmentSurface: View {
    var cornerRadius: CGFloat = AppLayout.cardRadius

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        let top    = scheme == .dark ? Color(white: 0.155) : Color(red: 0.985, green: 0.972, blue: 0.945)
        let bottom = scheme == .dark ? Color(white: 0.118) : Color(red: 0.965, green: 0.947, blue: 0.910)
        shape
            .fill(LinearGradient(colors: [top, bottom], startPoint: .top, endPoint: .bottom))
            // Texture, not decoration: a couple of percent of luminance noise
            // that reads as paper tooth. Lower in dark mode, where noise turns
            // to static faster.
            .paperGrain(strength: scheme == .dark ? 0.018 : 0.032)
            .overlay(
                shape.strokeBorder(
                    scheme == .dark
                        ? Color.white.opacity(0.07)
                        : Color(red: 0.72, green: 0.66, blue: 0.55).opacity(0.35),
                    lineWidth: 0.5
                )
            )
            // Tight contact shadow + soft ambient — cards sit on the desk,
            // they don't float.
            .shadow(color: .black.opacity(0.05), radius: 1.5, x: 0, y: 1)
            .shadow(color: .black.opacity(scheme == .dark ? 0.35 : 0.10), radius: 14, x: 0, y: 7)
    }
}

// MARK: - Button styles

extension Theme {
    /// The one shared press behavior for primary buttons: a quick, slightly
    /// bouncy settle. Cards keep the gentler `CardButtonStyle`.
    struct SpringyButtonStyle: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
                .opacity(configuration.isPressed ? 0.9 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.65), value: configuration.isPressed)
        }
    }
}

/// A filled primary action: accent-gradient capsule-ish rectangle with the
/// shared springy press. Label view is caller-supplied so icons work.
struct ProminentActionButton<Label: View>: View {
    var gradient: LinearGradient = Theme.accentGradient
    let action: () -> Void
    @ViewBuilder let label: () -> Label

    var body: some View {
        Button(action: action) {
            label()
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: AppLayout.controlRadius + 2, style: .continuous)
                        .fill(gradient)
                        .shadow(color: .black.opacity(0.12), radius: 5, x: 0, y: 3)
                )
                .contentShape(RoundedRectangle(cornerRadius: AppLayout.controlRadius + 2, style: .continuous))
        }
        .buttonStyle(Theme.SpringyButtonStyle())
    }
}
