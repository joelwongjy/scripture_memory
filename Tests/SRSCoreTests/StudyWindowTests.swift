import XCTest
@testable import SRSCore

final class StudyWindowTests: XCTestCase {

    func testLandscapeKeyboardDropsTheTitle() {
        XCTAssertTrue(StudyWindow.dropsTitle(height: 154, topInset: 82))
    }

    func testPortraitKeyboardKeepsTheTitle() {
        XCTAssertFalse(StudyWindow.dropsTitle(height: 308, topInset: 82))
    }

    func testDroppingTheTitleCannotChangeTheAnswer() {
        let barHeight: CGFloat = 58
        for height in stride(from: CGFloat(100), through: 500, by: 7) {
            let withTitle = StudyWindow.dropsTitle(height: height, topInset: 82)
            let withoutTitle = StudyWindow.dropsTitle(height: height + barHeight, topInset: 82 - barHeight)
            XCTAssertEqual(withTitle, withoutTitle)
        }
    }
}
