import UIKit

/// Thin wrappers around UIKit feedback generators for consistent haptic responses.
enum HapticEngine {
    static func light()   { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    /// A softer, quieter tick — the start of a card flip, a page settling.
    static func soft()    { UIImpactFeedbackGenerator(style: .soft).impactOccurred() }
    /// A solid mid-weight knock — a card landing on a pile.
    static func medium()  { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func error()   { UINotificationFeedbackGenerator().notificationOccurred(.error) }
}
