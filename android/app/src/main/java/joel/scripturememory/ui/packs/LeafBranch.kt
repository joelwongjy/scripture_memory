package joel.scripturememory.ui.packs

import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Path
import kotlin.math.max
import kotlin.math.sqrt

private class Leaf(val t: Float, val below: Boolean, val length: Float)

private val leaves = listOf(
    Leaf(0.20f, true, 0.30f),
    Leaf(0.34f, true, 0.34f),
    Leaf(0.50f, true, 0.31f),
    Leaf(0.64f, true, 0.25f),
    Leaf(0.40f, false, 0.20f),
    Leaf(0.56f, false, 0.17f),
)

internal fun leafBranchPath(size: Size): Path {
    val p = Path()
    val w = size.width
    val h = size.height
    val start = Offset(0.02f * w, 0.80f * h)
    val end = Offset(0.74f * w, 0.20f * h)
    val c1 = Offset(0.34f * w, 0.82f * h)
    val c2 = Offset(0.52f * w, 0.40f * h)
    p.moveTo(start.x, start.y)
    p.cubicTo(c1.x, c1.y, c2.x, c2.y, end.x, end.y)

    p.moveTo(end.x, end.y)
    p.cubicTo(0.82f * w, 0.10f * h, 0.93f * w, 0.03f * h, 0.93f * w, 0.16f * h)
    p.cubicTo(0.93f * w, 0.26f * h, 0.85f * w, 0.28f * h, 0.86f * w, 0.20f * h)

    for (leaf in leaves) {
        addLeaf(p, leaf.t, leaf.below, leaf.length * w, start, c1, c2, end)
    }
    return p
}

private fun addLeaf(p: Path, t: Float, below: Boolean, length: Float, start: Offset, c1: Offset, c2: Offset, end: Offset) {
    val base = bezierPoint(t, start, c1, c2, end)
    val d = bezierTangent(t, start, c1, c2, end)
    val mag = max(0.0001f, sqrt(d.x * d.x + d.y * d.y))
    val unit = Offset(d.x / mag, d.y / mag)

    val sign = if (below) 1f else -1f
    val normal = Offset(-unit.y * sign, unit.x * sign)
    val dir = Offset(normal.x * 0.82f - unit.x * 0.42f, normal.y * 0.82f - unit.y * 0.42f)
    val dmag = max(0.0001f, sqrt(dir.x * dir.x + dir.y * dir.y))
    val axis = Offset(dir.x / dmag, dir.y / dmag)
    val tip = Offset(base.x + axis.x * length, base.y + axis.y * length)

    val side = Offset(-axis.y, axis.x)
    val belly = length * 0.30f
    val mid = Offset((base.x + tip.x) / 2, (base.y + tip.y) / 2)
    val a = Offset(mid.x + side.x * belly, mid.y + side.y * belly)
    val b = Offset(mid.x - side.x * belly, mid.y - side.y * belly)

    p.moveTo(base.x, base.y)
    p.quadraticTo(a.x, a.y, tip.x, tip.y)
    p.quadraticTo(b.x, b.y, base.x, base.y)

    p.moveTo(base.x, base.y)
    p.lineTo(tip.x, tip.y)
}

private fun bezierPoint(t: Float, p0: Offset, p1: Offset, p2: Offset, p3: Offset): Offset {
    val u = 1 - t
    return Offset(
        u * u * u * p0.x + 3 * u * u * t * p1.x + 3 * u * t * t * p2.x + t * t * t * p3.x,
        u * u * u * p0.y + 3 * u * u * t * p1.y + 3 * u * t * t * p2.y + t * t * t * p3.y,
    )
}

private fun bezierTangent(t: Float, p0: Offset, p1: Offset, p2: Offset, p3: Offset): Offset {
    val u = 1 - t
    return Offset(
        3 * u * u * (p1.x - p0.x) + 6 * u * t * (p2.x - p1.x) + 3 * t * t * (p3.x - p2.x),
        3 * u * u * (p1.y - p0.y) + 6 * u * t * (p2.y - p1.y) + 3 * t * t * (p3.y - p2.y),
    )
}
