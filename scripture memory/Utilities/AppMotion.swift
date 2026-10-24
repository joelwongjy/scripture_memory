import SwiftUI
import UIKit

// MARK: - Motion

/// The app's animation curves: Apple's built-in springs at their default
/// timings, in three tiers by what's moving.
///
/// - `control`: a control answering a tap (press states, toggles, a symbol
///   swapping). Shorter than the default, as Apple suggests for small, direct
///   feedback, and without bounce.
/// - `content`: content changing in place (a card revealing, a row expanding,
///   chrome showing or hiding). `.smooth`, SwiftUI's default spring.
/// - `movement`: something crossing the screen (paging, scrubbing, a toast
///   arriving). `.snappy`, the default spring with a little more energy.
///
/// With Reduce Motion on, every tier becomes a short ease with no spring, and
/// motion-only flourishes (the wrong-answer shake) are skipped.
enum AppMotion {
    static var reduceMotion: Bool { UIAccessibility.isReduceMotionEnabled }

    static var control: Animation {
        reduceMotion ? .easeInOut(duration: 0.2) : .snappy(duration: 0.3)
    }

    static var content: Animation {
        reduceMotion ? .easeInOut(duration: 0.25) : .smooth
    }

    static var movement: Animation {
        reduceMotion ? .easeInOut(duration: 0.25) : .snappy
    }

    /// How long to wait before treating `movement` as finished: the guards that
    /// re-enable input after an animated jump. Matches the springs' 0.5s.
    static let settle: TimeInterval = 0.5

    /// The same, for `control`-length changes.
    static let settleShort: TimeInterval = 0.3
}
