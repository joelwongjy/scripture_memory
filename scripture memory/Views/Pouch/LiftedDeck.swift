import SwiftUI

/// The bottom pocket's cards on their way out into the fanned list, and back.
///
/// `lift` carries the stack out of the pocket to the list's size and place;
/// `spread` lays the cards out one above the other, the cards behind sliding
/// down and the ones before coming in from above. At 1 the list takes over,
/// so the deck draws every card the list will show around the front one.
struct LiftedDeck<Face: View>: View, Animatable {
    var lift: CGFloat
    var spread: CGFloat
    let pocketCenter: CGPoint
    let listCenter: CGPoint
    let pocketWidth: CGFloat
    let listWidth: CGFloat
    /// The gap from one card to the next in the list.
    let listPitch: CGFloat
    /// The card `k` places from the front one: below for positive `k`, above
    /// for negative.
    let around: (Int) -> PouchSlots.Card
    let edges: Int

    private static var reach: Int { 3 }
    let face: (PouchSlots.Card, CGFloat) -> Face

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(lift, spread) }
        set { lift = newValue.first; spread = newValue.second }
    }

    var body: some View {
        let height = listWidth / PouchMetrics.cardAspect
        let startScale = pocketWidth / listWidth
        let scale = startScale + (1 - startScale) * lift
        let center = CGPoint(x: pocketCenter.x + (listCenter.x - pocketCenter.x) * lift,
                             y: pocketCenter.y + (listCenter.y - pocketCenter.y) * lift)
        let gap = listPitch / max(scale, 0.01) * spread

        ZStack {
            ForEach(0..<edges, id: \.self) { i in
                let n = edges - i
                RoundedRectangle(cornerRadius: 2)
                    .fill(PouchInk.paper)
                    .overlay(alignment: .bottom) {
                        Rectangle().fill(PouchInk.edgeLine).frame(height: 0.5)
                    }
                    .offset(y: CGFloat(n) * 1.1)
                    .opacity(Double(1 - spread))
            }
            ForEach(Array((1...Self.reach).reversed()), id: \.self) { k in
                face(around(k), listWidth)
                    .listCardShadow(Double(spread))
                    .offset(y: gap * CGFloat(k))
                if spread > 0 {
                    face(around(-k), listWidth)
                        .listCardShadow(Double(spread))
                        .offset(y: -gap * CGFloat(k))
                        .opacity(Double(min(1, max(0, spread * 2 - CGFloat(k - 1) * 0.5))))
                }
            }
            face(around(0), listWidth)
                .listCardShadow(Double(spread))
        }
        .frame(width: listWidth, height: height)
        .shadow(color: .black.opacity(Double(0.14 * lift * (1 - spread))), radius: 1.5, y: 1)
        .shadow(color: .black.opacity(Double(0.09 * lift * (1 - spread))), radius: 16 * lift, y: 8 * lift)
        .scaleEffect(scale)
        .position(center)
        .opacity(lift > 0.02 ? 1 : 0)
    }
}
