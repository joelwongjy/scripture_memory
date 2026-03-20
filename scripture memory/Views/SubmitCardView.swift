import SwiftUI

// MARK: - Diff Model

struct DiffWord: Identifiable {
    enum Kind { case correct, wrong, missing, extra }
    let id = UUID()
    let text: String
    let kind: Kind
    let correction: String?

    init(text: String, kind: Kind, correction: String? = nil) {
        self.text = text
        self.kind = kind
        self.correction = correction
    }
}

struct SubmitResult {
    let titleDiffs: [DiffWord]
    let verseDiffs: [DiffWord]

    var isAllCorrect: Bool {
        !titleDiffs.isEmpty && !verseDiffs.isEmpty
        && titleDiffs.allSatisfy { $0.kind == .correct }
        && verseDiffs.allSatisfy { $0.kind == .correct }
    }
}

enum SubmitField: Hashable { case title, verse }

// MARK: - Submit Card View

struct SubmitCardView: View {
    let verse: Verse
    let cardLabel: String
    @Binding var titleText: String
    @Binding var verseText: String
    let result: SubmitResult?
    @FocusState.Binding var focusedField: SubmitField?

    private let cardColor = Color(uiColor: UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(white: 0.13, alpha: 1)
            : UIColor(red: 0.98, green: 0.965, blue: 0.94, alpha: 1)
    })

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("\(verse.book) \(verse.reference)")
                .font(.system(size: 18, weight: .bold, design: .serif))
                .foregroundColor(.primary)

            Spacer().frame(height: 10)

            if let result {
                diffSectionsView(result)
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
        VStack(alignment: .leading, spacing: 0) {
            titleField
            Divider().padding(.vertical, 6)
            verseField
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var titleField: some View {
        TextField("Title", text: $titleText)
            .font(.system(size: 16, weight: .bold, design: .serif))
            .foregroundColor(.primary)
            .focused($focusedField, equals: .title)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .onSubmit { focusedField = .verse }
    }

    private var verseField: some View {
        TextEditor(text: $verseText)
            .scrollContentBackground(.hidden)
            .background(.clear)
            .font(.system(size: 15, design: .serif))
            .foregroundColor(.primary)
            .lineSpacing(5)
            .focused($focusedField, equals: .verse)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .padding(.horizontal, -5)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(alignment: .topLeading) {
                if verseText.isEmpty {
                    Text("Verse")
                        .font(.system(size: 15, design: .serif))
                        .foregroundColor(.secondary.opacity(0.45))
                        .padding(.top, 8)
                        .allowsHitTesting(false)
                }
            }
    }

    // MARK: - Diff Sections View

    private func diffSectionsView(_ result: SubmitResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            diffLine(result.titleDiffs, font: .system(size: 16, weight: .bold, design: .serif))
            diffLine(result.verseDiffs, font: .system(size: 15, design: .serif))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func diffLine(_ diffs: [DiffWord], font: Font) -> some View {
        var groups: [(kind: DiffWord.Kind, words: [DiffWord])] = []
        for word in diffs {
            if let last = groups.last, last.kind == word.kind {
                groups[groups.count - 1].words.append(word)
            } else {
                groups.append((kind: word.kind, words: [word]))
            }
        }

        let text = groups.enumerated().reduce(Text("")) { acc, pair in
            let (gi, group) = pair
            let sep = gi < groups.count - 1 ? " " : ""
            switch group.kind {
            case .correct:
                let joined = group.words.map(\.text).joined(separator: " ")
                return acc + Text(joined + sep).foregroundColor(.green).font(font)
            case .wrong:
                let wrongJoined = group.words.map(\.text).joined(separator: " ")
                let corrections = group.words.compactMap(\.correction).joined(separator: " ")
                let crossed = Text(wrongJoined + " ").strikethrough().foregroundColor(.red.opacity(0.5)).font(font)
                if !corrections.isEmpty {
                    return acc + crossed + Text(corrections + sep).foregroundColor(.red).font(font)
                }
                return acc + crossed
            case .missing:
                let joined = group.words.map(\.text).joined(separator: " ")
                return acc + Text(joined + sep).foregroundColor(.secondary.opacity(0.5)).font(font)
            case .extra:
                let joined = group.words.map(\.text).joined(separator: " ")
                return acc + Text(joined + sep).strikethrough().foregroundColor(.red.opacity(0.5)).font(font)
            }
        }
        return text
            .lineSpacing(5)
            .minimumScaleFactor(0.75)
    }
}
