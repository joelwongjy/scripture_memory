import SwiftUI

/// How many of the selected verses to quiz, set like the Move goal in Fitness:
/// the count between a minus and a plus button. Tapping the count types an
/// exact number, with All above the keyboard.
struct QuizCountPicker: View {
    @Binding var count: Int
    /// The number of verses selected; the count stays within 1...maximum.
    let maximum: Int

    @State private var draft = ""
    @FocusState private var typing: Bool

    private var upperBound: Int { max(1, maximum) }
    private var clampedCount: Int { clamp(count) }
    private func clamp(_ n: Int) -> Int { max(1, min(n, upperBound)) }

    var body: some View {
        HStack {
            stepButton("minus", label: "Fewer verses", enabled: clampedCount > 1) { set(clampedCount - 1) }
            Spacer(minLength: 8)
            VStack(spacing: 2) {
                TextField("\(clampedCount)", text: $draft)
                    .keyboardType(.numberPad)
                    .textContentType(nil)
                    .autocorrectionDisabled()
                    .focused($typing)
                    .multilineTextAlignment(.center)
                    .font(.system(.title, design: .rounded).weight(.bold))
                    .monospacedDigit()
                    .frame(width: 96)
                    .padding(.vertical, 2)
                    .background(Color(.tertiarySystemFill), in: Capsule())
                    .accessibilityLabel("Verses to quiz")
                    .accessibilityValue("\(clampedCount) of \(maximum)")
                Text(clampedCount == upperBound ? "all verses" : "of \(maximum) verses")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            stepButton("plus", label: "More verses", enabled: clampedCount < upperBound) { set(clampedCount + 1) }
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                if typing {
                    Button("All \(maximum)") {
                        draft = "\(upperBound)"
                        typing = false
                    }
                    Spacer()
                    Button("Done") { typing = false }
                        .fontWeight(.semibold)
                }
            }
        }
        .onAppear { draft = "\(clampedCount)" }
        .onChange(of: clampedCount) { _, new in if !typing { draft = "\(new)" } }
        .onChange(of: typing) { _, now in
            if now {
                draft = ""
            } else {
                if let n = Int(draft) { set(n) }
                draft = "\(clampedCount)"
            }
        }
        .onChange(of: draft) { _, new in
            let digits = String(new.filter(\.isNumber).prefix(4))
            if digits != new { draft = digits }
        }
    }

    private func stepButton(_ symbol: String, label: String, enabled: Bool,
                            action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.title3.weight(.semibold))
                .frame(width: 30, height: 30)
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.circle)
        .buttonRepeatBehavior(.enabled)
        .disabled(!enabled)
        .accessibilityLabel(label)
    }

    private func set(_ n: Int) {
        let new = clamp(n)
        guard new != clampedCount else { return }
        withAnimation(AppMotion.content) { count = new }
        HapticEngine.light()
    }
}
