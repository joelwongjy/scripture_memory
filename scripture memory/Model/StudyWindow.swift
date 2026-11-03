import Foundation

enum StudyWindow {
    static let shortHeight: CGFloat = 320

    static func dropsTitle(height: CGFloat, topInset: CGFloat) -> Bool {
        height + topInset < shortHeight
    }
}
