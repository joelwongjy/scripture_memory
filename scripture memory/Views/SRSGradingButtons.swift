import SwiftUI

/// Four grading buttons (Again / Hard / Good / Easy) shown after a card is
/// finished in an SRS session.
///
/// - The **selected** grade (the one Confirm will commit) is filled with its
///   colour. Upstream it usually defaults to the suggestion, but the user can
///   tap any button to choose their own difficulty.
/// - The **suggested** grade carries a clear "Suggested" tag above it, so the
///   recommended choice is obvious — "this is your suggested one, you can pick
///   another". `suggested` may be `nil` (e.g. first-letter mode, where frequent
///   typos make a performance-based suggestion unreliable); then no tag shows
///   and the user simply chooses for themselves.
struct SRSGradingButtons: View {

    let state:     SRSCardState
    let suggested: SRSGrade?
    let selected:  SRSGrade?
    let now:       Date
    let onPick:    (SRSGrade) -> Void

    var body: some View {
        HStack(spacing: 8) {
            ForEach(SRSGrade.allCases, id: \.self) { grade in
                gradeButton(grade)
            }
        }
        // Headroom so the "Suggested" tag can sit above its button without clipping.
        .padding(.top, 14)
    }

    private func gradeButton(_ grade: SRSGrade) -> some View {
        let isSuggested = (grade == suggested)
        let isSelected  = (grade == selected)
        let label = predictedIntervalLabel(state: state, grade: grade, now: now)
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        return Button {
            HapticEngine.light()
            onPick(grade)
        } label: {
            VStack(spacing: 2) {
                Text(grade.displayName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(textColor(grade: grade, selected: isSelected, suggested: isSuggested))
                Text(label)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(textColor(grade: grade, selected: isSelected, suggested: isSuggested).opacity(0.85))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            // Filled only when this grade is the current selection.
            .background(shape.fill(isSelected ? color(for: grade) : Color(.secondarySystemGroupedBackground)))
            // Outline marks the suggestion when it isn't (also) the filled selection.
            .overlay(shape.stroke(isSuggested && !isSelected ? color(for: grade) : .clear, lineWidth: 2))
            // "Suggested" tag straddling the top edge of the recommended button.
            .overlay(alignment: .top) {
                if isSuggested { suggestedTag(color: color(for: grade)) }
            }
        }
        .buttonStyle(.plain)
    }

    /// A small pill anchored to the top edge of the suggested button. The
    /// background-coloured ring makes it read as a tag sitting on the button.
    private func suggestedTag(color: Color) -> some View {
        Text("Suggested")
            .font(.system(size: 9, weight: .heavy))
            .foregroundStyle(.white)
            .fixedSize()
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(Capsule().fill(color))
            .overlay(Capsule().stroke(Color(.systemBackground), lineWidth: 1.5))
            .offset(y: -10)
    }

    private func color(for grade: SRSGrade) -> Color {
        switch grade {
        case .again: return .red
        case .hard:  return .orange
        case .good:  return .green
        case .easy:  return .blue
        }
    }

    private func textColor(grade: SRSGrade, selected: Bool, suggested: Bool) -> Color {
        if selected  { return .white }            // filled selection
        if suggested { return color(for: grade) } // outlined recommendation
        return .primary
    }
}
