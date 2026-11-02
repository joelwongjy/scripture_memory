import SwiftUI

/// A card lifted out of the list: where it came from, so it can go back.
struct LiftedCard: Equatable {
    let index: Int
    let source: CGRect
}

/// The lifted card, moving between its slot in the list (`lift` 0) and the
/// middle of the screen (1). `angle` turns it over: 0 shows the verse, 180 the
/// reference alone. With Reduce Motion it fades in place and crossfades over.
struct LiftedCardView: View {
    let verse: Verse
    let isLearnt: Bool
    let source: CGRect
    let area: CGRect
    let lift: CGFloat
    let angle: Double
    /// How far a swipe has carried the card from the middle of the screen.
    let drag: CGSize
    let onFlip: () -> Void

    var body: some View {
        let width = PackListLayout.liftedWidth(listWidth: source.width, area: area.size,
                                               aspect: PouchMetrics.cardAspect, margin: AppLayout.screenMargin)
        let still = AppMotion.reduceMotion
        let moved = still ? 1 : lift

        FlippingCard(angle: angle, isFlat: still, front: {
            PouchVerseCard(verse: verse, isLearnt: isLearnt, width: width)
                .paperAppearance()
        }, back: {
            PouchCardBack(verse: verse, width: width)
                .paperAppearance()
        })
        .contentShape(Rectangle())
        .onTapGesture(perform: onFlip)
        .shadow(color: .black.opacity(0.28 * Double(lift)), radius: 22, y: 12)
        .scaleEffect((1 + (source.width / width - 1) * (1 - moved))
                     * (1 - 0.05 * hypot(drag.width, drag.height) / PackListLayout.cardPullLimit))
        .position(x: source.midX + (area.midX - source.midX) * moved,
                  y: source.midY + (area.midY - source.midY) * moved)
        .offset(drag)
        .opacity(still ? Double(lift) : 1)
    }
}

/// Turns a card over about its vertical axis, swapping faces edge-on.
struct FlippingCard<Front: View, Back: View>: View, Animatable {
    var angle: Double
    let isFlat: Bool
    @ViewBuilder let front: () -> Front
    @ViewBuilder let back: () -> Back

    var animatableData: Double {
        get { angle }
        set { angle = newValue }
    }

    var body: some View {
        let turn = cos(angle * .pi / 180)
        ZStack {
            front()
                .opacity(isFlat ? (1 + turn) / 2 : turn >= 0 ? 1 : 0)
            back()
                .scaleEffect(x: isFlat ? 1 : -1, y: 1)
                .opacity(isFlat ? (1 - turn) / 2 : turn >= 0 ? 0 : 1)
        }
        .rotation3DEffect(.degrees(isFlat ? 0 : angle), axis: (x: 0, y: 1, z: 0), perspective: 0.45)
    }
}

/// The side of a card with only its reference, to say the rest from memory.
struct PouchCardBack: View {
    let verse: Verse
    let width: CGFloat

    var body: some View {
        let u = width / 100
        VStack(spacing: 2.4 * u) {
            Text("\(verse.book) \(verse.reference)")
                .font(CardFont.font(verse.packName.hasPrefix("DEP ") ? .printBody : .body, size: 6.4 * u))
                .foregroundStyle(PouchInk.body)
                .multilineTextAlignment(.center)
            Text("Tap to reveal")
                .font(.system(size: 3.2 * u, weight: .medium))
                .foregroundStyle(PouchInk.caption)
        }
        .padding(.horizontal, 7 * u)
        .frame(width: width, height: width / PouchMetrics.cardAspect)
        .background(PaperFace())
    }
}
