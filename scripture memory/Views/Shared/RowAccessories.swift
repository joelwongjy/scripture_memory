import SwiftUI

// MARK: - Row accessories

/// The tick that marks the chosen row in a single-choice list.
struct SelectionCheckmark: View {
    var body: some View {
        Image(systemName: "checkmark")
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(Color.accentColor)
            .accessibilityLabel("Selected")
    }
}

/// The circle-tick that marks an included row in a multi-choice list. `mixed`
/// is the "some of this group" state a pack header shows.
struct SelectionCircle: View {
    var isSelected: Bool
    var mixed = false
    var size: CGFloat = 20

    var body: some View {
        Image(systemName: isSelected ? "checkmark.circle.fill" : mixed ? "minus.circle.fill" : "circle")
            .font(.system(size: size))
            .foregroundStyle(isSelected || mixed ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.secondary))
            .accessibilityHidden(true)
    }
}

/// The disclosure chevron a tappable row ends with.
struct RowChevron: View {
    var body: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.tertiary)
            .accessibilityHidden(true)
    }
}
