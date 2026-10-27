import SwiftUI

/// Which card occupies each place in the pouch for one frame.
struct PouchSlots {
    enum Card: Equatable { case verse(Int), backPage, none }
    var top: Card            // front of the top pocket (upside down)
    var bottom: Card         // front of the bottom pocket
    var topEdges: Int
    var bottomEdges: Int
}

/// The pouch for one frame of any animation.
///
/// Animatable so which face of the lid shows is decided per frame, halfway
/// through its rotation, rather than once at the end state.
///
/// - `openness`: 0 is folded shut, 1 is lying flat.
/// - `lift`: 0 is the bottom stack in its pocket, above 0 it's out (drawn by
///   `LiftedDeck`), so the pocket shows empty.
struct PouchScene<CardFace: View, Cover: View>: View, Animatable {
    var openness: CGFloat
    var lift: CGFloat = 0
    let m: PouchMetrics
    let style: PlasticStyle
    let slots: PouchSlots
    let tilt: CGFloat
    let face: (PouchSlots.Card) -> CardFace
    let cover: () -> Cover

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(openness, lift) }
        set { openness = newValue.first; lift = newValue.second }
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

        }
        .frame(width: m.pouchWidth, height: m.halfHeight * 2, alignment: .top)
        // Shut, only the bottom half's footprint is left: keep it centred.
        .offset(y: -(1 - openness) * m.halfHeight / 2)
    }
}
