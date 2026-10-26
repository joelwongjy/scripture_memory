import SwiftUI

/// Which card occupies each place in the pouch for one frame.
struct PouchSlots {
    enum Card: Equatable { case verse(Int), backPage, none }
    var top: Card            // front of the top pocket (upside down)
    var bottom: Card         // front of the bottom pocket
    var turning: Int?        // the card being turned over the fold, if any
    var topEdges: Int
    var bottomEdges: Int
}

/// The pouch for one frame of any animation.
///
/// Animatable so that the two things that change halfway through a rotation —
/// which face of the lid shows, and which face of a turning card — are decided
/// per frame rather than once at the end state.
///
/// - `openness`: 0 is folded shut, 1 is lying flat.
/// - `turn`: 0 is the turning card in the bottom pocket, 1 is it in the top one.
/// - `lift`: 0 is the bottom stack in its pocket, above 0 it's out (drawn by
///   `LiftedDeck`), so the pocket shows empty.
struct PouchScene<CardFace: View, Cover: View>: View, Animatable {
    var openness: CGFloat
    var turn: CGFloat
    var lift: CGFloat = 0
    let m: PouchMetrics
    let style: PlasticStyle
    let slots: PouchSlots
    let tilt: CGFloat
    let face: (PouchSlots.Card) -> CardFace
    let cover: () -> Cover

    var animatableData: AnimatablePair<AnimatablePair<CGFloat, CGFloat>, CGFloat> {
        get { AnimatablePair(AnimatablePair(openness, turn), lift) }
        set { openness = newValue.first.first; turn = newValue.first.second; lift = newValue.second }
    }

    var body: some View {
        let lidAngle = (1 - openness) * 180           // 0 flat, 180 shut
        let lidShowsOutside = lidAngle > 90
        let bottomFade: CGFloat = max(0, (180 - lidAngle) / 60 - 0.5)
        let shine = min(1, max(0, 0.35 + tilt * 0.5 + (1 - openness) * 0.3))

        ZStack(alignment: .top) {
            // Bottom half.
            let stackIsOut = lift > 0.02
            PouchPocket(m: m, style: style, stackEdges: stackIsOut ? 0 : slots.bottomEdges, shine: shine) {
                face(stackIsOut ? .none : slots.bottom)
            }
            .offset(y: m.halfHeight)
            // Shut, the lid's outside is all you see.
            .opacity(lidShowsOutside ? bottomFade : 1)
            .zIndex(1)

            // Top half: the same pocket turned round, folding over the hinge.
            Group {
                if lidShowsOutside {
                    PouchExterior(m: m, style: style, shine: 1 - shine) { cover() }
                        // Drawn upside down so it reads the right way once the
                        // lid has turned over onto the bottom half.
                        .scaleEffect(x: 1, y: -1)
                } else {
                    PouchPocket(m: m, style: style, stackEdges: slots.topEdges, shine: 1 - shine) {
                        face(slots.top)
                    }
                    .rotationEffect(.degrees(180))
                }
            }
            .frame(width: m.pouchWidth, height: m.halfHeight)
            .rotation3DEffect(.degrees(-lidAngle), axis: (x: 1, y: 0, z: 0),
                              anchor: .bottom, perspective: 0.35)
            .zIndex(lidAngle > 0.5 ? 3 : 0)

            // A card being turned over the fold like a page.
            if let i = slots.turning {
                TurningCard(turn: turn, m: m) { face(.verse(i)) }
                    .zIndex(2)
            }
        }
        .frame(width: m.pouchWidth, height: m.halfHeight * 2, alignment: .top)
        // Shut, only the bottom half's footprint is left: keep it centred.
        .offset(y: -(1 - openness) * m.halfHeight / 2)
    }
}

/// A card turning over the fold. Its front shows until it stands on edge, then
/// its back, which (like the printed card) lands upside down in the top pocket.
private struct TurningCard<Face: View>: View {
    let turn: CGFloat
    let m: PouchMetrics
    @ViewBuilder let face: () -> Face

    var body: some View {
        let frame = m.cardFrame
        let angle = turn * 180
        // Hinge line, in the card's own unit space.
        let hinge = UnitPoint(x: 0.5, y: -frame.minY / frame.height)
        let lift = sin(turn * .pi)

        face()
            .frame(width: frame.width, height: frame.height)
            // Past vertical we're looking at the back of the card.
            .scaleEffect(x: angle > 90 ? -1 : 1, y: 1)
            .shadow(color: .black.opacity(0.25 * lift), radius: 14 * lift, y: 8 * lift)
            .rotation3DEffect(.degrees(angle), axis: (x: 1, y: 0, z: 0),
                              anchor: hinge, perspective: 0.35)
            .offset(x: frame.minX, y: m.halfHeight + frame.minY)
            .frame(width: m.pouchWidth, height: m.halfHeight * 2, alignment: .topLeading)
            .allowsHitTesting(false)
    }
}
