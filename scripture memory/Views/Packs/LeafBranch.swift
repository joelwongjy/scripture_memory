import SwiftUI

/// The leaf-and-tendril line drawing from the cover of *Lessons on Assurance*.
///
/// Drawn rather than shipped as an asset so it inherits the cover's stroke
/// colour and scales cleanly with the pack tile, which renders at a fixed design
/// canvas and then scales to whatever width the grid gives it.
///
/// Everything is expressed as a fraction of the frame, so the proportions hold
/// at any size.
struct LeafBranch: Shape {

    /// Where along the stem each leaf sits, which side it falls on, and how long
    /// it is relative to the frame. Roughly the arrangement on the book: a run of
    /// leaves down the lower side, two shorter ones opposite.
    private static let leaves: [(t: CGFloat, below: Bool, length: CGFloat)] = [
        (0.20, true,  0.30),
        (0.34, true,  0.34),
        (0.50, true,  0.31),
        (0.64, true,  0.25),
        (0.40, false, 0.20),
        (0.56, false, 0.17),
    ]

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width, h = rect.height

        // The stem: a shallow S sweeping up from the lower left.
        let start = CGPoint(x: 0.02 * w, y: 0.80 * h)
        let end   = CGPoint(x: 0.74 * w, y: 0.20 * h)
        let c1    = CGPoint(x: 0.34 * w, y: 0.82 * h)
        let c2    = CGPoint(x: 0.52 * w, y: 0.40 * h)
        p.move(to: start)
        p.addCurve(to: end, control1: c1, control2: c2)

        // The tendril: continues past the tip and curls back on itself.
        p.move(to: end)
        p.addCurve(to: CGPoint(x: 0.93 * w, y: 0.16 * h),
                   control1: CGPoint(x: 0.82 * w, y: 0.10 * h),
                   control2: CGPoint(x: 0.93 * w, y: 0.03 * h))
        p.addCurve(to: CGPoint(x: 0.86 * w, y: 0.20 * h),
                   control1: CGPoint(x: 0.93 * w, y: 0.26 * h),
                   control2: CGPoint(x: 0.85 * w, y: 0.28 * h))

        for leaf in Self.leaves {
            addLeaf(to: &p, at: leaf.t, below: leaf.below, length: leaf.length * w,
                    start: start, c1: c1, c2: c2, end: end)
        }
        return p
    }

    /// A single leaf: two arcs meeting at a point, plus its midrib.
    ///
    /// Anchored to the stem's own curve and angled off its tangent, so the leaves
    /// follow the branch instead of being scattered near it.
    private func addLeaf(to p: inout Path, at t: CGFloat, below: Bool, length: CGFloat,
                         start: CGPoint, c1: CGPoint, c2: CGPoint, end: CGPoint) {
        let base = bezierPoint(t, start, c1, c2, end)
        let d    = bezierTangent(t, start, c1, c2, end)
        let mag  = max(0.0001, sqrt(d.x * d.x + d.y * d.y))
        let unit = CGPoint(x: d.x / mag, y: d.y / mag)

        // Off the stem at roughly 45°, leaning back toward its root.
        let sign: CGFloat = below ? 1 : -1
        let normal = CGPoint(x: -unit.y * sign, y: unit.x * sign)
        let dir    = CGPoint(x: normal.x * 0.82 - unit.x * 0.42,
                             y: normal.y * 0.82 - unit.y * 0.42)
        let dmag   = max(0.0001, sqrt(dir.x * dir.x + dir.y * dir.y))
        let axis   = CGPoint(x: dir.x / dmag, y: dir.y / dmag)
        let tip    = CGPoint(x: base.x + axis.x * length, y: base.y + axis.y * length)

        // Bulge the two sides out perpendicular to the leaf's own axis.
        let side  = CGPoint(x: -axis.y, y: axis.x)
        let belly = length * 0.30
        let mid   = CGPoint(x: (base.x + tip.x) / 2, y: (base.y + tip.y) / 2)
        let a = CGPoint(x: mid.x + side.x * belly, y: mid.y + side.y * belly)
        let b = CGPoint(x: mid.x - side.x * belly, y: mid.y - side.y * belly)

        p.move(to: base)
        p.addQuadCurve(to: tip, control: a)
        p.addQuadCurve(to: base, control: b)

        p.move(to: base)
        p.addLine(to: tip)
    }

    private func bezierPoint(_ t: CGFloat, _ p0: CGPoint, _ p1: CGPoint,
                             _ p2: CGPoint, _ p3: CGPoint) -> CGPoint {
        let u = 1 - t
        let x = u*u*u*p0.x + 3*u*u*t*p1.x + 3*u*t*t*p2.x + t*t*t*p3.x
        let y = u*u*u*p0.y + 3*u*u*t*p1.y + 3*u*t*t*p2.y + t*t*t*p3.y
        return CGPoint(x: x, y: y)
    }

    private func bezierTangent(_ t: CGFloat, _ p0: CGPoint, _ p1: CGPoint,
                               _ p2: CGPoint, _ p3: CGPoint) -> CGPoint {
        let u = 1 - t
        let x = 3*u*u*(p1.x - p0.x) + 6*u*t*(p2.x - p1.x) + 3*t*t*(p3.x - p2.x)
        let y = 3*u*u*(p1.y - p0.y) + 6*u*t*(p2.y - p1.y) + 3*t*t*(p3.y - p2.y)
        return CGPoint(x: x, y: y)
    }
}
