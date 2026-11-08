import Foundation

struct PackListLayout: Equatable {
    static let twoColumnWidth: CGFloat = 540
    static let threeColumnWidth: CGFloat = 960
    static let pouchCardShare: CGFloat = 0.86
    static let verseTextShare: CGFloat = 0.04
    static let printedVerseShare: CGFloat = 0.038
    static let flickProjectionSeconds: CGFloat = 0.998 / (1 - 0.998) / 1_000

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

    static func liftedScale(dragged distance: CGFloat, cardWidth: CGFloat) -> CGFloat {
        guard cardWidth > 0 else { return 1 }
        return 1 - 0.25 * min(distance / cardWidth, 1)
    }

    static func putsCardBack(projected distance: CGFloat, area: CGSize) -> Bool {
        distance > min(area.width, area.height) * 0.25
    }

    static func springVelocity(_ velocity: CGSize, from start: CGPoint, to end: CGPoint) -> Double {
        let dx = end.x - start.x, dy = end.y - start.y
        let span = hypot(dx, dy)
        guard span > 1 else { return 0 }
        let toward = (velocity.width * dx + velocity.height * dy) / span
        return Double(min(max(toward / span, 0), 20))
    }

    static func titleSpan(barWidth: CGFloat, leading: CGFloat, trailing: CGFloat,
                          title: CGFloat, gap: CGFloat) -> (x: CGFloat, width: CGFloat) {
        let width = min(title, max(barWidth - leading - trailing - 2 * gap, 0))
        let x = min(max((barWidth - width) / 2, leading + gap), barWidth - trailing - gap - width)
        return (x, width)
    }

    static func scrubTarget(fraction: Double, most: CGFloat, viewport: CGFloat, cardHeight: CGFloat,
                            spacing: CGFloat, rows: Int) -> (row: Int, anchor: CGFloat?) {
        let offset = CGFloat(min(max(fraction, 0), 1)) * most
        let pitch = cardHeight + spacing
        let room = viewport - cardHeight
        let row = min(max(Int(((offset + room / 2 - spacing) / pitch).rounded()), 0), max(rows - 1, 0))
        guard room > 0 else { return (row, nil) }
        return (row, (spacing + CGFloat(row) * pitch - offset) / room)
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
