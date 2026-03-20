import SwiftUI

enum ReviewSection: Hashable {
    case title, verse
}

struct FlashcardView: View {
    let verse: Verse
    let cardLabel: String
    let isReviewMode: Bool
    let titleRevealedCount: Int
    let verseRevealedCount: Int
    let activeSection: ReviewSection
    var onSectionTap: ((ReviewSection) -> Void)? = nil

    @AppStorage("hardMode") private var hardMode = false

    private let cardColor = Color(uiColor: UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(white: 0.13, alpha: 1)
            : UIColor(red: 0.98, green: 0.965, blue: 0.94, alpha: 1)
    })

    private var titleWords: [String] {
        verse.title.components(separatedBy: " ").filter { !$0.isEmpty }
    }

    private var verseWords: [String] {
        verse.verse.components(separatedBy: " ").filter { !$0.isEmpty }
    }

    private var activeWords: [String] {
        activeSection == .title ? titleWords : verseWords
    }

    private var activeRevealed: Int {
        activeSection == .title ? titleRevealedCount : verseRevealedCount
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if isReviewMode {
                reviewContent
            } else {
                readContent
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
        .contentShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Read Mode

    private var readContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(verse.title)
                .font(.system(size: 18, weight: .bold, design: .serif))
                .foregroundColor(.primary)

            Spacer().frame(height: 10)

            Text("\(verse.book) \(verse.reference)")
                .font(.system(size: 15))
                .foregroundColor(.primary)

            Spacer().frame(height: 8)

            Text(verse.verse)
                .font(.system(size: 15, design: .serif))
                .foregroundColor(.primary)
                .lineSpacing(6)
                .minimumScaleFactor(0.7)
        }
    }

    // MARK: - Review Mode

    private var reviewContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("\(verse.book) \(verse.reference)")
                .font(.system(size: 18, weight: .bold, design: .serif))
                .foregroundColor(.primary)

            Spacer().frame(height: 12)

            sectionView(
                section: .title,
                words: titleWords,
                revealed: titleRevealedCount,
                font: .system(size: 16, weight: .bold, design: .serif)
            )

            Spacer().frame(height: 8)

            sectionView(
                section: .verse,
                words: verseWords,
                revealed: verseRevealedCount,
                font: .system(size: 15, design: .serif)
            )

            if !hardMode && activeRevealed < activeWords.count {
                Spacer().frame(height: 10)
                reviewProgress
            }
        }
    }

    @ViewBuilder
    private func sectionView(section: ReviewSection, words: [String], revealed: Int, font: Font) -> some View {
        let isActive = activeSection == section
        let isComplete = revealed >= words.count && !words.isEmpty

        HStack(alignment: .top, spacing: 4) {
            Group {
                if isComplete {
                    completedText(words: words, font: font)
                        .lineSpacing(section == .verse ? 6 : 4)
                } else if isActive {
                    activeText(words: words, revealed: revealed, font: font)
                        .lineSpacing(section == .verse ? 6 : 4)
                        .animation(.easeOut(duration: 0.2), value: revealed)
                } else {
                    inactiveText(section: section, words: words, revealed: revealed, font: font)
                        .lineSpacing(section == .verse ? 6 : 4)
                }
            }
            .minimumScaleFactor(0.7)

            if isComplete {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green.opacity(0.6))
                    .font(.system(size: 10))
            }
        }
        .overlay(alignment: .leading) {
            if isActive && !isComplete {
                RoundedRectangle(cornerRadius: 0.5)
                    .fill(Color.blue.opacity(0.5))
                    .frame(width: 2)
                    .offset(x: -6)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { onSectionTap?(section) }
    }

    private func sectionLabel(_ section: ReviewSection) -> Text {
        let label = section == .title ? "Title" : "Verse"
        return Text(label)
            .font(.system(size: 18, weight: .medium, design: .serif))
            .foregroundColor(Color.gray.opacity(0.35))
    }

    private func activeText(words: [String], revealed: Int, font: Font) -> Text {
        if hardMode {
            if revealed == 0 {
                return sectionLabel(activeSection)
            }
            return words.prefix(revealed).enumerated().reduce(Text("")) { result, pair in
                let (index, word) = pair
                let sep = index < revealed - 1 ? " " : ""
                return result + Text(word + sep).foregroundColor(.primary).font(font)
            }
        }
        return words.enumerated().reduce(Text("")) { result, pair in
            let (index, word) = pair
            let sep = index < words.count - 1 ? " " : ""
            if index < revealed {
                return result + Text(word + sep).foregroundColor(.primary).font(font)
            } else if index == revealed {
                return result + Text(masked(word) + sep).foregroundColor(.blue).font(font)
            } else {
                return result + Text(masked(word) + sep).foregroundColor(Color.gray.opacity(0.28)).font(font)
            }
        }
    }

    private func inactiveText(section: ReviewSection, words: [String], revealed: Int, font: Font) -> Text {
        if hardMode {
            if revealed > 0 {
                return words.prefix(revealed).enumerated().reduce(Text("")) { result, pair in
                    let (index, word) = pair
                    let sep = index < revealed - 1 ? " " : ""
                    return result + Text(word + sep).foregroundColor(.primary.opacity(0.5)).font(font)
                }
            }
            return sectionLabel(section)
        }
        return words.enumerated().reduce(Text("")) { result, pair in
            let (index, word) = pair
            let sep = index < words.count - 1 ? " " : ""
            return result + Text(masked(word) + sep).foregroundColor(Color.gray.opacity(0.22)).font(font)
        }
    }

    private func completedText(words: [String], font: Font) -> Text {
        words.enumerated().reduce(Text("")) { result, pair in
            let (index, word) = pair
            let sep = index < words.count - 1 ? " " : ""
            return result + Text(word + sep).foregroundColor(.primary).font(font)
        }
    }

    private var reviewProgress: some View {
        HStack(spacing: 6) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color(.systemGray5))
                    Capsule()
                        .fill(Color.blue.opacity(0.5))
                        .frame(width: max(4, geo.size.width * Double(activeRevealed) / Double(max(1, activeWords.count))))
                        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: activeRevealed)
                }
            }
            .frame(height: 3)

            Text("\(activeRevealed)/\(activeWords.count)")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundColor(.secondary)
        }
    }

    private func masked(_ word: String) -> String {
        var result = ""
        for char in word {
            result.append(char.isLetter ? "_" : char)
        }
        return result
    }
}

#Preview {
    FlashcardView(
        verse: packs.first!.verses[0],
        cardLabel: "A-1 · TMS 60",
        isReviewMode: true,
        titleRevealedCount: 0,
        verseRevealedCount: 0,
        activeSection: .verse
    )
    .aspectRatio(5.0/3.0, contentMode: .fit)
    .padding(24)
    .background(Color(.systemGroupedBackground))
}
