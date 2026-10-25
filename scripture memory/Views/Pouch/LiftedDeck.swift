import SwiftUI

/// The bottom pocket's cards taken out into your hand: the stack rises out of
/// the pocket, grows to a readable size and hangs over the dimmed pouch.
///
/// Animatable so the stack shows from the very first frame of the lift and
/// disappears on the last frame of putting it back, in step with the pocket
/// going empty and filling again in `PouchScene`.
struct LiftedDeck<Face: View>: View, Animatable {
    var lift: CGFloat
    /// Where the front card sits in the pocket, and where it hangs once out.
    let pocketCenter: CGPoint
    let handCenter: CGPoint
    /// Card width in the pocket and in the hand.
    let pocketWidth: CGFloat
    let handWidth: CGFloat
    let front: PouchSlots.Card
    let next: PouchSlots.Card
    let edges: Int
    /// The front card being swiped, and how far the stack is pulled down.
    let swipe: CGSize
    let face: (PouchSlots.Card, CGFloat) -> Face

    var animatableData: CGFloat {
        get { lift }
        set { lift = newValue }
    }

    var body: some View {
        let height = handWidth / PouchMetrics.cardAspect
        let startScale = pocketWidth / handWidth
        let scale = startScale + (1 - startScale) * lift
        let center = CGPoint(x: pocketCenter.x + (handCenter.x - pocketCenter.x) * lift,
                             y: pocketCenter.y + (handCenter.y - pocketCenter.y) * lift)
        let pulledDown = max(0, swipe.height) * 0.6

        ZStack {
            // The rest of the stack behind, a hair lower each.
            ForEach(0..<edges, id: \.self) { i in
                let n = edges - i
                RoundedRectangle(cornerRadius: 2)
                    .fill(n % 2 == 0 ? PouchInk.paperBack : Color(white: 0.89))
                    .overlay(RoundedRectangle(cornerRadius: 2).strokeBorder(Color.black.opacity(0.10), lineWidth: 0.5))
                    .offset(y: CGFloat(n) * 2.4)
            }
            face(next, handWidth)
            face(front, handWidth)
                .offset(x: swipe.width)
                .rotationEffect(.degrees(Double(swipe.width / 28)), anchor: .bottom)
                .shadow(color: .black.opacity(abs(swipe.width) > 1 ? 0.18 : 0), radius: 10, y: 4)
        }
        .frame(width: handWidth, height: height)
        .shadow(color: .black.opacity(0.28 * lift), radius: 22 * lift, y: 12 * lift)
        .scaleEffect(scale)
        .position(x: center.x, y: center.y + pulledDown)
        .opacity(lift > 0.02 ? 1 : 0)
    }
}
