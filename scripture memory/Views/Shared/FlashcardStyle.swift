import SwiftUI

// MARK: - Flashcard Style

extension View {
    /// The printed card: paper stock with near-square corners, a soft shadow,
    /// on light paper unless the Cards setting says otherwise.
    func flashcardStyle() -> some View {
        let shape = RoundedRectangle(cornerRadius: 2, style: .continuous)
        return self
            .padding(AppLayout.cardPadding)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(PaperFace())
            .clipShape(shape)
            .shadow(color: .black.opacity(0.08), radius: 10, x: 0, y: 4)
            .contentShape(shape)
            .paperAppearance()
    }
}
