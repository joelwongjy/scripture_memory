import XCTest
@testable import SRSCore

final class SRSMathTests: XCTestCase {

    /// The exact reported bug: 4 cards due today, several packs turned on. Pack A
    /// only has due learning/review (0 new candidates); packs B/C/D each have new
    /// verses. The new-card cap is GLOBAL (here 2), so only 2 new cards are served
    /// total — all from the first pack that has them. The old per-pack display
    /// showed "2 new" on EACH of B/C/D ([0,2,2,2]); the drip yields [0,2,0,0].
    func testReportedBugScenario() {
        XCTAssertEqual(SRSMath.dripBudget(2, across: [0, 5, 5, 5]), [0, 2, 0, 0])
    }

    func testKnownCases() {
        XCTAssertEqual(SRSMath.dripBudget(0, across: [3, 3]), [0, 0])      // no budget
        XCTAssertEqual(SRSMath.dripBudget(-5, across: [3]), [0])           // negative budget
        XCTAssertEqual(SRSMath.dripBudget(5, across: [-2, 3]), [0, 3])     // negative candidates
        XCTAssertEqual(SRSMath.dripBudget(5, across: []), [])              // no packs
        XCTAssertEqual(SRSMath.dripBudget(10, across: [2, 3]), [2, 3])     // budget exceeds supply
        XCTAssertEqual(SRSMath.dripBudget(3, across: [2, 5]), [2, 1])      // spills into 2nd pack
    }

    /// Randomized property check of the invariants the dashboard relies on.
    func testProperties() {
        var rng = SplitMix64(seed: 0xCAFE_BABE)
        for _ in 0..<20_000 {
            let budget = Int.random(in: -3...12, using: &rng)
            let n = Int.random(in: 0...8, using: &rng)
            var cands: [Int] = []
            for _ in 0..<n { cands.append(Int.random(in: -2...9, using: &rng)) }
            let res = SRSMath.dripBudget(budget, across: cands)
            let avail = cands.map { max(0, $0) }
            let effBudget = max(0, budget)

            // length preserved
            XCTAssertEqual(res.count, cands.count)
            // each entry within [0, available]
            for (r, a) in zip(res, avail) { XCTAssertTrue(r >= 0 && r <= a) }
            // total == min(budget, total available) -> guarantees hero == sum(rows)
            XCTAssertEqual(res.reduce(0, +), min(effBudget, avail.reduce(0, +)))
            // front-loaded: a short-changed entry means the budget is fully spent,
            // so every later entry must be 0.
            var spent = 0
            for i in res.indices {
                if res[i] < avail[i] {
                    XCTAssertEqual(effBudget - spent - res[i], 0)
                    XCTAssertTrue(res[(i + 1)...].allSatisfy { $0 == 0 })
                    break
                }
                spent += res[i]
            }
        }
    }
}
