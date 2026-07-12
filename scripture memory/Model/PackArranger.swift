import Foundation

/// Pure logic for applying a user's custom pack order + hidden set on top of the
/// natural pack list. Foundation-only so it can be unit-tested on CI.
///
/// `order` is a saved list of pack names. Packs not present in `order` (new
/// packs, first run) keep their natural position, appended after the ordered
/// ones. Names in `order` that no longer exist are ignored.
enum PackArranger {

    /// All pack names arranged by the saved order, with unknown packs appended
    /// in their natural order.
    static func arrangedNames(order: [String], all: [String]) -> [String] {
        let allSet = Set(all)
        var result: [String] = []
        var seen = Set<String>()
        for name in order where allSet.contains(name) && !seen.contains(name) {
            result.append(name)
            seen.insert(name)
        }
        for name in all where !seen.contains(name) {
            result.append(name)
            seen.insert(name)
        }
        return result
    }

    /// Arranged names with hidden packs removed.
    static func visibleNames(order: [String], hidden: Set<String>, all: [String]) -> [String] {
        arrangedNames(order: order, all: all).filter { !hidden.contains($0) }
    }

    /// Apply a move within the arranged order, returning the new order list.
    /// Mirrors SwiftUI's `move(fromOffsets:toOffset:)` semantics, but pure (the
    /// SwiftUI method isn't available on a Foundation-only CI target).
    static func movedOrder(arranged: [String], from source: IndexSet, to destination: Int) -> [String] {
        var names = arranged
        let moving = source.sorted().map { names[$0] }
        for i in source.sorted(by: >) { names.remove(at: i) }
        let removedBefore = source.filter { $0 < destination }.count
        let insertAt = min(max(destination - removedBefore, 0), names.count)
        names.insert(contentsOf: moving, at: insertAt)
        return names
    }
}
