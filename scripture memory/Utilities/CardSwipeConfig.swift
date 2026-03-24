import CoreGraphics

// MARK: - Card deck swipe (shared by pack study + test session)

/// Centralizes swipe thresholds and drag math so both card stacks stay in sync.
enum CardSwipeConfig {
    static let threshold: CGFloat = 80
    static let velocityThreshold: CGFloat = 400
    static let flyWidth: CGFloat = 600
    static let prevCardOffset: CGFloat = 420

    private static let forwardDragCap: CGFloat = 150
    private static let backwardDragCap: CGFloat = 200

    static func forwardDragProgress(dragWidth: CGFloat) -> CGFloat {
        guard dragWidth < 0 else { return 0 }
        return min(abs(dragWidth) / forwardDragCap, 1)
    }

    static func backwardDragProgress(dragWidth: CGFloat) -> CGFloat {
        guard dragWidth > 0 else { return 0 }
        return min(dragWidth / backwardDragCap, 1)
    }

    /// Rubber-band when swiping past first/last card.
    static func clampedDragTranslation(_ translation: CGSize, canGoNext: Bool, canGoPrev: Bool) -> CGSize {
        let tx = translation.width
        if (tx < 0 && canGoNext) || (tx > 0 && canGoPrev) {
            return translation
        }
        return CGSize(width: tx * 0.15, height: translation.height * 0.15)
    }
}
