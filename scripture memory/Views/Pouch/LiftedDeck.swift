import SwiftUI

/// The bottom pocket's cards on their way out into the fanned list, and back.
///
/// `lift` carries the stack out of the pocket to the list's size and place;
/// `spread` lays the cards out one above the other, the card behind sliding
/// down and the one before coming in from above. At 1 the list takes over.
struct LiftedDeck<Face: View>: View, Animatable {
    var lift: CGFloat
    var spread: CGFloat
    let pocketCenter: CGPoint
    let listCenter: CGPoint
    let pocketWidth: CGFloat
    let listWidth: CGFloat
    /// The gap from one card to the next in the list.
    let listPitch: CGFloat
    let previous: PouchSlots.Card
    let front: PouchSlots.Card
    let next: PouchSlots.Card
    let edges: Int
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
            face(next, listWidth)
                .offset(y: gap)
            if spread > 0 {
                face(previous, listWidth)
                    .offset(y: -gap)
                    .opacity(Double(min(1, spread * 2)))
            }
            face(front, listWidth)
        }
        .frame(width: listWidth, height: height)
        .shadow(color: .black.opacity(Double(0.14 * lift * (1 - spread))), radius: 1.5, y: 1)
        .shadow(color: .black.opacity(Double(0.09 * lift * (1 - spread))), radius: 16 * lift, y: 8 * lift)
        .scaleEffect(scale)
        .position(center)
        .opacity(lift > 0.02 ? 1 : 0)
    }
}
