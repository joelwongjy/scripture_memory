import SwiftUI

/// The pinned bar a setup screen ends with — Confirm, Start, Continue.
///
/// Hairline on top, frosted `.bar` material underneath, one padding. Attach
/// with `.safeAreaInset(edge: .bottom, spacing: 0)` so list rows scroll under
/// it rather than behind a floating button. The quiz picker, the starting-
/// point picker and onboarding each drew their own version of this with
/// different materials and paddings; this is the one they share.
struct BottomActionBar<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) {
            Divider()
            content
                .padding(.horizontal, AppLayout.screenMargin)
                .padding(.top, 12)
                .padding(.bottom, 8)
        }
        .background(.bar)
    }
}

/// The full-width capsule primary action used inside a `BottomActionBar`.
struct PrimaryActionButton: View {
    let title: String
    var isEnabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .frame(maxWidth: .infinity)
        }
        .controlSize(.large)
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.capsule)
        .tint(.accentColor)
        .disabled(!isEnabled)
    }
}
