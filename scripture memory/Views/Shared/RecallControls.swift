import SwiftUI

/// The controls both card-recall screens (`CardStudyView`, `TestSessionView`)
/// put under the card. They used to be copies in each file; this is the one set.
///
/// Everything here is a `Button` on purpose: a bare tap target would resign the
/// text field's first responder and dismiss the keyboard mid-verse.

// MARK: - Tile button

/// The 48pt square control tile — hint, mic — in the bottom control band.
struct StudyControlTile: View {
    let systemImage: String
    var tint: Color = .primary
    var fill: Color = Color(.secondarySystemGroupedBackground)
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: StudyControlMetrics.buttonSize, height: StudyControlMetrics.buttonSize)
                .background(fill)
                .roundedRect(StudyControlMetrics.cornerRadius)
        }
        .buttonStyle(.plain)
    }
}

/// Reveals (or types in) the next hidden word.
struct HintButton: View {
    var accessibilityLabel = "Reveal next word"
    let action: () -> Void

    var body: some View {
        StudyControlTile(systemImage: "lightbulb") {
            action()
            HapticEngine.light()
        }
        .accessibilityLabel(accessibilityLabel)
    }
}

/// Entire Verse mode's mic — a full tile, red while listening.
struct DictationTile: View {
    let isListening: Bool
    let action: () -> Void

    var body: some View {
        StudyControlTile(systemImage: isListening ? "mic.fill" : "mic",
                         tint: isListening ? .white : .primary,
                         fill: isListening ? .red : Color(.secondarySystemGroupedBackground),
                         action: action)
            .accessibilityLabel(isListening ? "Stop dictation" : "Dictate verse")
    }
}

// MARK: - Typing field

/// The single text field first-letter and full-word modes share, with the
/// inline mic on its leading edge and the hint tile beside it.
///
/// The mic takes the slot a decorative "character.cursor.ibeam" glyph used to
/// occupy: the control row (peek, field, hint) has no width for a fourth
/// button, and that glyph was ornament. Entire Verse mode keeps its own larger
/// mic (`DictationTile`) — this field only exists in the two typing modes.
///
/// Typing is scored by the view model; the field just reports right/wrong with
/// haptics and a shake. A wrong letter is deliberately *not* a session mistake —
/// see `TestSessionViewModel.recordMistake`.
struct RecallInputField: View {
    @ObservedObject var vm: RecallCardViewModel
    let studyMode: StudyMode
    let isListening: Bool
    var isFocused: FocusState<Bool>.Binding
    let onToggleSpeech: () -> Void

    @State private var shakeOffset: CGFloat = 0

    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: 10) {
                dictationButton

                TextField(studyMode.inputPlaceholder, text: $vm.inputText)
                    .font(.system(size: 17))
                    .focused(isFocused)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .onChange(of: vm.inputText) { _, newValue in
                        guard !newValue.isEmpty else { return }
                        switch studyMode {
                        case .firstLetter:
                            let correct = vm.processFirstLetterInput(newValue)
                            DispatchQueue.main.async { vm.inputText = "" }
                            if correct { HapticEngine.light() } else { miss() }
                        case .fullWord:
                            if vm.processFullWordInput(newValue) {
                                HapticEngine.light()
                            } else if newValue.hasSuffix(" ") {
                                miss()
                            }
                        case .submit:
                            break
                        }
                    }
                    // Keyboard dismissal lives in the top bar ("Done") — a single,
                    // reliable affordance instead of a second keyboard-toolbar one.
            }
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground))
            .roundedRect(StudyControlMetrics.cornerRadius)
            .overlay(RoundedRectangle(cornerRadius: StudyControlMetrics.cornerRadius, style: .continuous)
                .stroke(Color(.separator).opacity(0.5), lineWidth: 0.5))
            .offset(x: shakeOffset)

            HintButton { vm.revealHint() }
        }
    }

    private func miss() {
        HapticEngine.error()
        triggerShake($shakeOffset)
    }

    private var dictationButton: some View {
        Button(action: onToggleSpeech) {
            Image(systemName: isListening ? "mic.fill" : "mic")
                .font(.system(size: 16))
                .foregroundStyle(isListening ? Color.red : Color.secondary)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 22, height: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isListening ? "Stop dictation" : "Dictate verse")
    }
}
