import SwiftUI

// MARK: - Shake Animation

/// Fires a three-step horizontal shake by animating a `CGFloat` binding.
/// Used to signal wrong input (alongside an error haptic). Skipped with Reduce
/// Motion, where the haptic carries the signal on its own.
@MainActor
func triggerShake(_ offset: Binding<CGFloat>) {
    guard !AppMotion.reduceMotion else { return }
    withAnimation(.interpolatingSpring(stiffness: 600, damping: 10)) { offset.wrappedValue = 12 }
    Task { @MainActor in
        try? await Task.sleep(for: .milliseconds(70))
        withAnimation(.interpolatingSpring(stiffness: 600, damping: 12)) { offset.wrappedValue = -8 }
        try? await Task.sleep(for: .milliseconds(70))
        withAnimation(AppMotion.content) { offset.wrappedValue = 0 }
    }
}
