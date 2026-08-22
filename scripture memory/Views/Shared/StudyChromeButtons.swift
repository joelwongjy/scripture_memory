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

    /// Toggle controls (shuffle, layout). Background flips: neutral when off,
    /// accent when on. Icon goes white on the accent background so there's no
    /// accent-on-accent visibility issue. 36pt visual / 44pt hit target.
    func studyChromeToggle(isOn: Bool) -> some View {
        self
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(isOn ? AnyShapeStyle(Color.white) : AnyShapeStyle(Color.accentColor))
            .frame(width: 36, height: 36)
            .background(
                isOn ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(Color(.secondarySystemBackground)),
                in: Circle()
            )
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
    }
}
