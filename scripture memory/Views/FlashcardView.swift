import SwiftUI

struct FlashcardView: View {
    let verse:               Verse
    let cardLabel:           String
    let isReviewMode:        Bool
    let titleRevealedCount:  Int
    let verseRevealedCount:  Int
    let activeSection:       CardSection
    var onSectionTap:        ((CardSection) -> Void)? = nil

    /// Marks this card as the "current stopped verse" (the learning cursor) with a
    /// small badge — shown wherever the verse appears: study card and test card.
    var isCurrentLearning:   Bool = false

    /// When set (read mode, on the cursor card) the badge becomes a tappable
    /// "Mark as Complete" button so the current verse can be marked right on the
    /// card — read mode has no test-completion event to surface it otherwise.
    var onMarkComplete:      (() -> Void)? = nil

    /// Whether tap-to-flip is live (read mode only). Callers pass `false` for
    /// the non-interactive cards peeking out of the stack so a stray tap on an
    /// exposed edge can't flip a card that isn't front-most.
    var allowsFlip:          Bool = true

    @AppStorage("hardMode") private var hardMode = false

    // MARK: - Flip (read mode)
    //
    // The physical pack cards are two-sided: verse text on one face, topic +
    // reference on the other, so you quiz yourself by flipping. Tap flips this
    // card the same way: a quick edge-on turn with a lift, the content swaps
    // while the card is edge-on (never mirrored), and it settles with a spring.

    @State private var showsQuizSide = false
    @State private var flipRotation: Double  = 0
    @State private var flipScale:    CGFloat = 1
    @State private var isFlipping             = false

    private var canFlip: Bool { !isReviewMode && allowsFlip }

    private func flip() {
        guard canFlip, !isFlipping else { return }
        isFlipping = true
        HapticEngine.soft()
        withAnimation(.easeIn(duration: 0.16)) {
            flipRotation = 90
            flipScale = 1.05
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
            // The card may have changed mid-flip (swipe, scrub) — resetFlip()
            // clears `isFlipping`, and this pending phase must not fire then.
            guard isFlipping else { return }
            showsQuizSide.toggle()
            // Jump to the mirrored edge without animating so the swap happens
            // while the card is edge-on and text is never seen reversed.
            var t = Transaction(); t.disablesAnimations = true
            withTransaction(t) { flipRotation = -90 }
            HapticEngine.medium()
            withAnimation(.spring(response: 0.32, dampingFraction: 0.72)) {
                flipRotation = 0
                flipScale = 1
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { isFlipping = false }
        }
    }

    private func resetFlip() {
        isFlipping    = false
        showsQuizSide = false
        flipRotation  = 0
        flipScale     = 1
    }

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
            VStack(alignment: .leading, spacing: 0) {
                if isReviewMode {
                    reviewContent(cardSize: geo.size)
                } else if showsQuizSide {
                    quizContent(cardSize: geo.size)
                } else {
                    readContent(cardSize: geo.size)
                }
                Spacer(minLength: 16)
                HStack(spacing: 6) {
                    Text(cardLabel)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                    Spacer(minLength: 8)
                    if isCurrentLearning {
                        if let onMarkComplete {
                            markCompleteButton(onMarkComplete)
                        } else {
                            currentBadge
                        }
                    }
                    if canFlip { flipHint }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .flashcardStyle(edge: packColor(forPackName: verse.packName))
        .rotation3DEffect(.degrees(flipRotation), axis: (x: 0, y: 1, z: 0), perspective: 0.35)
        .scaleEffect(flipScale)
        // Low-priority so the mark-complete button and section taps still win;
        // masked to subviews-only when flipping isn't available here.
        .gesture(TapGesture().onEnded { flip() }, including: canFlip ? .all : .subviews)
        .onChange(of: verse.id) { _, _ in resetFlip() }
    }

    /// Footer affordance naming the hidden face — "Quiz" on the verse side,
    /// "Verse" on the quiz side — so the flip is discoverable without chrome.
    private var flipHint: some View {
        HStack(spacing: 3) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 8, weight: .bold))
            Text(showsQuizSide ? "Verse" : "Quiz")
                .font(.system(size: 9, weight: .semibold))
        }
        .foregroundStyle(.tertiary)
        .accessibilityLabel(showsQuizSide ? "Flip to verse side" : "Flip to quiz side")
    }

    /// Green "Mark as Complete" pill — the on-card action for the current verse in
    /// read mode. Replaces the badge (which it implies) when an action is provided.
    private func markCompleteButton(_ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 11, weight: .bold))
                Text("Mark as Complete")
                    .font(.system(size: 11, weight: .bold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Capsule().fill(Theme.successGradient))
        }
        .buttonStyle(Theme.SpringyButtonStyle())
        .accessibilityLabel("Mark current verse as complete")
    }

    /// Small "Current" chip marking the learning-cursor verse on any flashcard —
    /// a bookmark (distinct from the pin used for the Home spotlight) so it reads
    /// as "this is where you stopped."
    private var currentBadge: some View {
        HStack(spacing: 3) {
            Image(systemName: "bookmark.fill")
                .font(.system(size: 8, weight: .bold))
            Text("Current")
                .font(.system(size: 9, weight: .bold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(Capsule().fill(Color.accentColor))
        .accessibilityLabel("Current verse")
    }

    // MARK: - Read Mode

    private func readContent(cardSize: CGSize) -> some View {
        let cardWidth = cardSize.width
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
            // Scales the verse down to fit (never truncates) but stays within a
            // calm reading range — short verses don't balloon to headline size.
            FittedVerseText(text: verse.verse, lineSpacing: lineGap, minSize: 11, maxSize: 15)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: - Quiz Side (read-mode flip)

    /// The reverse of the printed card: topic and reference only, centered —
    /// enough to prompt recall, nothing that gives the verse away.
    private func quizContent(cardSize: CGSize) -> some View {
        let cardWidth = cardSize.width
        let titleSize = scaledTypeSize(base: 20, extra: 4.0, cardWidth: cardWidth)
        let refSize   = scaledTypeSize(base: 15, extra: 3.0, cardWidth: cardWidth)
        return VStack(spacing: 10) {
            Spacer(minLength: 0)
            Text(verse.title)
                .font(.system(size: titleSize, weight: .bold, design: .serif))
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.7)
            Text("\(verse.book) \(verse.reference)")
                .font(.system(size: refSize, design: .serif))
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Review Mode

    private func reviewContent(cardSize: CGSize) -> some View {
        let cardWidth = cardSize.width
        let activeWords    = activeSection == .title ? verse.titleWords : verse.verseWords
        let activeRevealed = activeSection == .title ? titleRevealedCount : verseRevealedCount
        let refSize = scaledTypeSize(base: 18, extra: 3.25, cardWidth: cardWidth)
        let titleSectionSize = scaledTypeSize(base: 16, extra: 2.75, cardWidth: cardWidth)
        let verseGap = verseLineSpacing(cardWidth: cardWidth)

        // Size the verse to the height the layout actually leaves after the
        // reference, title row, gaps, progress bar and card label — so it fills
        // the card and never truncates, instead of guessing from word count.
        let refH    = VerseFit.height("\(verse.book) \(verse.reference)", width: cardWidth, size: refSize, weight: .bold, lineSpacing: 0)
        let titleH  = VerseFit.height(verse.title, width: cardWidth, size: titleSectionSize, weight: .bold, lineSpacing: 4)
        let showsProgress = !hardMode && activeRevealed < activeWords.count
        // Count everything below the verse so the fit target matches the space
        // that's actually free: the progress block (spacer + bar) and the card's
        // own bottom spacer + label. Undercounting here picks a font one step too
        // big — which is exactly what made long verses overflow and truncate.
        let reserved = refH + 12 + titleH + 8 + (showsProgress ? 24 : 0) + 34
        let avail = max(48, cardSize.height - reserved)
        let verseSize = VerseFit.fontSize(verse.verse, width: cardWidth, height: avail,
                                          lineSpacing: verseGap, minSize: 10, maxSize: 16)

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
                    .foregroundStyle(Theme.success)
                    .font(.system(size: 10))
            }
        }
        .overlay(alignment: .leading) {
            if isActive && !isComplete {
                RoundedRectangle(cornerRadius: 0.5, style: .continuous)
                    .fill(Color.accentColor)
                    .frame(width: 2)
                    .offset(x: -6)
            }
        }
        .contentShape(Rectangle())
        // A finished section (all words revealed) can't be re-focused — tapping it
        // shouldn't pull the keyboard off the section you're still working on.
        .onTapGesture { if !isComplete { onSectionTap?(section) } }
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
                return acc + Text(masked(word) + sep).foregroundColor(.accentColor).font(font)
            } else {
                // Semantic `.tertiary` adapts to both modes instead of the old
                // hardcoded `.gray.opacity(0.28)`, which fell below AA in dark.
                return acc + Text(masked(word) + sep).foregroundStyle(.tertiary).font(font)
            }
        }
    }

    private func inactiveText(section: CardSection, words: [String], revealed: Int, font: Font) -> Text {
        if hardMode {
            guard revealed > 0 else { return placeholder(for: section) }
            return words.prefix(revealed).enumerated().reduce(Text("")) { acc, pair in
                let (i, word) = pair
                let sep = i < revealed - 1 ? " " : ""
                return acc + Text(word + sep).foregroundStyle(.secondary).font(font)
            }
        }
        // Keep already-revealed words visible (de-emphasized) even when this
        // isn't the active section. Switching sections must NOT hide the
        // progress you've made — only the still-masked words stay hidden.
        return words.enumerated().reduce(Text("")) { acc, pair in
            let (i, word) = pair
            let sep = i < words.count - 1 ? " " : ""
            if i < revealed {
                return acc + Text(word + sep).foregroundStyle(.secondary).font(font)
            }
            return acc + Text(masked(word) + sep).foregroundStyle(.quaternary).font(font)
        }
    }

    private func placeholder(for section: CardSection) -> Text {
        Text(section == .title ? "Title" : "Verse")
            .font(.system(size: 18, weight: .medium, design: .serif))
            .foregroundStyle(.tertiary)
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
                    // Emerald (matching the completion check) so it reads as
                    // "progress made" and doesn't blur into the lapis active-section
                    // bar / next-word accent sitting right above it.
                    Capsule()
                        .fill(Theme.success)
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
