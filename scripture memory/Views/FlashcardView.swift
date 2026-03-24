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
    //
    // Word-count tiers keep long verses on-screen; `cardWidth` nudges type up on wider phones
    // (e.g. Pro Max) where the same pt sizes read small.

    /// Interpolates font size between `narrowWidth` and `wideWidth` (card inner width in pt).
    private func scaledTypeSize(base: CGFloat, extra: CGFloat, cardWidth: CGFloat, narrow: CGFloat = 322, wide: CGFloat = 398) -> CGFloat {
        let t = (cardWidth - narrow) / (wide - narrow)
        let u = min(1, max(0, t))
        return base + extra * u
    }

    private func verseFontSize(cardWidth: CGFloat) -> CGFloat {
        let count = verse.verseWords.count
        let base: CGFloat
        if count > 50 { base = 11.5 }
        else if count > 40 { base = 12.5 }
        else if count > 30 { base = 13.5 }
        else { base = 15.0 }
        // Card width ≈ screen − horizontal chrome; Pro Max ~390pt, standard ~350–360, smaller ~330.
        let widthBonus: CGFloat
        if cardWidth >= 382 { widthBonus = 1.5 }
        else if cardWidth >= 358 { widthBonus = 1.0 }
        else if cardWidth >= 346 { widthBonus = 0.5 }
        else { widthBonus = 0 }
        return base + widthBonus
    }

    private func verseLineSpacing(cardWidth: CGFloat) -> CGFloat {
        let count = verse.verseWords.count
        let base: CGFloat
        if count > 55 { base = 2.0 }
        else if count > 45 { base = 3.0 }
        else if count > 35 { base = 4.0 }
        else { base = 6.0 }
        let bonus = cardWidth >= 382 ? 1.0 : (cardWidth >= 352 ? 0.5 : 0)
        return base + bonus
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            VStack(alignment: .leading, spacing: 0) {
                if isReviewMode { reviewContent(cardWidth: w) } else { readContent(cardWidth: w) }
                Spacer(minLength: 6)
                Text(cardLabel)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .flashcardStyle()
    }

    // MARK: - Read Mode

    private func readContent(cardWidth: CGFloat) -> some View {
        let verseSize = verseFontSize(cardWidth: cardWidth)
        let lineGap = verseLineSpacing(cardWidth: cardWidth)
        let titleSize = scaledTypeSize(base: 15, extra: 3.5, cardWidth: cardWidth)
        let refSize = scaledTypeSize(base: 14, extra: 3.0, cardWidth: cardWidth)
        return VStack(alignment: .leading, spacing: 0) {
            Text(verse.title)
                .font(.system(size: titleSize, weight: .bold, design: .serif))
            Spacer().frame(height: 8)
            Text("\(verse.book) \(verse.reference)")
                .font(.system(size: refSize))
            Spacer().frame(height: 6)
            Text(verse.verse)
                .font(.system(size: verseSize, design: .serif))
                .lineSpacing(lineGap)
        }
    }

    // MARK: - Review Mode

    private func reviewContent(cardWidth: CGFloat) -> some View {
        let activeWords    = activeSection == .title ? verse.titleWords : verse.verseWords
        let activeRevealed = activeSection == .title ? titleRevealedCount : verseRevealedCount
        let refSize = scaledTypeSize(base: 18, extra: 3.25, cardWidth: cardWidth)
        let titleSectionSize = scaledTypeSize(base: 16, extra: 2.75, cardWidth: cardWidth)
        let verseSize = verseFontSize(cardWidth: cardWidth)

        return VStack(alignment: .leading, spacing: 0) {
            Text("\(verse.book) \(verse.reference)")
                .font(.system(size: refSize, weight: .bold, design: .serif))

            Spacer().frame(height: 12)

            sectionView(.title,
                         words: verse.titleWords,
                         revealed: titleRevealedCount,
                         cardWidth: cardWidth,
                         font: .system(size: titleSectionSize, weight: .bold, design: .serif))

            Spacer().frame(height: 8)

            sectionView(.verse,
                         words: verse.verseWords,
                         revealed: verseRevealedCount,
                         cardWidth: cardWidth,
                         font: .system(size: verseSize, design: .serif))

            if !hardMode && activeRevealed < activeWords.count {
                Spacer().frame(height: 10)
                progressBar(revealed: activeRevealed, total: activeWords.count)
            }
        }
    }

    // MARK: - Section View

    @ViewBuilder
    private func sectionView(_ section: CardSection, words: [String], revealed: Int, cardWidth: CGFloat, font: Font) -> some View {
        let isActive   = (activeSection == section)
        let isComplete = revealed >= words.count && !words.isEmpty
        let verseGap = verseLineSpacing(cardWidth: cardWidth)

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
            .lineSpacing(section == .verse ? verseGap : 4)

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
