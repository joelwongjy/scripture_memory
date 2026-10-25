import SwiftUI

/// The bottom pocket's cards taken out into your hand: the stack rises out of
/// the pocket, grows to a readable size and hangs over the dimmed pouch.
///
/// Animatable so the stack shows from the very first frame of the lift and
/// disappears on the last frame of putting it back, in step with the pocket
/// going empty and filling again in `PouchScene`.
///
/// `spread` lays the cards out the way the pack's list shows them, one above
/// the other: the card behind slides down from under the front one and the
/// card before it comes in from above. At 1 it hands over to the list.
struct LiftedDeck<Face: View>: View, Animatable {
    var lift: CGFloat
    var spread: CGFloat = 0
    /// Where the front card sits in the pocket, and where it hangs once out.
    let pocketCenter: CGPoint
    let handCenter: CGPoint
    /// Card width in the pocket and in the hand.
    let pocketWidth: CGFloat
    let handWidth: CGFloat
    /// Where the list will put the front card, and the gap from one card to the next.
    let listCenter: CGPoint
    let listPitch: CGFloat
    let previous: PouchSlots.Card
    let front: PouchSlots.Card
    let next: PouchSlots.Card
    let edges: Int
    /// The front card being swiped, and how far the stack is pulled down.
    let swipe: CGSize
    let face: (PouchSlots.Card, CGFloat) -> Face

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(lift, spread) }
        set { lift = newValue.first; spread = newValue.second }
    }

    var body: some View {
        let height = handWidth / PouchMetrics.cardAspect
        let startScale = pocketWidth / handWidth
        let scale = startScale + (1 - startScale) * lift
        let held = CGPoint(x: pocketCenter.x + (handCenter.x - pocketCenter.x) * lift,
                           y: pocketCenter.y + (handCenter.y - pocketCenter.y) * lift)
        let center = CGPoint(x: held.x + (listCenter.x - held.x) * spread,
                             y: held.y + (listCenter.y - held.y) * spread)
        let gap = listPitch / max(scale, 0.01) * spread
        // Follows the finger down (toward putting back) more than up (toward the list).
        let pulledDown = swipe.height > 0 ? swipe.height * 0.6 : swipe.height * 0.3

        ZStack {
            // The rest of the stack behind, a hair lower each.
            ForEach(0..<edges, id: \.self) { i in
                let n = edges - i
                RoundedRectangle(cornerRadius: 2)
                    .fill(n % 2 == 0 ? PouchInk.paperBack : Color(white: 0.89))
                    .overlay(RoundedRectangle(cornerRadius: 2).strokeBorder(Color.black.opacity(0.10), lineWidth: 0.5))
                    .offset(y: CGFloat(n) * 2.4)
                    .opacity(Double(1 - spread))
            }
            face(next, handWidth)
                .offset(y: gap)
            if spread > 0 {
                face(previous, handWidth)
                    .offset(y: -gap)
                    .opacity(Double(min(1, spread * 2)))
            }
            face(front, handWidth)
                .offset(x: swipe.width)
                .rotationEffect(.degrees(Double(swipe.width / 28)), anchor: .bottom)
                .shadow(color: .black.opacity(abs(swipe.width) > 1 ? 0.18 : 0), radius: 10, y: 4)
        }
        .frame(width: handWidth, height: height)
        .shadow(color: .black.opacity(Double(0.28 * lift * (1 - spread))), radius: 22 * lift, y: 12 * lift)
        .scaleEffect(scale)
        .position(x: center.x, y: center.y + pulledDown)
        .opacity(lift > 0.02 ? 1 : 0)
    }
}
