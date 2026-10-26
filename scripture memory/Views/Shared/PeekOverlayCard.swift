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
        VStack(alignment: .leading, spacing: 0) {
            if let pinned = verse.pinnedVersion {
                Text("(\(pinned))")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color.secondary)
                Spacer().frame(height: 6)
            }
            Text("\(verse.book) \(verse.reference)")
                .font(CardFont.font(.reference, size: 18))
                .foregroundStyle(Color.secondary)

            Spacer().frame(height: 10)

            Text(verse.title)
                .font(CardFont.font(.title, size: 16))
                .foregroundStyle(Color.secondary)
                .padding(.bottom, 6)

            Text(verse.verse)
                .font(CardFont.font(.body, size: 15))
                .lineSpacing(5)
                .foregroundStyle(Color.secondary)
                .minimumScaleFactor(0.75)

            Spacer(minLength: 6)

            if showCardLabel {
                Text(cardLabel)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(Color.secondary.opacity(0.5))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .flashcardStyle()
        .frame(width: width, height: height)
    }
}
