import SwiftUI

// MARK: - Jump-to-current button

/// The floating "Jump to current verse" shortcut: shows its full label for a
/// second, then shrinks to just the icon. It's its own view so each appearance
/// gets fresh `expanded` state — the collapse re-arms every time it's shown — and
/// it fades (never scales) in, so the expanded pill is tappable immediately.
struct JumpToCurrentButton: View {
    let action: () -> Void
    /// Whether this appearance gets the labelled pill. The label teaches what the
    /// button is; once that's landed, re-teaching it every time the button comes
    /// back (which is every time you navigate away from the cursor verse) is just
    /// noise — and it briefly covers the card underneath.
    var startExpanded: Bool = true
    /// Fired as soon as the pill is shown, so the owner can suppress it from here on.
    var onExpandedShown: () -> Void = {}

    @State private var expanded: Bool

    init(startExpanded: Bool = true,
         onExpandedShown: @escaping () -> Void = {},
         action: @escaping () -> Void) {
        self.startExpanded    = startExpanded
        self.onExpandedShown  = onExpandedShown
        self.action           = action
        _expanded             = State(initialValue: startExpanded)
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: "bookmark.fill")
                    .font(.system(size: expanded ? 12 : 15, weight: .bold))
                if expanded {
                    Text("Jump to current verse")
                        .font(.system(size: 13, weight: .semibold))
                        .fixedSize()
                }
            }
            .foregroundStyle(.white)
            .padding(.horizontal, expanded ? 14 : 0)
            .padding(.vertical, expanded ? 10 : 0)
            // Collapsed form stays a 44pt circular tap target (Apple minimum).
            .frame(minWidth: expanded ? 0 : 44, minHeight: expanded ? 0 : 44)
            .background(Capsule().fill(Color.accentColor))
            .shadow(color: .black.opacity(0.22), radius: 6, x: 0, y: 3)
            .contentShape(Capsule())
        }
        .accessibilityLabel("Jump to current verse")
        // Fade only — a `.scale` transition hit-tests its shrunken geometry while
        // springing in, so the expanded pill would miss taps for its whole life.
        .transition(.opacity)
        .task {
            guard expanded else { return }
            // Claim the one expanded showing up front, not after the collapse —
            // navigating away inside that first second cancels this task, and the
            // label would otherwise be owed all over again.
            onExpandedShown()
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            withAnimation(AppMotion.movement) { expanded = false }
        }
    }
}
