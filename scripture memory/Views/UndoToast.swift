import SwiftUI

// MARK: - State

/// A pending undo prompt. `id` gives each toast its own view identity, so raising
/// a second one while the first is still on screen re-arms the dismiss timer
/// instead of inheriting the old one's remaining time.
struct UndoToastState: Identifiable {
    let id = UUID()
    let message: String
    let undo: () -> Void
}

// MARK: - Toast

/// Transient confirmation for an action that is easy to fire by accident and
/// fiddly to reverse by hand — marking a verse complete, which also advances the
/// learning cursor. Confirms what happened, offers one-tap Undo, and leaves on
/// its own.
struct UndoToast: View {
    let message: String
    let onUndo: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.green)

            Text(message)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)

            Spacer(minLength: 6)

            Button(action: onUndo) {
                Text("Undo")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                    // Padded to a comfortable target — the toast is short-lived, so
                    // a miss costs the user the whole affordance.
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.leading, 14)
        .padding(.trailing, 2)
        .padding(.vertical, 6)
        .background(
            Capsule(style: .continuous)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.18), radius: 12, x: 0, y: 4)
        )
        .overlay(
            Capsule(style: .continuous)
                .strokeBorder(Color(.separator).opacity(0.35), lineWidth: 0.5)
        )
        .accessibilityElement(children: .contain)
    }
}

// MARK: - Presentation

extension View {

    /// How long an undo stays available. Long enough to notice and react to,
    /// short enough not to sit on top of the controls underneath it.
    private static var undoToastSeconds: Double { 5 }

    /// Floats `toast` over the bottom edge until it's undone or times out.
    ///
    /// Attach to the screen's root so the toast clears the bottom controls it sits
    /// above. Tapping Undo runs the action and dismisses immediately.
    func undoToast(_ toast: Binding<UndoToastState?>) -> some View {
        overlay(alignment: .bottom) {
            if let state = toast.wrappedValue {
                UndoToast(message: state.message) {
                    state.undo()
                    HapticEngine.light()
                    withAnimation(AppMotion.content) {
                        toast.wrappedValue = nil
                    }
                }
                .padding(.horizontal, AppLayout.screenMargin)
                .padding(.bottom, 10)
                .id(state.id)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                // Keyed on `id` so replacing a visible toast restarts the countdown.
                // Cancellation (view removed, or a newer toast) must not dismiss the
                // replacement, hence the explicit cancellation check.
                .task(id: state.id) {
                    try? await Task.sleep(for: .seconds(Self.undoToastSeconds))
                    guard !Task.isCancelled else { return }
                    withAnimation(AppMotion.content) {
                        toast.wrappedValue = nil
                    }
                }
            }
        }
        .animation(AppMotion.content, value: toast.wrappedValue?.id)
    }
}
