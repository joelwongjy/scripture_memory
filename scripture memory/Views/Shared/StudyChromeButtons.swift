import SwiftUI

// MARK: - Study chrome (top bar + scrubber)

extension Image {
    /// Neutral circular icon button — close, list, reset, etc. Accent icon on a
    /// solid neutral fill. 36pt visual circle inside a 44pt hit target (HIG min).
    func studyChromeCircleButton() -> some View {
        self
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(Color.accentColor)
            .frame(width: 36, height: 36)
            .background(Color(.secondarySystemBackground), in: Circle())
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
    }

    /// A 44pt round glass control, for chrome floating over full-screen content.
    func floatingGlassButton() -> some View {
        font(.system(size: 15, weight: .semibold))
            .foregroundStyle(Color.primary)
            .frame(width: 44, height: 44)
            .floatingGlass(in: Circle())
            .contentShape(Circle())
    }
}

extension View {
    /// Liquid Glass on iOS 26 and later; a thin material before it.
    @ViewBuilder
    func floatingGlass(in shape: some Shape) -> some View {
        if #available(iOS 26.0, *) {
            glassEffect(.regular, in: shape)
        } else {
            background(.ultraThinMaterial, in: shape)
        }
    }
}

/// The top bar's "Done" while typing: a guaranteed-visible way to put the
/// keyboard away (the keyboard's own toolbar item is unreliable this deep in
/// the card stack).
struct KeyboardDoneButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("Done")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.accentColor)
        }
        .accessibilityLabel("Close keyboard")
    }
}
