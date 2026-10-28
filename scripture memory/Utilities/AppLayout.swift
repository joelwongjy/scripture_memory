import SwiftUI

/// App-wide layout values, matched to iOS's own where iOS has one.
///
/// Measured against a system `.insetGrouped` list on iOS 26: sections sit 16pt
/// from the screen edge, their corners are 26pt, and row content is inset 16pt.
/// Every screen uses the same numbers so edges and corners line up from one
/// screen to the next.
enum AppLayout {
    /// Distance from the screen (or window) edge to content.
    static let screenMargin: CGFloat = 16
    /// Gap between stacked cards and panels, and between grid tiles.
    static let spacing: CGFloat = 16

    /// Corner radius for panels, matching iOS 26's grouped-list sections.
    /// Controls use capsules.
    static let cornerRadius: CGFloat = 26
    /// Corner radius for cards (flashcards, pack covers): tighter than a panel,
    /// like the printed cards they stand for.
    static let cardRadius: CGFloat = 10

    /// Inner padding of a list-like panel (one row of text and a control), the
    /// same as a list row's content inset.
    static let panelPadding: CGFloat = 16
    /// Vertical padding of a one-row panel, giving it a list row's height.
    static let panelRowPadding: CGFloat = 14
    /// Inner padding of a card holding a verse. A little more than a panel so
    /// text clears the larger corners.
    static let cardPadding: CGFloat = 20

    // MARK: Wide windows (iPhone Duo's inner display)

    /// Widest a scrolling column of cards gets before it centres, so lines of
    /// text stay readable on a wide window.
    static let readableWidth: CGFloat = 640
    /// Widest the study and review screens get (card plus margins).
    static let studyColumnWidth: CGFloat = 592

    /// The card's proportions on the study screens: 5 wide by 3 tall.
    static let cardAspect: CGFloat = 5.0 / 3.0
}

extension View {
    /// Clips to a continuous ("squircle") rounded rectangle, the iOS-standard
    /// corner style.
    func roundedRect(_ radius: CGFloat = AppLayout.cornerRadius) -> some View {
        clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
    }

    /// The white rounded panel Home's cards sit on, matching grouped-list sections.
    func groupedPanel() -> some View {
        background(
            RoundedRectangle(cornerRadius: AppLayout.cornerRadius, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    /// Centres content in a column no wider than `maxWidth`. A no-op on a phone;
    /// on a wide window it keeps lines readable instead of stretching edge to edge.
    func readableColumn(_ maxWidth: CGFloat = AppLayout.readableWidth) -> some View {
        frame(maxWidth: maxWidth).frame(maxWidth: .infinity)
    }
}

/// The shared 48pt control metrics for the study screens' bottom bar (mic, hint,
/// peek, the typing field and the action buttons). All of them are capsules.
enum StudyControlMetrics {
    static let buttonSize: CGFloat = 48
    static let rowSpacing: CGFloat = 10
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

// MARK: - Bigger tap targets

extension View {
    /// Grows the tappable area to Apple's 44×44pt minimum without changing the
    /// layout, for a control drawn smaller than that.
    func minimumTapTarget(visibleSize: CGFloat) -> some View {
        contentShape(Rectangle().inset(by: min(0, (visibleSize - 44) / 2)))
    }
}
