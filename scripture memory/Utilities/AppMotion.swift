import SwiftUI

// MARK: - Motion

/// One motion scale for the whole app, in three tiers by what's moving.
///
/// The tiers exist because responsiveness is not one number. Apple's guidance is
/// that the closer an animation is to the finger, the shorter it has to be: a
/// control reacting to a tap should read as *caused by* the tap, while something
/// travelling across the screen is allowed the time its distance implies. Sizing
/// everything the same is what makes an app feel sluggish — every one of these
/// used to sit between 0.3 and 0.4s, including a star toggling.
///
/// `snappy` rather than `spring(response:dampingFraction:)`: its `duration` is
/// perceptual — the time to *look* settled — where a spring's response is only
/// the first quarter-period, so the same number reads much slower.
enum AppMotion {
    /// A control answering a tap: press states, toggles, a symbol swapping.
    /// No overshoot — a control that wobbles reads as slower than it is.
    static let control  = Animation.snappy(duration: 0.15, extraBounce: 0)

    /// Content changing in place: a card revealing, a row expanding, chrome
    /// showing or hiding.
    static let content  = Animation.snappy(duration: 0.22, extraBounce: 0.05)

    /// Something crossing the screen: paging, scrubbing, a toast arriving.
    static let movement = Animation.snappy(duration: 0.28, extraBounce: 0.08)

    /// How long to wait before treating `movement` as finished — the settle
    /// guards that re-enable input after an animated jump. Kept just past
    /// `movement` so it tracks the tier instead of drifting from it.
    static let settle: TimeInterval = 0.3

    /// The same, for `control`-length changes.
    static let settleShort: TimeInterval = 0.16
}
