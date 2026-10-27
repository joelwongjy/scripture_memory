import SwiftUI

/// How many of the selected verses to quiz, as one menu: the usual counts,
/// All, and Custom… for an exact number.
struct QuizCountMenu: View {
    @Binding var count: Int
    /// The number of verses selected; the count stays within 1...maximum.
    let maximum: Int

    @State private var askingCustom = false
    @State private var customText = ""

    private static let presets = [5, 10, 15, 20, 30, 50]

    private var upperBound: Int { max(1, maximum) }
    private var clampedCount: Int { clamp(count) }
    private func clamp(_ n: Int) -> Int { max(1, min(n, upperBound)) }

    var body: some View {
        HStack {
            Text("Verses")
            Spacer(minLength: 8)
            Menu {
                Picker("Verses", selection: selection) {
                    ForEach(Self.presets.filter { $0 < maximum }, id: \.self) { n in
                        Text("\(n)").tag(n)
                    }
                    Text("All \(maximum)").tag(maximum)
                }
                Divider()
                Button("Custom…") {
                    customText = "\(clampedCount)"
                    askingCustom = true
                }
            } label: {
                HStack(spacing: 4) {
                    Text("\(clampedCount) of \(maximum)")
                        .monospacedDigit()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.footnote.weight(.semibold))
                }
            }
            .accessibilityLabel("Verses to quiz")
            .accessibilityValue("\(clampedCount) of \(maximum)")
        }
        .font(.body)
        .alert("Verses to Quiz", isPresented: $askingCustom) {
            TextField("Number", text: $customText)
                .keyboardType(.numberPad)
            Button("Cancel", role: .cancel) {}
            Button("Done") {
                if let n = Int(customText.filter(\.isNumber)) { count = clamp(n) }
            }
        } message: {
            Text("Between 1 and \(maximum).")
        }
    }

    private var selection: Binding<Int> {
        Binding { clampedCount } set: {
            count = clamp($0)
            HapticEngine.light()
        }
    }
}
