import Foundation

struct PackListLayout: Equatable {
    static let twoColumnWidth: CGFloat = 540
    static let threeColumnWidth: CGFloat = 960
    static let pouchCardShare: CGFloat = 0.86
    static let liftedCardWidth: CGFloat = 420

    let columns: Int
    let cardWidth: CGFloat
    let spacing: CGFloat

    init(width: CGFloat, spacing: CGFloat) {
        columns = Self.columns(forWidth: width)
        self.spacing = spacing
        cardWidth = (width - spacing * CGFloat(columns - 1)) / CGFloat(columns)
    }

    static func liftedWidth(listWidth: CGFloat, area: CGSize, aspect: CGFloat, margin: CGFloat) -> CGFloat {
        let fitting = min(area.width - 2 * margin, (area.height - 2 * margin) * aspect)
        return min(fitting, max(listWidth, liftedCardWidth))
    }

    static func columns(forWidth width: CGFloat) -> Int {
        width >= threeColumnWidth ? 3 : width >= twoColumnWidth ? 2 : 1
    }

    var columnPitch: CGFloat { cardWidth + spacing }

    var pouchWidthLimit: CGFloat? {
        columns > 1 ? cardWidth / Self.pouchCardShare : nil
    }

    func row(of card: Int) -> Int {
        card >= 0 ? card / columns : -((columns - 1 - card) / columns)
    }

    func column(of card: Int) -> Int {
        card - row(of: card) * columns
    }

    func rows(forCount count: Int) -> Int {
        (count + columns - 1) / columns
    }

    func firstCard(inRow row: Int) -> Int {
        row * columns
    }

    func offset(from card: Int, by distance: Int) -> (columns: Int, rows: Int) {
        let target = card + distance
        return (column(of: target) - column(of: card), row(of: target) - row(of: card))
    }

    func centerOffset(ofCard card: Int) -> CGFloat {
        (CGFloat(column(of: card)) - CGFloat(columns - 1) / 2) * columnPitch
    }
}
