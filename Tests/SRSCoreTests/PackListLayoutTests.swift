import XCTest
@testable import SRSCore

final class PackListLayoutTests: XCTestCase {

    func testPhonesKeepOneFullWidthColumn() {
        let layout = PackListLayout(width: 408, spacing: 16)
        XCTAssertEqual(layout.columns, 1)
        XCTAssertEqual(layout.cardWidth, 408)
        XCTAssertEqual(layout.centerOffset(ofCard: 5), 0)
    }

    func testWiderWindowsSplitIntoColumnsThatFillTheWidth() {
        let duoOpen = PackListLayout(width: 637, spacing: 16)
        XCTAssertEqual(duoOpen.columns, 2)
        XCTAssertEqual(duoOpen.cardWidth, 310.5)

        let tablet = PackListLayout(width: 1000, spacing: 16)
        XCTAssertEqual(tablet.columns, 3)
        XCTAssertEqual(CGFloat(tablet.columns) * tablet.cardWidth + 2 * tablet.spacing, 1000)
    }

    func testColumnBoundaries() {
        XCTAssertEqual(PackListLayout.columns(forWidth: 539), 1)
        XCTAssertEqual(PackListLayout.columns(forWidth: 540), 2)
        XCTAssertEqual(PackListLayout.columns(forWidth: 959), 2)
        XCTAssertEqual(PackListLayout.columns(forWidth: 960), 3)
    }

    func testRowsAndColumnsOfCards() {
        let layout = PackListLayout(width: 637, spacing: 16)
        XCTAssertEqual(layout.row(of: 5), 2)
        XCTAssertEqual(layout.column(of: 5), 1)
        XCTAssertEqual(layout.firstCard(inRow: 2), 4)
        XCTAssertEqual(layout.rows(forCount: 5), 3)
        XCTAssertEqual(layout.rows(forCount: 6), 3)
    }

    func testOffsetsReachCardsBeforeTheFirst() {
        let layout = PackListLayout(width: 637, spacing: 16)
        XCTAssertEqual(layout.row(of: -1), -1)
        XCTAssertEqual(layout.column(of: -1), 1)
        XCTAssertEqual(layout.row(of: -2), -1)
        XCTAssertEqual(layout.column(of: -2), 0)
        XCTAssertEqual(layout.row(of: -3), -2)
    }

    func testOffsetBetweenCardsFollowsTheGrid() {
        let layout = PackListLayout(width: 637, spacing: 16)
        let next = layout.offset(from: 2, by: 1)
        XCTAssertEqual(next.columns, 1)
        XCTAssertEqual(next.rows, 0)
        let wrapped = layout.offset(from: 3, by: 1)
        XCTAssertEqual(wrapped.columns, -1)
        XCTAssertEqual(wrapped.rows, 1)
        let previous = layout.offset(from: 2, by: -1)
        XCTAssertEqual(previous.columns, 1)
        XCTAssertEqual(previous.rows, -1)
    }

    func testOneColumnOffsetsMatchTheOldStraightList() {
        let layout = PackListLayout(width: 408, spacing: 16)
        for distance in -3...3 {
            let offset = layout.offset(from: 4, by: distance)
            XCTAssertEqual(offset.columns, 0)
            XCTAssertEqual(offset.rows, distance)
        }
    }

    func testCardCentresSitEitherSideOfTheMiddle() {
        let layout = PackListLayout(width: 637, spacing: 16)
        XCTAssertEqual(layout.centerOffset(ofCard: 0), -163.25)
        XCTAssertEqual(layout.centerOffset(ofCard: 1), 163.25)
    }
}
