import Foundation

/// Pure, dependency-free SRS math. Deliberately isolated from `SRSStore` and the
/// main actor so it can be unit-tested directly (including on Linux CI, which has
/// no UIKit/SwiftUI and no iCloud key-value store).
enum SRSMath {

    /// Distributes a whole-number `budget` across `candidatesInOrder`, taking as
    /// much as possible from each entry in turn before moving to the next.
    /// Returns the amount taken from each entry, in the same order.
    ///
    /// This is the core of the daily new-card "drip": a single GLOBAL cap shared
    /// across packs, handed out pack-by-pack in list order. Guarantees:
    /// - `0 <= result[i] <= max(0, candidatesInOrder[i])`
    /// - `result.reduce(0, +) == min(max(0, budget), totalAvailable)`
    /// - front-loaded: once the budget is exhausted, every later entry is 0.
    static func dripBudget(_ budget: Int, across candidatesInOrder: [Int]) -> [Int] {
        var remaining = max(0, budget)
        return candidatesInOrder.map { raw in
            let available = max(0, raw)
            let take = min(remaining, available)
            remaining -= take
            return take
        }
    }
}
