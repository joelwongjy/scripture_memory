import SwiftUI

/// Four grading buttons (Again / Hard / Good / Easy) shown after the user has
/// finished a card in an SRS session. The auto-suggested grade is visually
/// emphasized; the user can override by tapping any other button.
///
/// Each button shows the predicted next interval underneath ("1m", "10m", "1d", "4d", …)
/// so the consequence of the choice is visible.
struct SRSGradingButtons: View {

    let state:     SRSCardState
    let suggested: SRSGrade
    let now:       Date
    let onPick:    (SRSGrade) -> Void

    var body: some View {
        HStack(spacing: 8) {
            ForEach(SRSGrade.allCases, id: \.self) { grade in
                gradeButton(grade)
            }
        }
        .padding(.horizontal, 24)
    }

    private func gradeButton(_ grade: SRSGrade) -> some View {
        let isSuggested = (grade == suggested)
        let label = predictedIntervalLabel(state: state, grade: grade, now: now)
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        return Button {
            HapticEngine.light()
            onPick(grade)
        } label: {
            VStack(spacing: 2) {
                Text(grade.displayName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(textColor(for: grade, suggested: isSuggested))
                Text(label)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(textColor(for: grade, suggested: isSuggested).opacity(0.85))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(shape.fill(background(for: grade, suggested: isSuggested)))
            .overlay(shape.stroke(isSuggested ? color(for: grade) : .clear, lineWidth: 2))
        }
        .buttonStyle(.plain)
    }

    private func color(for grade: SRSGrade) -> Color {
        switch grade {
        case .again: return .red
        case .hard:  return .orange
        case .good:  return .green
        case .easy:  return .blue
        }
    }

    private func textColor(for grade: SRSGrade, suggested: Bool) -> Color {
        suggested ? .white : .primary
    }

    private func background(for grade: SRSGrade, suggested: Bool) -> Color {
        suggested ? color(for: grade) : Color(.secondarySystemGroupedBackground)
    }
}
