import XCTest
@testable import SRSCore

final class PackArrangerTests: XCTestCase {

    func testNoOrderKeepsNatural() {
        XCTAssertEqual(PackArranger.arrangedNames(order: [], all: ["a", "b", "c"]), ["a", "b", "c"])
    }

    func testCustomOrderApplied() {
        XCTAssertEqual(PackArranger.arrangedNames(order: ["c", "a", "b"], all: ["a", "b", "c"]), ["c", "a", "b"])
    }

    func testNewPacksAppendedInNaturalOrder() {
        // order knows a,b; c,d are new -> appended after, natural order preserved
        XCTAssertEqual(PackArranger.arrangedNames(order: ["b", "a"], all: ["a", "b", "c", "d"]),
                       ["b", "a", "c", "d"])
    }

    func testStaleOrderNamesIgnored() {
        // "x" no longer exists
        XCTAssertEqual(PackArranger.arrangedNames(order: ["x", "b", "a"], all: ["a", "b"]), ["b", "a"])
    }

    func testDuplicatesInOrderDeduped() {
        XCTAssertEqual(PackArranger.arrangedNames(order: ["a", "a", "b"], all: ["a", "b", "c"]),
                       ["a", "b", "c"])
    }

    func testVisibleRemovesHidden() {
        XCTAssertEqual(
            PackArranger.visibleNames(order: ["c", "a", "b"], hidden: ["a"], all: ["a", "b", "c"]),
            ["c", "b"])
    }

    func testVisibleAllHidden() {
        XCTAssertEqual(
            PackArranger.visibleNames(order: [], hidden: ["a", "b"], all: ["a", "b"]), [])
    }

    func testMoveReordering() {
        // move "a" (index 0) to the end
        let moved = PackArranger.movedOrder(arranged: ["a", "b", "c"], from: IndexSet(integer: 0), to: 3)
        XCTAssertEqual(moved, ["b", "c", "a"])
    }

    func testMoveUp() {
        let moved = PackArranger.movedOrder(arranged: ["a", "b", "c"], from: IndexSet(integer: 2), to: 0)
        XCTAssertEqual(moved, ["c", "a", "b"])
    }

    /// arranged is a permutation of `all` (no packs lost or duplicated), for any order.
    func testArrangedIsPermutationProperty() {
        var rng = SplitMix64(seed: 0xACED_F00D)
        let all = ["a", "b", "c", "d", "e", "f"]
        for _ in 0..<3_000 {
            var order: [String] = []
            for _ in 0..<Int.random(in: 0...8, using: &rng) {
                order.append(all.randomElement(using: &rng)!)
            }
            let arranged = PackArranger.arrangedNames(order: order, all: all)
            XCTAssertEqual(Set(arranged), Set(all))            // same membership
            XCTAssertEqual(arranged.count, all.count)          // no dupes/losses
        }
    }
}
