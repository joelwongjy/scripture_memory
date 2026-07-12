import UIKit

/// Thin wrappers around UIKit feedback generators for consistent haptic responses.
enum HapticEngine {
    static func light()   { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func error()   { UINotificationFeedbackGenerator().notificationOccurred(.error) }
}
