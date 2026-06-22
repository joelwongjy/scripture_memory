import Foundation

/// Pure geometry for the vertical fast-scroll thumb (index ↔ track position).
/// Uses `Double` (no CoreGraphics) so it stays Foundation-only and unit-testable
/// on a Linux CI runner. The SwiftUI overlay converts to `CGFloat` at the edge.
enum ScrubberMath {

    /// Track fraction [0,1] for a verse index. Single-item lists pin to 0.
    static func fraction(index: Int, count: Int) -> Double {
        guard count > 1 else { return 0 }
        let clamped = min(max(index, 0), count - 1)
        return Double(clamped) / Double(count - 1)
    }

    /// Verse index nearest a track fraction [0,1].
    static func index(fraction: Double, count: Int) -> Int {
        guard count > 1 else { return 0 }
        let f = min(max(fraction, 0), 1)
        let raw = Int((f * Double(count - 1)).rounded())
        return min(max(raw, 0), count - 1)
    }

    /// How far the thumb's top can travel: container minus its own height and
    /// the symmetric vertical insets. Never negative.
    static func trackTravel(containerHeight: Double, thumbSize: Double, inset: Double) -> Double {
        max(0, containerHeight - 2 * inset - thumbSize)
    }

    /// Thumb top-Y for a verse index.
    static func thumbY(index: Int, count: Int, travel: Double, inset: Double) -> Double {
        inset + fraction(index: index, count: count) * travel
    }

    /// Thumb top-Y for a CONTINUOUS scroll fraction [0,1]. Used so the thumb
    /// tracks the live scroll offset smoothly and reaches both ends exactly
    /// (index-snapping at `anchor: .center` sticks one card in from each end).
    static func thumbY(fraction: Double, travel: Double, inset: Double) -> Double {
        inset + min(max(fraction, 0), 1) * travel
    }

    /// Continuous track fraction [0,1] for a drag (start thumb-Y + translation).
    static func fractionForDrag(startThumbY: Double, translationY: Double,
                                inset: Double, travel: Double) -> Double {
        guard travel > 0 else { return 0 }
        return max(0, min(1, ((startThumbY + translationY) - inset) / travel))
    }

    /// Map a drag (start thumb-Y + translation) to a verse index.
    static func indexForDrag(startThumbY: Double, translationY: Double,
                             inset: Double, travel: Double, count: Int) -> Int {
        guard travel > 0 else { return 0 }
        let targetTopInTrack = (startThumbY + translationY) - inset
        let fraction = max(0, min(travel, targetTopInTrack)) / travel
        return index(fraction: fraction, count: count)
    }
}
