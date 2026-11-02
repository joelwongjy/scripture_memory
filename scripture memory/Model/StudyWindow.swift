import Foundation

enum StudyWindow {
    static let titleRoom: CGFloat = 320

    static func dropsTitle(height: CGFloat, topInset: CGFloat) -> Bool {
        height + topInset < titleRoom
    }
}
