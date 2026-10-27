import SwiftUI

/// Card-style overlay matching the real card but with all text in secondary color.
/// Shown while the user holds a `PeekHoldButton`.
struct PeekOverlayCard: View {
    let verse:     Verse
    let cardLabel: String
    let width:     CGFloat
    let height:    CGFloat
    /// Matches the card underneath — see `FlashcardView.showCardLabel`.
    var showCardLabel: Bool = true

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            VStack(alignment: .leading, spacing: 0) {
                if let pinned = verse.pinnedVersion {
                    Text("(\(pinned))")
                        .font(.system(size: 10, weight: .bold))
                    Spacer().frame(height: 6)
                }
                Text("\(verse.book) \(verse.reference)")
                    .font(CardFont.font(.reference, size: FlashcardView.scaledTypeSize(base: 18, extra: 3.25, cardWidth: w)))

                Spacer().frame(height: 12)

                Text(verse.title)
                    .font(CardFont.font(.title, size: FlashcardView.scaledTypeSize(base: 16, extra: 2.75, cardWidth: w)))

                Spacer().frame(height: 8)

                FittedVerseText(text: verse.verse, lineSpacing: 5, minSize: 10,
                                maxSize: FlashcardView.scaledTypeSize(base: 16, extra: 3, cardWidth: w))

                if showCardLabel {
                    Spacer().frame(height: 16)
                    Text(cardLabel)
                        .font(.system(size: 12.5, weight: .medium))
                        .opacity(0.5)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
            .foregroundStyle(Color.secondary)
        }
        .flashcardStyle()
        .frame(width: width, height: height)
    }
}
