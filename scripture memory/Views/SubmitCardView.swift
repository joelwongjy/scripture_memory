import SwiftUI

// MARK: - Diff Model

struct DiffWord: Identifiable {
    enum Kind { case correct, wrong, missing, extra }
    let id = UUID()
    let text: String
    let kind: Kind
}

// MARK: - Submit Card View

struct SubmitCardView: View {
    let verse: Verse
    let cardLabel: String
    @Binding var typedText: String
    let diff: [DiffWord]?           // nil = not yet submitted
    @FocusState.Binding var isFocused: Bool

    private let cardColor = Color(uiColor: UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(white: 0.13, alpha: 1)
            : UIColor(red: 0.98, green: 0.965, blue: 0.94, alpha: 1)
    })

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Reference header
            Text("\(verse.book) \(verse.reference)")
                .font(.system(size: 18, weight: .bold, design: .serif))
                .foregroundColor(.primary)

            Spacer().frame(height: 6)

            Text(verse.title)
                .font(.system(size: 12, weight: .medium, design: .serif))
                .foregroundColor(.secondary)

            Spacer().frame(height: 10)

            if let diff {
                diffView(diff)
            } else {
                typingView
            }

            Spacer(minLength: 6)

            HStack {
                Text(cardLabel)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
                Spacer()
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color(white: 0.82), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.12), radius: 16, x: 0, y: 8)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }

    // MARK: - Typing View

    private var typingView: some View {
        TextEditor(text: $typedText)
            .scrollContentBackground(.hidden)
            .background(.clear)
            .font(.system(size: 15, design: .serif))
            .foregroundColor(.primary)
            .lineSpacing(5)
            .focused($isFocused)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(alignment: .topLeading) {
                if typedText.isEmpty {
                    Text("Type the verse here...")
                        .font(.system(size: 15, design: .serif))
                        .foregroundColor(.secondary.opacity(0.45))
                        .lineSpacing(5)
                        .padding(.top, 8)
                        .padding(.leading, 5)
                        .allowsHitTesting(false)
                }
            }
    }

    // MARK: - Diff View

    private func diffView(_ diffs: [DiffWord]) -> some View {
        let font = Font.system(size: 15, design: .serif)
        let text = diffs.enumerated().reduce(Text("")) { acc, pair in
            let (i, word) = pair
            let sep = i < diffs.count - 1 ? " " : ""
            switch word.kind {
            case .correct:
                return acc + Text(word.text + sep).foregroundColor(.primary).font(font)
            case .wrong:
                return acc + Text(word.text + sep).foregroundColor(.red).font(font)
            case .missing:
                return acc + Text(word.text + sep).foregroundColor(.secondary.opacity(0.35)).font(font)
            case .extra:
                return acc + Text(word.text + sep).foregroundColor(.orange).font(font)
            }
        }
        return text
            .lineSpacing(5)
            .minimumScaleFactor(0.75)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
