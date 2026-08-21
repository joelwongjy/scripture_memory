import SwiftUI

/// Single, always-present hold-to-peek control for the study/review controls.
///
/// One consistent control across every test/review screen and every state
/// within them (before submit, after submit, while grading, on a finished
/// card, in all study modes). Press and hold to reveal the full verse via the
/// card overlay; release to hide.
///
/// Anchored to the leading edge of the bottom control band so it sits in the
/// same place regardless of which state-specific controls are showing, and is
/// visually subordinate to the centered primary action. Compact (matches the
/// mic / keyboard-dismiss buttons). Wrapped in a `Button` (with a no-op action)
/// so pressing it never resigns the focused text field — otherwise the keyboard
/// would dismiss mid-review.
struct PeekHoldButton: View {
    @Binding var isPeeking: Bool

    /// One-time discoverability hint (icon-only press-and-hold isn't obvious).
    @AppStorage("peekHintSeen") private var hintSeen = false
    @State private var showHint = false

    var body: some View {
        Button(action: {}) {
            Image(systemName: isPeeking ? "eye.fill" : "eye")
                .font(.system(size: 18, weight: .semibold))
                .contentTransition(.symbolEffect(.replace))
                .foregroundStyle(isPeeking ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.secondary))
                .frame(width: StudyControlMetrics.buttonSize, height: StudyControlMetrics.buttonSize)
                .background(
                    RoundedRectangle(cornerRadius: StudyControlMetrics.cornerRadius, style: .continuous)
                        .fill(isPeeking ? Color.accentColor.opacity(0.12) : Color(.secondarySystemGroupedBackground))
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(PressReportingButtonStyle { pressed in
            withAnimation(.easeInOut(duration: 0.1)) { isPeeking = pressed }
            if pressed {
                HapticEngine.light()
                dismissHint()
            }
        })
        .accessibilityLabel("Peek at answer")
        .accessibilityHint("Press and hold to reveal the verse")
        .accessibilityAddTraits(.isButton)
        .overlay(alignment: .top) {
            if showHint {
                Text("Hold to peek")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule(style: .continuous).fill(Color.accentColor))
                    .fixedSize()
                    .offset(y: -34)
                    .transition(.opacity.combined(with: .scale(scale: 0.9, anchor: .bottom)))
                    .allowsHitTesting(false)
            }
        }
        .task {
            guard !hintSeen else { return }
            try? await Task.sleep(for: .milliseconds(700))   // let the screen settle
            guard !hintSeen else { return }
            withAnimation(AppMotion.movement) { showHint = true }
            try? await Task.sleep(for: .seconds(4))
            dismissHint()
        }
    }

    private func dismissHint() {
        if showHint { withAnimation(AppMotion.control) { showHint = false } }
        hintSeen = true
    }
}

/// Reports a button's press state the moment the touch lands, and again on release.
///
/// `PeekHoldButton` used to get press-and-hold from a `DragGesture(minimumDistance: 0)`
/// riding alongside the button. That gesture sits behind UIKit's decision about
/// whether the touch is really a drag, and inside the review screen's gesture stack
/// (card swipe + tap-to-focus + the button itself) that arbitration took a long
/// beat — so peek felt like it demanded a multi-second press before anything
/// happened. A `ButtonStyle`'s `isPressed` flips on touch-down with no arbitration
/// to wait for, so the reveal is immediate.
struct PressReportingButtonStyle: ButtonStyle {
    let onPressChange: (Bool) -> Void

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .onChange(of: configuration.isPressed) { _, pressed in onPressChange(pressed) }
    }
}
