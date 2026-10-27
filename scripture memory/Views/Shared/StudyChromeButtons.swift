import SwiftUI

extension View {
    /// The system's glass button on iOS 26 and later; a bordered one before it.
    @ViewBuilder
    func systemGlassButton() -> some View {
        if #available(iOS 26.0, *) {
            buttonStyle(.glass)
        } else {
            buttonStyle(.bordered)
        }
    }

    /// The system's glass behind a control that can't take the glass button
    /// style (a text field, a press-and-hold button); a grouped fill before
    /// iOS 26.
    @ViewBuilder
    func systemGlass(in shape: some Shape) -> some View {
        if #available(iOS 26.0, *) {
            glassEffect(.regular.interactive(), in: shape)
        } else {
            background(Color(.secondarySystemGroupedBackground), in: shape)
        }
    }
}
