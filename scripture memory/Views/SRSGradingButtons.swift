import SwiftUI

/// Four grading buttons (Again / Hard / Good / Easy) shown after the user has
/// finished a card in an SRS session.
///
/// Before the user picks, the auto-suggested grade is shown as an **outline**
/// (a recommendation) — never pre-filled, so it can't be mistaken for a choice
/// already made. Once picked (`isConfirmed`), that grade fills in to read as the
/// selection. Each button shows the predicted next interval ("1m", "1d", "4d", …)
/// so the consequence of the choice is visible.
struct SRSGradingButtons: View {

    let state:     SRSCardState
    let suggested: SRSGrade
    let now:       Date
    /// True once the user has actually graded this card. Until then `suggested`
    /// is only a recommendation and must not look selected.
    var isConfirmed: Bool = false
    let onPick:    (SRSGrade) -> Void

    var body: some View {
        HStack(spacing: 8) {
            ForEach(SRSGrade.allCases, id: \.self) { grade in
                gradeButton(grade)
            }
        }
    }

    private func gradeButton(_ grade: SRSGrade) -> some View {
        let isSuggested = (grade == suggested)
        let isPicked    = isSuggested && isConfirmed
        let label = predictedIntervalLabel(state: state, grade: grade, now: now)
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        return Button {
            HapticEngine.light()
            onPick(grade)
        } label: {
            VStack(spacing: 2) {
                Text(grade.displayName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(textColor(for: grade, suggested: isSuggested, picked: isPicked))
                Text(label)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(textColor(for: grade, suggested: isSuggested, picked: isPicked).opacity(0.85))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            // Filled only once the grade is the confirmed pick; otherwise plain.
            .background(shape.fill(isPicked ? color(for: grade) : Color(.secondarySystemGroupedBackground)))
            // Recommendation marker: an outline on the suggested grade *before*
            // it's picked — distinct from the filled "selected" look.
            .overlay(shape.stroke(isSuggested && !isConfirmed ? color(for: grade) : .clear, lineWidth: 2))
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

    private func textColor(for grade: SRSGrade, suggested: Bool, picked: Bool) -> Color {
        if picked    { return .white }            // confirmed selection (filled)
        if suggested { return color(for: grade) } // recommendation (outlined)
        return .primary
    }
}
