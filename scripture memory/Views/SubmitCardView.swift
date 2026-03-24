import SwiftUI

// MARK: - Submit Field

/// Focus state identifier for the two text inputs on a submit-mode card.
enum SubmitField: Hashable { case title, verse }

// MARK: - Submit Card View

struct SubmitCardView: View {
    let verse:       Verse
    let cardLabel:   String
    @Binding var titleText: String
    @Binding var verseText: String
    let result:      SubmitResult?
    @FocusState.Binding var focusedField: SubmitField?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("\(verse.book) \(verse.reference)")
                .font(.system(size: 18, weight: .bold, design: .serif))

            Spacer().frame(height: 10)

            // Fill space between header and footer so the verse TextEditor (and diff text) get a real height.
            // A flexible `Spacer` here would expand and leave `inputView` at intrinsic height only (~one line).
            Group {
                if let result { diffView(result) } else { inputView }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            Text(cardLabel)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.secondary)
                .padding(.top, 6)
        }
        .flashcardStyle()
    }

    // MARK: - Input View

    private var inputView: some View {
        VStack(alignment: .leading, spacing: 0) {
            TextField("Title", text: $titleText)
                .font(.system(size: 16, weight: .bold, design: .serif))
                .focused($focusedField, equals: .title)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .onSubmit { focusedField = .verse }

            Divider().padding(.vertical, 6)

            TextEditor(text: $verseText)
                .scrollContentBackground(.hidden)
                .background(.clear)
                .font(.system(size: 15, design: .serif))
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
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: - Diff View

    private func diffView(_ result: SubmitResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            diffLine(result.titleDiffs, font: .system(size: 16, weight: .bold, design: .serif))
            diffLine(result.verseDiffs, font: .system(size: 15, design: .serif))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    /// Renders a sequence of `DiffWord` annotations as a single attributed `Text`.
    ///
    /// Consecutive words of the same kind are grouped first to minimise concatenation operations.
    private func diffLine(_ diffs: [DiffWord], font: Font) -> some View {
        var groups: [(kind: DiffWord.Kind, words: [DiffWord])] = []
        for word in diffs {
            if let last = groups.last, last.kind == word.kind {
                groups[groups.count - 1].words.append(word)
            } else {
                groups.append((kind: word.kind, words: [word]))
            }
        }

        return groups.enumerated().reduce(Text("")) { acc, pair in
            let (gi, group) = pair
            let sep = gi < groups.count - 1 ? " " : ""
            switch group.kind {
            case .correct:
                let joined = group.words.map(\.text).joined(separator: " ")
                return acc + Text(joined + sep).foregroundColor(.green).font(font)
            case .wrong:
                let wrong       = group.words.map(\.text).joined(separator: " ")
                let corrections = group.words.compactMap(\.correction).joined(separator: " ")
                let crossed     = Text(wrong + " ").strikethrough().foregroundColor(.red.opacity(0.5)).font(font)
                return corrections.isEmpty
                    ? acc + crossed
                    : acc + crossed + Text(corrections + sep).foregroundColor(.red).font(font)
            case .missing:
                let joined = group.words.map(\.text).joined(separator: " ")
                return acc + Text(joined + sep).foregroundColor(.secondary.opacity(0.5)).font(font)
            case .extra:
                let joined = group.words.map(\.text).joined(separator: " ")
                return acc + Text(joined + sep).strikethrough().foregroundColor(.red.opacity(0.5)).font(font)
            }
        }
        .lineSpacing(5)
        .minimumScaleFactor(0.75)
    }
}
