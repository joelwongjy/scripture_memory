import SwiftUI

struct FlashcardView: View {
    let verse:               Verse
    let cardLabel:           String
    let isReviewMode:        Bool
    let titleRevealedCount:  Int
    let verseRevealedCount:  Int
    let activeSection:       CardSection
    var onSectionTap:        ((CardSection) -> Void)? = nil

    @AppStorage("hardMode") private var hardMode = false

    // MARK: - Adaptive Typography

    private var verseFontSize: CGFloat {
        let count = verse.verseWords.count
        if count > 55 { return 11.0 }
        if count > 45 { return 12.0 }
        if count > 35 { return 13.5 }
        return 15.0
    }

    private var verseLineSpacing: CGFloat {
        let count = verse.verseWords.count
        if count > 55 { return 2.0 }
        if count > 45 { return 3.0 }
        if count > 35 { return 4.0 }
        return 6.0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if isReviewMode { reviewContent } else { readContent }
            Spacer(minLength: 6)
            Text(cardLabel)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.secondary)
        }
        .flashcardStyle()
    }

    // MARK: - Read Mode

    private var readContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(verse.title)
                .font(.system(size: 18, weight: .bold, design: .serif))
            Spacer().frame(height: 10)
            Text("\(verse.book) \(verse.reference)")
                .font(.system(size: 15))
            Spacer().frame(height: 8)
            Text(verse.verse)
                .font(.system(size: verseFontSize, design: .serif))
                .lineSpacing(verseLineSpacing)
        }
    }

    // MARK: - Review Mode

    private var reviewContent: some View {
        let activeWords    = activeSection == .title ? verse.titleWords : verse.verseWords
        let activeRevealed = activeSection == .title ? titleRevealedCount : verseRevealedCount

        return VStack(alignment: .leading, spacing: 0) {
            Text("\(verse.book) \(verse.reference)")
                .font(.system(size: 18, weight: .bold, design: .serif))

            Spacer().frame(height: 12)

            sectionView(.title,
                         words: verse.titleWords,
                         revealed: titleRevealedCount,
                         font: .system(size: 16, weight: .bold, design: .serif))

            Spacer().frame(height: 8)

            sectionView(.verse,
                         words: verse.verseWords,
                         revealed: verseRevealedCount,
                         font: .system(size: verseFontSize, design: .serif))

            if !hardMode && activeRevealed < activeWords.count {
                Spacer().frame(height: 10)
                progressBar(revealed: activeRevealed, total: activeWords.count)
            }
        }
    }

    // MARK: - Section View

    @ViewBuilder
    private func sectionView(_ section: CardSection, words: [String], revealed: Int, font: Font) -> some View {
        let isActive   = (activeSection == section)
        let isComplete = revealed >= words.count && !words.isEmpty

        HStack(alignment: .top, spacing: 4) {
            Group {
                if isComplete {
                    completedText(words, font: font)
                } else if isActive {
                    activeText(words: words, revealed: revealed, font: font)
                        .animation(.easeOut(duration: 0.2), value: revealed)
                } else {
                    inactiveText(section: section, words: words, revealed: revealed, font: font)
                }
            }
            .lineSpacing(section == .verse ? verseLineSpacing : 4)

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

    // MARK: - Text Builders
    //
    // SwiftUI's `Text` concatenation is the only way to mix per-word colours inline,
    // so these functions reduce over word arrays to build a single attributed `Text`.

    private func completedText(_ words: [String], font: Font) -> Text {
        words.enumerated().reduce(Text("")) { acc, pair in
            let (i, word) = pair
            let sep = i < words.count - 1 ? " " : ""
            return acc + Text(word + sep).foregroundColor(.primary).font(font)
        }
    }

    private func activeText(words: [String], revealed: Int, font: Font) -> Text {
        if hardMode {
            guard revealed > 0 else { return placeholder(for: activeSection) }
            return words.prefix(revealed).enumerated().reduce(Text("")) { acc, pair in
                let (i, word) = pair
                let sep = i < revealed - 1 ? " " : ""
                return acc + Text(word + sep).foregroundColor(.primary).font(font)
            }
        }
        return words.enumerated().reduce(Text("")) { acc, pair in
            let (i, word) = pair
            let sep = i < words.count - 1 ? " " : ""
            if i < revealed {
                return acc + Text(word + sep).foregroundColor(.primary).font(font)
            } else if i == revealed {
                return acc + Text(masked(word) + sep).foregroundColor(.blue).font(font)
            } else {
                return acc + Text(masked(word) + sep).foregroundColor(.gray.opacity(0.28)).font(font)
            }
        }
    }

    private func inactiveText(section: CardSection, words: [String], revealed: Int, font: Font) -> Text {
        if hardMode {
            guard revealed > 0 else { return placeholder(for: section) }
            return words.prefix(revealed).enumerated().reduce(Text("")) { acc, pair in
                let (i, word) = pair
                let sep = i < revealed - 1 ? " " : ""
                return acc + Text(word + sep).foregroundColor(.primary.opacity(0.5)).font(font)
            }
        }
        return words.enumerated().reduce(Text("")) { acc, pair in
            let (i, word) = pair
            let sep = i < words.count - 1 ? " " : ""
            return acc + Text(masked(word) + sep).foregroundColor(.gray.opacity(0.22)).font(font)
        }
    }

    private func placeholder(for section: CardSection) -> Text {
        Text(section == .title ? "Title" : "Verse")
            .font(.system(size: 18, weight: .medium, design: .serif))
            .foregroundColor(.gray.opacity(0.35))
    }

    private func masked(_ word: String) -> String {
        String(word.map { $0.isLetter ? "_" : $0 })
    }

    // MARK: - Progress Bar

    private func progressBar(revealed: Int, total: Int) -> some View {
        HStack(spacing: 6) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color(.systemGray5))
                    Capsule()
                        .fill(Color.blue.opacity(0.5))
                        .frame(width: max(4, geo.size.width * Double(revealed) / Double(max(1, total))))
                        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: revealed)
                }
            }
            .frame(height: 3)

            Text("\(revealed)/\(total)")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    FlashcardView(
        verse: packsNIV84.first!.verses[0],
        cardLabel: "A-1 · TMS 60",
        isReviewMode: true,
        titleRevealedCount: 0,
        verseRevealedCount: 0,
        activeSection: .verse
    )
    .aspectRatio(5.0 / 3.0, contentMode: .fit)
    .padding(24)
    .background(Color(.systemGroupedBackground))
}
