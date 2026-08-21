import SwiftUI

/// App-wide layout constants. One canonical horizontal screen margin so every
/// screen — pack grid, daily dashboard, settings list, and the immersive study
/// / review screens (card, chrome, and controls) — lines up to the same edge.
/// 16pt matches the iOS `.insetGrouped` list inset that Settings and Daily use.
enum AppLayout {
    static let screenMargin: CGFloat = 16
    /// Corner radius for content cards (flashcards, pack covers).
    static let cardRadius:    CGFloat = 10
    /// Corner radius for grouped-list containers (Daily hero / packs panels) —
    /// matched to the iOS 26 system `.insetGrouped` section corners so the Daily
    /// dashboard's white panels line up with Settings / Review.
    static let groupedRadius: CGFloat = 20
    /// Corner radius for buttons and control chips.
    static let controlRadius: CGFloat = 12
}

extension View {
    /// Clips to a continuous ("squircle") rounded rectangle — the iOS-standard
    /// corner style. Used app-wide so every card and control shares one corner
    /// shape instead of mixing `.continuous` with the default circular style
    /// (which made the Daily panels look subtly different from other screens).
    func roundedRect(_ radius: CGFloat) -> some View {
        clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
    }
}

/// The shared 48×48 control-button metrics used across the study/review bottom
/// bar (mic, keyboard-dismiss, peek). Centralized so every control in that row
/// is the same size and corner radius.
enum StudyControlMetrics {
    static let buttonSize:   CGFloat = 48
    static let cornerRadius: CGFloat = 12
    static let rowSpacing:   CGFloat = 10
}

// MARK: - Card Button Style

/// Press-to-scale feedback for tappable pack cards.
struct CardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(AppMotion.control, value: configuration.isPressed)
    }
}
