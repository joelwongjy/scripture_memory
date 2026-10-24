import SwiftUI

/// How many of the selected verses to quiz: − / count / +, with "Max" below.
/// The count itself is a number field, since "make it 40" is painful by stepping.
struct QuizCountStepper: View {
    @Binding var count: Int
    /// The number of verses selected; the count stays within 1...maximum.
    let maximum: Int

    @State private var draft = ""
    @FocusState private var fieldFocused: Bool
    /// The value on screen that the next keystroke should replace rather than
    /// extend — set whenever the count arrives from somewhere other than typing
    /// (focus, +/-, Max). Tap the field showing 15, type 8, get 8 (not 158).
    @State private var replaceAnchor: String? = nil

    private var upperBound: Int { max(1, maximum) }
    private var clampedCount: Int { clamp(count) }

    private func clamp(_ n: Int) -> Int { max(1, min(n, upperBound)) }

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 10) {
                stepButton(systemImage: "minus", label: "Fewer cards to quiz",
                           disabled: clampedCount <= 1) { setCount(clampedCount - 1) }
                countField
                stepButton(systemImage: "plus", label: "More cards to quiz",
                           disabled: clampedCount >= maximum) { setCount(clampedCount + 1) }
            }
            // "Max" is the count that's tedious to step to and annoying to type.
            HStack(spacing: 6) {
                Text("cards to quiz")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.secondary)
                Button {
                    setCount(maximum)
                    HapticEngine.light()
                } label: {
                    Text("Max")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.accentColor)
                }
                .buttonStyle(.plain)
                .disabled(clampedCount >= maximum)
                .opacity(clampedCount >= maximum ? 0.35 : 1)
                .accessibilityLabel("Quiz all \(maximum) selected verses")
            }
        }
    }

    private func stepButton(systemImage: String, label: String, disabled: Bool,
                            action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 32, height: 32)
                .background(Color(.secondarySystemBackground), in: Circle())
                .minimumTapTarget(visibleSize: 32)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.35 : 1)
        .accessibilityLabel(label)
    }

    /// Always a `TextField` (not a label that swaps for one on tap) so the keypad
    /// opens on the first tap. It shows the live count whether or not it has
    /// focus, so +/- and Max keep working with the keypad up.
    private var countField: some View {
        TextField("", text: $draft)
            .keyboardType(.numberPad)
            .multilineTextAlignment(.center)
            .font(.system(size: 22, weight: .bold, design: .monospaced))
            .focused($fieldFocused)
            // Fixed width so the stepper circles don't shift as digits are added.
            .frame(width: 58, height: 32)
            .background(Color(.secondarySystemBackground), in: Capsule())
            // Sanitise and commit on every keystroke, so what the field shows is
            // what Start will use. `.numberPad` doesn't stop a hardware keyboard,
            // dictation or paste, so non-digits are stripped here.
            .onChange(of: draft) { oldValue, newValue in
                var incoming = newValue
                if let anchor = replaceAnchor, oldValue == anchor,
                   newValue.count > anchor.count, newValue.hasPrefix(anchor) {
                    incoming = String(newValue.dropFirst(anchor.count))
                    replaceAnchor = nil
                }
                var digits = String(incoming.filter(\.isNumber).prefix(4))
                if let typed = Int(digits) {
                    let clamped = clamp(typed)
                    if clamped != typed { digits = "\(clamped)" }
                    count = clamped
                }
                // An empty field mid-edit is fine; `commitEdit` restores a valid
                // number when focus leaves.
                if digits != newValue { draft = digits }
            }
            .onChange(of: fieldFocused) { _, focused in
                if focused {
                    draft = "\(clampedCount)"
                    replaceAnchor = "\(clampedCount)"
                } else {
                    replaceAnchor = nil
                    commitEdit()
                }
            }
            .onChange(of: clampedCount) { _, newValue in
                // A change that didn't come from typing: +/-, Max, or the selection
                // shrinking under it.
                guard draft != "\(newValue)" else { return }
                draft = "\(newValue)"
                if fieldFocused { replaceAnchor = "\(newValue)" }
            }
            .onAppear { draft = "\(clampedCount)" }
            // A number pad has no return key, so something has to dismiss it.
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { fieldFocused = false }
                }
            }
            .accessibilityLabel("Cards to quiz")
            .accessibilityValue("\(clampedCount)")
            .accessibilityHint("Tap to type a number")
    }

    /// The write path for everything that isn't typing (+/-, Max).
    private func setCount(_ value: Int) {
        let clamped = clamp(value)
        count = clamped
        draft = "\(clamped)"
        replaceAnchor = fieldFocused ? "\(clamped)" : nil
    }

    /// Applies a typed count. An empty draft falls back to the count in effect.
    private func commitEdit() {
        if let typed = Int(draft.filter(\.isNumber)), typed >= 1 {
            count = clamp(typed)
        }
        draft = "\(clampedCount)"
    }
}
