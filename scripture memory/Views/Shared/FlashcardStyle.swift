import SwiftUI

// MARK: - Flashcard Style

extension View {
    /// Applies the standard card appearance: parchment background, rounded corners, shadows.
    func flashcardStyle() -> some View {
        self
            .padding(AppLayout.cardPadding)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(flashcardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppLayout.cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppLayout.cornerRadius, style: .continuous)
                    .stroke(Color(.separator).opacity(0.5), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.12), radius: 16, x: 0, y: 8)
            .shadow(color: .black.opacity(0.05), radius: 2,  x: 0, y: 1)
            .contentShape(RoundedRectangle(cornerRadius: AppLayout.cornerRadius, style: .continuous))
    }
}

/// Adaptive parchment-style background shared by all card types.
let flashcardBackground = Color(uiColor: UIColor { tc in
    tc.userInterfaceStyle == .dark
        ? UIColor(white: 0.13, alpha: 1)
        : UIColor(red: 0.98, green: 0.965, blue: 0.94, alpha: 1)
})
