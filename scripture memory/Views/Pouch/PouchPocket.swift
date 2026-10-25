import SwiftUI

/// Sizes for the pouch, all derived from the space it gets.
///
/// The pouch is one clear sleeve folded in the middle. Each half has an inner
/// pocket whose mouth faces the fold, with a U-shaped thumb notch so you can
/// push the front card out. `halfHeight` is one half, hinge to outer edge.
struct PouchMetrics {
    /// The app's card shape everywhere (the pack covers are drawn for it too).
    static let cardAspect: CGFloat = AppLayout.cardAspect

    let pouchWidth: CGFloat
    let cardWidth: CGFloat
    let cardHeight: CGFloat
    let rim: CGFloat            // welded edge band
    let foldGap: CGFloat        // hinge to pocket mouth
    let stackRoom: CGFloat      // room below the front card for the stack's edges
    let halfHeight: CGFloat
    let notchWidth: CGFloat
    let notchDepth: CGFloat
    let corner: CGFloat

    init(fitting size: CGSize) {
        var width = min(size.width - 2 * AppLayout.screenMargin, 560)
        var m = PouchMetrics(width: width)
        if 2 * m.halfHeight > size.height {
            width *= size.height / (2 * m.halfHeight)
            m = PouchMetrics(width: width)
        }
        self = m
    }

    private init(width: CGFloat) {
        pouchWidth = width
        cardWidth  = width * 0.86
        cardHeight = cardWidth / Self.cardAspect
        rim        = max(5, width * 0.028)
        foldGap    = cardHeight * 0.13
        stackRoom  = cardHeight * 0.06
        halfHeight = foldGap + cardHeight + stackRoom + rim + 6
        notchWidth = cardWidth * 0.42
        notchDepth = cardHeight * 0.20
        corner     = rim * 2.4
    }

    /// How far the sides pinch in at `y` (distance from the fold). The real
    /// sleeve is crimped down each side, and the crimp draws the sides in where
    /// the plastic bends, so the outline narrows at the fold.
    func pinch(at y: CGFloat) -> CGFloat {
        let reach = foldGap * 1.8
        guard y < reach else { return 0 }
        let t = max(0, y) / reach
        return rim * 0.9 * (1 - t * t * (3 - 2 * t))
    }

    /// The front card's frame inside a half drawn mouth-up (hinge at y = 0).
    var cardFrame: CGRect {
        CGRect(x: (pouchWidth - cardWidth) / 2, y: foldGap - 1, width: cardWidth, height: cardHeight)
    }
}

/// Colours of the plastic, which has to read on a light and a dark background.
struct PlasticStyle {
    let tint: Color         // the sheet itself
    let panel: Color        // the pocket's front layer, a touch denser
    let rim: Color          // welded edge, denser still
    let edgeLight: Color    // light catching a cut edge
    let edgeShade: Color    // the edge's thickness
    let shine: Color        // specular highlight
    let emboss: Color       // the pressed pattern along a pocket's mouth
    let embossShade: Color  // its shadow, so it reads over white card too
    let crease: Color       // the bend at the fold

    init(_ scheme: ColorScheme) {
        if scheme == .dark {
            tint = Color.white.opacity(0.055); panel = Color.white.opacity(0.03)
            rim = Color.white.opacity(0.13); edgeLight = Color.white.opacity(0.5)
            edgeShade = Color.black.opacity(0.35); shine = Color.white.opacity(0.14)
            emboss = Color.white.opacity(0.75); embossShade = Color.black.opacity(0.45)
            crease = Color.white.opacity(0.07)
        } else {
            tint = Color(white: 0.3).opacity(0.06); panel = Color(white: 0.5).opacity(0.035)
            rim = Color(white: 0.35).opacity(0.13); edgeLight = Color.white.opacity(0.95)
            edgeShade = Color.black.opacity(0.13); shine = Color.white.opacity(0.6)
            emboss = Color.white; embossShade = Color.black.opacity(0.22)
            crease = Color.black.opacity(0.07)
        }
    }
}

// MARK: - Shapes (a half drawn mouth-up: hinge along the top edge)

/// The sleeve's back sheet for one half: square along the fold, rounded at the
/// outer corners.
struct HalfSheetShape: Shape {
    let m: PouchMetrics
    func path(in r: CGRect) -> Path {
        let corner = m.corner
        return Path { p in
            p.addLines(sidePoints(m, x: r.maxX, inward: -1, inset: 0, to: r.maxY - corner))
            p.addQuadCurve(to: CGPoint(x: r.maxX - corner, y: r.maxY), control: CGPoint(x: r.maxX, y: r.maxY))
            p.addLine(to: CGPoint(x: r.minX + corner, y: r.maxY))
            p.addQuadCurve(to: CGPoint(x: r.minX, y: r.maxY - corner), control: CGPoint(x: r.minX, y: r.maxY))
            // addLine, not addLines: addLines would start a new subpath here.
            for pt in sidePoints(m, x: r.minX, inward: 1, inset: 0, to: r.maxY - corner).reversed() { p.addLine(to: pt) }
            p.closeSubpath()
        }
    }
}

/// One side edge from the fold down to `bottom`, pinched in near the fold.
/// `inward` is +1 for the left side, -1 for the right.
func sidePoints(_ m: PouchMetrics, x: CGFloat, inward: CGFloat, inset: CGFloat, to bottom: CGFloat) -> [CGPoint] {
    var pts: [CGPoint] = []
    var y: CGFloat = 0
    while y < bottom {
        pts.append(CGPoint(x: x + inward * (inset + m.pinch(at: y)), y: y))
        y += y < m.foldGap * 2 ? 1.5 : 12
    }
    pts.append(CGPoint(x: x + inward * inset, y: bottom))
    return pts
}

/// The welded rim: down one side, along the outer edge, up the other. Open at
/// the fold, so it carries straight on into the other half.
struct RimShape: Shape {
    let m: PouchMetrics
    let inset: CGFloat
    func path(in rect: CGRect) -> Path {
        let c = max(0, m.corner - inset)
        let bottom = rect.maxY - inset
        return Path { p in
            p.addLines(sidePoints(m, x: rect.minX, inward: 1, inset: inset, to: bottom - c))
            p.addQuadCurve(to: CGPoint(x: rect.minX + inset + c, y: bottom), control: CGPoint(x: rect.minX + inset, y: bottom))
            p.addLine(to: CGPoint(x: rect.maxX - inset - c, y: bottom))
            p.addQuadCurve(to: CGPoint(x: rect.maxX - inset, y: bottom - c), control: CGPoint(x: rect.maxX - inset, y: bottom))
            for pt in sidePoints(m, x: rect.maxX, inward: -1, inset: inset, to: bottom - c).reversed() { p.addLine(to: pt) }
        }
    }
}

/// The crimp down each side: fine parallel ridges pressed into the weld,
/// following the side's pinch at the fold.
struct SideCrimp: View {
    let m: PouchMetrics
    let style: PlasticStyle

    var body: some View {
        Canvas { ctx, size in
            let bottom = size.height - m.corner
            let ridges = 4
            for k in 1...ridges {
                let inset = m.rim * CGFloat(k) / CGFloat(ridges + 1)
                for (x, inward) in [(CGFloat(0), CGFloat(1)), (size.width, CGFloat(-1))] {
                    var line = Path()
                    line.addLines(sidePoints(m, x: x, inward: inward, inset: inset, to: bottom))
                    ctx.stroke(line.offsetBy(dx: inward * 0.5, dy: 0), with: .color(style.edgeShade), lineWidth: 0.5)
                    ctx.stroke(line, with: .color(style.edgeLight.opacity(0.75)), lineWidth: 0.6)
                }
            }
        }
        .allowsHitTesting(false)
    }
}

/// Points along a pocket's mouth: straight across, dipping into the U-shaped
/// thumb notch in the middle. `grow` pushes the line further into the panel,
/// which is how the embossed band follows the cut edge.
func mouthPoints(width: CGFloat, y: CGFloat, notchWidth: CGFloat, notchDepth: CGFloat,
                 grow: CGFloat = 0, from x0: CGFloat, to x1: CGFloat, step: CGFloat = 2) -> [CGPoint] {
    let w = notchWidth + 2 * grow
    let d = notchDepth + grow
    let cx = width / 2
    let xs = cx - w / 2, xe = cx + w / 2
    let y0 = y + grow
    var pts: [CGPoint] = []
    var x = x0
    while x < xs { pts.append(CGPoint(x: x, y: y0)); x += step }
    // Two cubic halves with soft shoulders, like the die-cut notch.
    func cubic(_ p0: CGPoint, _ c1: CGPoint, _ c2: CGPoint, _ p3: CGPoint) {
        let n = max(8, Int(w / step))
        for i in 0...n {
            let t = CGFloat(i) / CGFloat(n), m = 1 - t
            let a = m * m * m, b = 3 * m * m * t, c = 3 * m * t * t, e = t * t * t
            pts.append(CGPoint(x: a * p0.x + b * c1.x + c * c2.x + e * p3.x,
                               y: a * p0.y + b * c1.y + c * c2.y + e * p3.y))
        }
    }
    cubic(CGPoint(x: xs, y: y0), CGPoint(x: xs + w * 0.20, y: y0),
          CGPoint(x: cx - w * 0.30, y: y0 + d), CGPoint(x: cx, y: y0 + d))
    cubic(CGPoint(x: cx, y: y0 + d), CGPoint(x: cx + w * 0.30, y: y0 + d),
          CGPoint(x: xe - w * 0.20, y: y0), CGPoint(x: xe, y: y0))
    x = xe + step
    while x <= x1 { pts.append(CGPoint(x: x, y: y0)); x += step }
    return pts
}

/// The pocket's front layer: from the mouth (with its notch) down to the outer
/// edge.
struct PocketPanelShape: Shape {
    let m: PouchMetrics
    func path(in r: CGRect) -> Path {
        let mouth = mouthPoints(width: r.width, y: m.foldGap, notchWidth: m.notchWidth,
                                notchDepth: m.notchDepth, from: 0, to: r.width)
        return Path { p in
            p.addLines(mouth)
            p.addLine(to: CGPoint(x: r.maxX, y: m.foldGap))
            p.addLine(to: CGPoint(x: r.maxX, y: r.maxY - m.corner))
            p.addQuadCurve(to: CGPoint(x: r.maxX - m.corner, y: r.maxY), control: CGPoint(x: r.maxX, y: r.maxY))
            p.addLine(to: CGPoint(x: r.minX + m.corner, y: r.maxY))
            p.addQuadCurve(to: CGPoint(x: r.minX, y: r.maxY - m.corner), control: CGPoint(x: r.minX, y: r.maxY))
            p.closeSubpath()
        }
    }
}

/// Just the cut edge of the mouth, for its highlight.
struct MouthEdgeShape: Shape {
    let m: PouchMetrics
    var grow: CGFloat = 0
    func path(in r: CGRect) -> Path {
        Path { p in
            p.addLines(mouthPoints(width: r.width, y: m.foldGap, notchWidth: m.notchWidth,
                                   notchDepth: m.notchDepth, grow: grow, from: m.rim, to: r.width - m.rim))
        }
    }
}

/// The pressed chain pattern that runs along each mouth and around its notch:
/// a row of small loops, light on top with a faint shadow so it reads as
/// embossed into the plastic.
struct EmbossedBand: View {
    let m: PouchMetrics
    let color: Color
    let shade: Color

    var body: some View {
        Canvas { ctx, size in
            let pts = mouthPoints(width: size.width, y: m.foldGap, notchWidth: m.notchWidth,
                                  notchDepth: m.notchDepth, grow: max(4, m.rim * 0.9),
                                  from: m.rim + 2, to: size.width - m.rim - 2, step: 0.5)
            let loop = max(3.2, m.cardWidth * 0.013)
            var travelled: CGFloat = 0
            for i in 1..<pts.count {
                let a = pts[i - 1], b = pts[i]
                travelled += hypot(b.x - a.x, b.y - a.y)
                guard travelled >= loop * 1.25 else { continue }
                travelled = 0
                let angle = atan2(b.y - a.y, b.x - a.x)
                let t = CGAffineTransform(translationX: b.x, y: b.y).rotated(by: angle)
                let oval = Path(ellipseIn: CGRect(x: -loop * 0.6, y: -loop * 0.42, width: loop * 1.2, height: loop * 0.84))
                // Shadow a hair below, then the raised loop: pressed plastic.
                ctx.stroke(oval.applying(t.translatedBy(x: 0, y: 0.7)), with: .color(shade), lineWidth: 1.0)
                ctx.stroke(oval.applying(t), with: .color(color), lineWidth: 1.0)
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - One half

/// One half of the sleeve, drawn mouth-up with the fold along its top edge. The
/// top half of the pouch is this same view turned round, which is also why its
/// cards sit upside down, exactly as in the real pouch.
struct PouchPocket<Card: View>: View {
    let m: PouchMetrics
    let style: PlasticStyle
    /// How many card edges peek out below the front card.
    let stackEdges: Int
    /// Where the highlight sits across the plastic, 0…1.
    let shine: CGFloat
    @ViewBuilder let card: () -> Card

    var body: some View {
        let size = CGSize(width: m.pouchWidth, height: m.halfHeight)
        let frame = m.cardFrame
        ZStack(alignment: .topLeading) {
            HalfSheetShape(m: m).fill(style.tint)

            // The fold: the sheet bends here, darker into the crease with a
            // bright line right on it.
            LinearGradient(colors: [style.crease, .clear],
                           startPoint: .top, endPoint: UnitPoint(x: 0.5, y: m.foldGap / m.halfHeight * 0.8))
            // Light catching the bend, brightest off to one side like the photo.
            LinearGradient(stops: [
                .init(color: .clear, location: 0.45),
                .init(color: style.edgeLight.opacity(0.7), location: 0.78),
                .init(color: .clear, location: 0.95),
            ], startPoint: .leading, endPoint: .trailing)
            .frame(height: 1.6)
            .blur(radius: 0.6)
            .offset(y: m.foldGap * 0.25)

            // The stack: edges of the cards behind the front one.
            ForEach(0..<stackEdges, id: \.self) { i in
                let n = stackEdges - i
                RoundedRectangle(cornerRadius: 2)
                    .fill(n % 2 == 0 ? PouchInk.paperBack : Color(white: 0.89))
                    .overlay(RoundedRectangle(cornerRadius: 2).strokeBorder(Color.black.opacity(0.10), lineWidth: 0.5))
                    .frame(width: frame.width, height: frame.height)
                    .offset(x: frame.minX, y: frame.minY + CGFloat(n) * 1.5)
            }

            card()
                .frame(width: frame.width, height: frame.height)
                .offset(x: frame.minX, y: frame.minY)
                .shadow(color: .black.opacity(0.10), radius: 1, y: 0.5)

            // Front layer of the pocket, with the light moving across it.
            PocketPanelShape(m: m)
                .fill(style.panel)
                .overlay(
                    LinearGradient(stops: [
                        .init(color: .clear, location: 0),
                        .init(color: style.shine, location: 0.10),
                        .init(color: .clear, location: 0.22),
                        .init(color: style.shine.opacity(0.35), location: 0.36),
                        .init(color: .clear, location: 0.46),
                    ], startPoint: UnitPoint(x: -0.6 + shine * 1.4, y: 0),
                       endPoint: UnitPoint(x: 0.4 + shine * 1.4, y: 1))
                    .clipShape(PocketPanelShape(m: m))
                )
            MouthEdgeShape(m: m, grow: 0.8).stroke(style.edgeShade, lineWidth: 0.8)
            MouthEdgeShape(m: m).stroke(style.edgeLight, lineWidth: 1)
            EmbossedBand(m: m, color: style.emboss, shade: style.embossShade)

            // The weld along the sides and outer edge, over everything.
            RimShape(m: m, inset: m.rim / 2).stroke(style.rim, lineWidth: m.rim)
            SideCrimp(m: m, style: style)
            RimShape(m: m, inset: m.rim).stroke(style.edgeShade.opacity(0.7), lineWidth: 0.6)
            RimShape(m: m, inset: 0.5).stroke(style.edgeLight.opacity(0.8), lineWidth: 0.8)
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        .clipShape(HalfSheetShape(m: m))
    }
}

/// The outside of the closed pouch: the plastic over the pack's cover card.
struct PouchExterior<Card: View>: View {
    let m: PouchMetrics
    let style: PlasticStyle
    let shine: CGFloat
    @ViewBuilder let card: () -> Card

    var body: some View {
        // Its top edge is the fold, so square there and no weld.
        let shape = HalfSheetShape(m: m)
        let frame = m.cardFrame
        ZStack(alignment: .topLeading) {
            shape.fill(style.tint)
            shape.fill(style.tint)          // two layers of plastic folded together
            ForEach(0..<4, id: \.self) { i in
                RoundedRectangle(cornerRadius: 2)
                    .fill(i % 2 == 0 ? PouchInk.paperBack : Color(white: 0.89))
                    .frame(width: frame.width, height: frame.height)
                    .offset(x: frame.minX, y: frame.minY + CGFloat(4 - i) * 1.5)
            }
            card()
                .frame(width: frame.width, height: frame.height)
                .offset(x: frame.minX, y: frame.minY)
            LinearGradient(stops: [
                .init(color: .clear, location: 0),
                .init(color: style.shine, location: 0.12),
                .init(color: .clear, location: 0.24),
                .init(color: style.shine.opacity(0.3), location: 0.40),
                .init(color: .clear, location: 0.5),
            ], startPoint: UnitPoint(x: -0.6 + shine * 1.4, y: 0), endPoint: UnitPoint(x: 0.4 + shine * 1.4, y: 1))
            .clipShape(shape)
            LinearGradient(colors: [style.crease, .clear], startPoint: .top,
                           endPoint: UnitPoint(x: 0.5, y: m.foldGap / m.halfHeight * 0.8))
            Rectangle().fill(style.edgeLight.opacity(0.8)).frame(height: 1)
            RimShape(m: m, inset: m.rim / 2).stroke(style.rim, lineWidth: m.rim)
            SideCrimp(m: m, style: style)
            RimShape(m: m, inset: m.rim).stroke(style.edgeShade.opacity(0.7), lineWidth: 0.6)
            RimShape(m: m, inset: 0.5).stroke(style.edgeLight.opacity(0.8), lineWidth: 0.8)
        }
        .frame(width: m.pouchWidth, height: m.halfHeight, alignment: .topLeading)
        .clipShape(shape)
    }
}
