import Foundation

struct PackListLayout: Equatable {
    static let twoColumnWidth: CGFloat = 540
    static let threeColumnWidth: CGFloat = 960
    static let pouchCardShare: CGFloat = 0.86
    static let verseTextShare: CGFloat = 0.04
    static let cardPullLimit: CGFloat = 120

    let columns: Int
    let cardWidth: CGFloat
    let spacing: CGFloat

    init(width: CGFloat, spacing: CGFloat) {
        columns = Self.columns(forWidth: width)
        self.spacing = spacing
        cardWidth = (width - spacing * CGFloat(columns - 1)) / CGFloat(columns)
    }

    static func homeIsSideBySide(contentWidth: CGFloat, height: CGFloat) -> Bool {
        columns(forWidth: contentWidth) > 1 && contentWidth > height
    }

    static func focalCardWidth(bodyTextSize: CGFloat) -> CGFloat {
        bodyTextSize / verseTextShare
    }

    static func verseTextCeiling(cardWidth: CGFloat, share: CGFloat, readableSize: CGFloat) -> CGFloat {
        max(cardWidth * share, readableSize)
    }

    static func cardPull(_ travel: CGFloat) -> CGFloat {
        let limit = cardPullLimit
        let pulled = limit * (1 - 1 / (abs(travel) * 0.55 / limit + 1))
        return travel < 0 ? -pulled : pulled
    }

    static func titleSpan(barWidth: CGFloat, leading: CGFloat, trailing: CGFloat,
                          title: CGFloat, gap: CGFloat) -> (x: CGFloat, width: CGFloat) {
        let width = min(title, max(barWidth - leading - trailing - 2 * gap, 0))
        let x = min(max((barWidth - width) / 2, leading + gap), barWidth - trailing - gap - width)
        return (x, width)
    }

    static func positionLabel(card: Int, count: Int, columns: Int) -> String {
        let first = card / columns * columns
        let last = min(first + columns, count)
        return last > first + 1 ? "Cards \(first + 1)–\(last) of \(count)" : "Card \(first + 1) of \(count)"
    }

    static func liftedWidth(listWidth: CGFloat, focalWidth: CGFloat, area: CGSize, aspect: CGFloat,
                            margin: CGFloat) -> CGFloat {
        let fitting = min(area.width - 2 * margin, (area.height - 2 * margin) * aspect)
        return min(fitting, max(listWidth, focalWidth))
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
