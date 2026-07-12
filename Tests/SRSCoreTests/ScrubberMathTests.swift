import XCTest
@testable import SRSCore

final class ScrubberMathTests: XCTestCase {

    func testFractionEndpoints() {
        XCTAssertEqual(ScrubberMath.fraction(index: 0, count: 10), 0.0, accuracy: 1e-9)
        XCTAssertEqual(ScrubberMath.fraction(index: 9, count: 10), 1.0, accuracy: 1e-9)
    }

    func testFractionDegenerateCounts() {
        XCTAssertEqual(ScrubberMath.fraction(index: 0, count: 1), 0.0)  // single item
        XCTAssertEqual(ScrubberMath.fraction(index: 4, count: 0), 0.0)  // empty
    }

    func testFractionClampsIndex() {
        XCTAssertEqual(ScrubberMath.fraction(index: -3, count: 10), 0.0)
        XCTAssertEqual(ScrubberMath.fraction(index: 99, count: 10), 1.0)
    }

    func testIndexFromFraction() {
        XCTAssertEqual(ScrubberMath.index(fraction: 0.0, count: 10), 0)
        XCTAssertEqual(ScrubberMath.index(fraction: 1.0, count: 10), 9)
        XCTAssertEqual(ScrubberMath.index(fraction: 0.5, count: 11), 5)
        XCTAssertEqual(ScrubberMath.index(fraction: -1.0, count: 10), 0)   // clamp low
        XCTAssertEqual(ScrubberMath.index(fraction: 2.0, count: 10), 9)    // clamp high
        XCTAssertEqual(ScrubberMath.index(fraction: 0.4, count: 1), 0)     // single
    }

    func testTrackTravel() {
        XCTAssertEqual(ScrubberMath.trackTravel(containerHeight: 100, thumbSize: 40, inset: 8), 44)
        XCTAssertEqual(ScrubberMath.trackTravel(containerHeight: 30, thumbSize: 40, inset: 8), 0) // never negative
    }

    func testThumbYEndpoints() {
        let travel = 200.0, inset = 8.0
        XCTAssertEqual(ScrubberMath.thumbY(index: 0, count: 10, travel: travel, inset: inset), inset, accuracy: 1e-9)
        XCTAssertEqual(ScrubberMath.thumbY(index: 9, count: 10, travel: travel, inset: inset), inset + travel, accuracy: 1e-9)
    }

    func testIndexForDragFromIndexRoundTrips() {
        let inset = 8.0, travel = 200.0, count = 10
        for i in 0..<count {
            let y = ScrubberMath.thumbY(index: i, count: count, travel: travel, inset: inset)
            let back = ScrubberMath.indexForDrag(startThumbY: y, translationY: 0,
                                                 inset: inset, travel: travel, count: count)
            XCTAssertEqual(back, i)
        }
    }

    func testIndexForDragTranslationAndClamps() {
        let inset = 8.0, travel = 180.0, count = 10   // 20pt per index
        let startY = ScrubberMath.thumbY(index: 0, count: count, travel: travel, inset: inset)
        XCTAssertEqual(ScrubberMath.indexForDrag(startThumbY: startY, translationY: 40,
                                                 inset: inset, travel: travel, count: count), 2)
        XCTAssertEqual(ScrubberMath.indexForDrag(startThumbY: startY, translationY: -999,
                                                 inset: inset, travel: travel, count: count), 0)
        XCTAssertEqual(ScrubberMath.indexForDrag(startThumbY: startY, translationY: 9999,
                                                 inset: inset, travel: travel, count: count), 9)
    }

    func testZeroTravelStaysAtZero() {
        XCTAssertEqual(ScrubberMath.indexForDrag(startThumbY: 0, translationY: 50,
                                                 inset: 8, travel: 0, count: 10), 0)
    }

    // MARK: - Continuous fraction helpers (boundary-safe thumb)

    func testThumbYFromFraction() {
        XCTAssertEqual(ScrubberMath.thumbY(fraction: 0.0, travel: 200, inset: 8), 8, accuracy: 1e-9)
        XCTAssertEqual(ScrubberMath.thumbY(fraction: 1.0, travel: 200, inset: 8), 208, accuracy: 1e-9)
        XCTAssertEqual(ScrubberMath.thumbY(fraction: 0.5, travel: 200, inset: 8), 108, accuracy: 1e-9)
        XCTAssertEqual(ScrubberMath.thumbY(fraction: -1.0, travel: 200, inset: 8), 8)   // clamp
        XCTAssertEqual(ScrubberMath.thumbY(fraction: 2.0, travel: 200, inset: 8), 208)  // clamp
    }

    func testFractionForDrag() {
        XCTAssertEqual(ScrubberMath.fractionForDrag(startThumbY: 8, translationY: 100, inset: 8, travel: 200), 0.5, accuracy: 1e-9)
        XCTAssertEqual(ScrubberMath.fractionForDrag(startThumbY: 8, translationY: -50, inset: 8, travel: 200), 0.0)  // clamp top
        XCTAssertEqual(ScrubberMath.fractionForDrag(startThumbY: 8, translationY: 999, inset: 8, travel: 200), 1.0)  // clamp bottom
        XCTAssertEqual(ScrubberMath.fractionForDrag(startThumbY: 8, translationY: 50, inset: 8, travel: 0), 0.0)     // zero travel
    }

    /// The top (fraction 0) and bottom (fraction 1) must be exactly reachable —
    /// this is the boundary bug (thumb stuck one card from the top) as a guard.
    func testFractionReachesBothEnds() {
        let travel = 300.0, inset = 8.0
        XCTAssertEqual(ScrubberMath.thumbY(fraction: 0, travel: travel, inset: inset), inset)
        XCTAssertEqual(ScrubberMath.thumbY(fraction: 1, travel: travel, inset: inset), inset + travel)
        XCTAssertEqual(ScrubberMath.index(fraction: 0, count: 60), 0)
        XCTAssertEqual(ScrubberMath.index(fraction: 1, count: 60), 59)
    }

    func testFractionThumbYRoundTrip() {
        var rng = SplitMix64(seed: 0xF00D_CAFE)
        for _ in 0..<5_000 {
            let f = Double.random(in: 0...1, using: &rng)
            let travel = Double(Int.random(in: 50...400, using: &rng))
            let inset = 8.0
            let y = ScrubberMath.thumbY(fraction: f, travel: travel, inset: inset)
            let back = ScrubberMath.fractionForDrag(startThumbY: y, translationY: 0, inset: inset, travel: travel)
            XCTAssertEqual(back, f, accuracy: 1e-9)
        }
    }

    /// thumbY → indexForDrag is an exact identity for any index/count/travel.
    func testRoundTripProperty() {
        var rng = SplitMix64(seed: 0x5C2B_BEEF)
        for _ in 0..<10_000 {
            let count  = Int.random(in: 1...50, using: &rng)
            let idx    = Int.random(in: 0..<count, using: &rng)
            let travel = Double(Int.random(in: 50...400, using: &rng))
            let inset  = 8.0
            let y = ScrubberMath.thumbY(index: idx, count: count, travel: travel, inset: inset)
            let back = ScrubberMath.indexForDrag(startThumbY: y, translationY: 0,
                                                 inset: inset, travel: travel, count: count)
            XCTAssertEqual(back, idx)
        }
    }
}
