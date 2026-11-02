package joel.scripturememory.ui.pouch

import android.graphics.BlurMaskFilter
import android.graphics.LinearGradient
import android.graphics.Matrix
import android.graphics.RectF
import android.graphics.Shader
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.Immutable
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.dropShadow
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.CompositingStrategy
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.asComposePath
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.scale
import androidx.compose.ui.graphics.drawscope.drawIntoCanvas
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.nativeCanvas
import androidx.compose.ui.graphics.shadow.Shadow
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.unit.DpOffset
import androidx.compose.ui.unit.dp
import joel.scripturememory.ui.packs.ShadowRadiusScale
import joel.scripturememory.ui.theme.AppLayout
import joel.scripturememory.ui.theme.AppTheme
import joel.scripturememory.ui.theme.PouchInk
import kotlin.math.atan2
import kotlin.math.hypot
import kotlin.math.max
import kotlin.math.min

@Immutable
internal class PouchMetrics private constructor(width: Float) {
    val pouchWidth: Float = width
    val rim: Float = max(5f, width * 0.028f)
    val cardHeight: Float = width * 0.86f / cardAspect
    val cardWidth: Float = cardHeight * cardAspect
    val foldGap: Float = cardHeight * 0.13f
    val stackRoom: Float = cardHeight * 0.06f
    val halfHeight: Float = foldGap + cardHeight + stackRoom + rim + 6f
    val notchWidth: Float = cardWidth * 0.42f
    val notchDepth: Float = cardHeight * 0.20f
    val corner: Float = rim * 2.4f

    val mouthCorner: Float get() = foldGap * 0.8f
    val embossCell: Float get() = max(3f, cardWidth * 0.018f)
    val cardFrame: Rect
        get() = Rect(
            Offset((pouchWidth - cardWidth) / 2, foldGap - 1f),
            Size(cardWidth, cardHeight),
        )

    companion object {
        const val cardAspect = AppLayout.cardAspect

        fun fitting(width: Float, height: Float): PouchMetrics {
            var fitted = min(width - 2 * AppLayout.screenMargin.value, 560f)
            var m = PouchMetrics(fitted)
            if (2 * m.halfHeight > height) {
                fitted *= height / (2 * m.halfHeight)
                m = PouchMetrics(fitted)
            }
            return m
        }
    }
}

@Immutable
internal class PlasticStyle(dark: Boolean) {
    val tint: Color
    val panel: Color
    val rim: Color
    val edgeLight: Color
    val edgeShade: Color
    val shine: Color
    val emboss: Color
    val embossShade: Color
    val crease: Color

    init {
        if (dark) {
            tint = Color.White.copy(alpha = 0.055f)
            panel = Color.White.copy(alpha = 0.03f)
            rim = Color.White.copy(alpha = 0.13f)
            edgeLight = Color.White.copy(alpha = 0.5f)
            edgeShade = Color.Black.copy(alpha = 0.35f)
            shine = Color.White.copy(alpha = 0.14f)
            emboss = Color.White.copy(alpha = 0.75f)
            embossShade = Color.Black.copy(alpha = 0.45f)
            crease = Color.White.copy(alpha = 0.07f)
        } else {
            tint = Color(0.3f, 0.3f, 0.3f, 0.06f)
            panel = Color(0.5f, 0.5f, 0.5f, 0.035f)
            rim = Color(0.35f, 0.35f, 0.35f, 0.13f)
            edgeLight = Color.White.copy(alpha = 0.95f)
            edgeShade = Color.Black.copy(alpha = 0.13f)
            shine = Color.White.copy(alpha = 0.6f)
            emboss = Color.White
            embossShade = Color.Black.copy(alpha = 0.22f)
            crease = Color.Black.copy(alpha = 0.07f)
        }
    }
}

private fun mouthPoints(
    width: Float,
    y: Float,
    notchWidth: Float,
    notchDepth: Float,
    from: Float,
    to: Float,
    step: Float = 2f,
): List<Offset> {
    val w = notchWidth
    val d = notchDepth
    val cx = width / 2
    val xs = cx - w / 2
    val xe = cx + w / 2
    val pts = ArrayList<Offset>()
    var x = from
    while (x < xs) {
        pts += Offset(x, y)
        x += step
    }
    fun cubic(p0: Offset, c1: Offset, c2: Offset, p3: Offset) {
        val n = max(8, (w / step).toInt())
        for (i in 0..n) {
            val t = i.toFloat() / n
            val m = 1 - t
            val a = m * m * m
            val b = 3 * m * m * t
            val c = 3 * m * t * t
            val e = t * t * t
            pts += Offset(a * p0.x + b * c1.x + c * c2.x + e * p3.x, a * p0.y + b * c1.y + c * c2.y + e * p3.y)
        }
    }
    cubic(Offset(xs, y), Offset(xs + w * 0.20f, y), Offset(cx - w * 0.30f, y + d), Offset(cx, y + d))
    cubic(Offset(cx, y + d), Offset(cx + w * 0.30f, y + d), Offset(xe - w * 0.20f, y), Offset(xe, y))
    x = xe + step
    while (x <= to) {
        pts += Offset(x, y)
        x += step
    }
    return pts
}

private fun mouthOutline(m: PouchMetrics, width: Float): List<Offset> {
    val rc = m.mouthCorner
    val y = m.foldGap
    val left = m.rim
    val right = width - m.rim
    fun quad(a: Offset, c: Offset, b: Offset): List<Offset> = (0..12).map { i ->
        val t = i / 12f
        val u = 1 - t
        Offset(u * u * a.x + 2 * u * t * c.x + t * t * b.x, u * u * a.y + 2 * u * t * c.y + t * t * b.y)
    }
    return quad(Offset(left, y + rc), Offset(left, y), Offset(left + rc, y)) +
        mouthPoints(width, y, m.notchWidth, m.notchDepth, left + rc + 2, right - rc - 2) +
        quad(Offset(right - rc, y), Offset(right, y), Offset(right, y + rc))
}

private fun offsetIntoPanel(points: List<Offset>, distance: Float): List<Offset> {
    if (points.size <= 1 || distance == 0f) return points
    return points.indices.map { i ->
        val a = points[max(i - 1, 0)]
        val b = points[min(i + 1, points.size - 1)]
        val dx = b.x - a.x
        val dy = b.y - a.y
        val len = max(hypot(dx, dy), 0.0001f)
        Offset(points[i].x + -dy / len * distance, points[i].y + dx / len * distance)
    }
}

private fun polyline(points: List<Offset>, path: Path = Path()): Path {
    points.forEachIndexed { i, p -> if (i == 0) path.moveTo(p.x, p.y) else path.lineTo(p.x, p.y) }
    return path
}

private fun halfSheet(m: PouchMetrics): Path = Path().apply {
    val w = m.pouchWidth
    val h = m.halfHeight
    val c = m.corner
    moveTo(w, 0f)
    lineTo(w, h - c)
    quadraticTo(w, h, w - c, h)
    lineTo(c, h)
    quadraticTo(0f, h, 0f, h - c)
    lineTo(0f, 0f)
    close()
}

private fun rimPath(m: PouchMetrics, inset: Float): Path = Path().apply {
    val w = m.pouchWidth
    val c = max(0f, m.corner - inset)
    val bottom = m.halfHeight - inset
    moveTo(inset, 0f)
    lineTo(inset, bottom - c)
    quadraticTo(inset, bottom, inset + c, bottom)
    lineTo(w - inset - c, bottom)
    quadraticTo(w - inset, bottom, w - inset, bottom - c)
    lineTo(w - inset, 0f)
}

private fun pocketPanel(m: PouchMetrics): Path = Path().apply {
    val w = m.pouchWidth
    val h = m.halfHeight
    moveTo(0f, m.foldGap + m.mouthCorner)
    mouthOutline(m, w).forEach { lineTo(it.x, it.y) }
    lineTo(w, m.foldGap + m.mouthCorner)
    lineTo(w, h - m.corner)
    quadraticTo(w, h, w - m.corner, h)
    lineTo(m.corner, h)
    quadraticTo(0f, h, 0f, h - m.corner)
    close()
}

internal class PlasticGeometry(val m: PouchMetrics) {
    val sheet = halfSheet(m)
    val panel = pocketPanel(m)
    val mouthEdge = polyline(mouthOutline(m, m.pouchWidth))
    val mouthEdgeShade = polyline(offsetIntoPanel(mouthOutline(m, m.pouchWidth), 0.8f))
    val rimCenter = rimPath(m, m.rim / 2)
    val rimInner = rimPath(m, m.rim)
    val rimOuter = rimPath(m, 0.5f)
    val crimpLight: Path
    val crimpShade: Path
    val embossCells: Path
    val embossShades: Path

    init {
        val light = Path()
        val shade = Path()
        val bottom = m.halfHeight - m.corner
        for (k in 1..4) {
            val inset = m.rim * k / 5f
            for ((x, inward) in listOf(0f to 1f, m.pouchWidth to -1f)) {
                val at = x + inward * inset
                light.moveTo(at, 0f)
                light.lineTo(at, bottom)
                shade.moveTo(at + inward * 0.5f, 0f)
                shade.lineTo(at + inward * 0.5f, bottom)
            }
        }
        crimpLight = light
        crimpShade = shade

        val cell = m.embossCell
        val pitch = cell * 1.12f
        val edge = offsetIntoPanel(mouthOutline(m, m.pouchWidth), cell * 0.5f + 1.5f)
        val dense = ArrayList<Offset>()
        for (i in 1 until edge.size) {
            val a = edge[i - 1]
            val b = edge[i]
            val n = max(1, (hypot(b.x - a.x, b.y - a.y) / 0.5f).toInt())
            for (k in 0 until n) {
                val t = k.toFloat() / n
                dense += Offset(a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t)
            }
        }
        val cellPath = android.graphics.Path().apply {
            addRoundRect(
                RectF(-cell / 2, -cell * 0.45f, cell / 2, cell * 0.45f),
                cell * 0.3f,
                cell * 0.3f,
                android.graphics.Path.Direction.CW,
            )
        }
        val cells = android.graphics.Path()
        val shades = android.graphics.Path()
        val matrix = Matrix()
        var travelled = pitch / 2
        for (i in 1 until dense.size) {
            val a = dense[i - 1]
            val b = dense[i]
            travelled += hypot(b.x - a.x, b.y - a.y)
            if (travelled < pitch) continue
            travelled = 0f
            val degrees = Math.toDegrees(atan2(b.y - a.y, b.x - a.x).toDouble()).toFloat()
            matrix.reset()
            matrix.postRotate(degrees)
            matrix.postTranslate(b.x, b.y)
            cells.addPath(cellPath, matrix)
            matrix.reset()
            matrix.postTranslate(0f, 0.6f)
            matrix.postRotate(degrees)
            matrix.postTranslate(b.x, b.y)
            shades.addPath(cellPath, matrix)
        }
        embossCells = cells.asComposePath()
        embossShades = shades.asComposePath()
    }
}

private inline fun DrawScope.inPoints(block: DrawScope.() -> Unit) {
    val density = this.density
    scale(density, density, pivot = Offset.Zero, block)
}

private fun DrawScope.drawCrease(g: PlasticGeometry, style: PlasticStyle) {
    val m = g.m
    drawPath(
        g.sheet,
        Brush.verticalGradient(
            listOf(style.crease, style.crease.copy(alpha = 0f)),
            startY = 0f,
            endY = m.halfHeight * (m.foldGap / m.halfHeight * 0.8f),
        ),
    )
}

private fun shineBrush(
    style: PlasticStyle,
    m: PouchMetrics,
    shine: Float,
    stops: Array<Pair<Float, Color>>,
): Brush {
    val w = m.pouchWidth
    return Brush.linearGradient(
        colorStops = stops,
        start = Offset((-0.6f + shine * 1.4f) * w, 0f),
        end = Offset((0.4f + shine * 1.4f) * w, m.halfHeight),
    )
}

private fun panelStops(style: PlasticStyle): Array<Pair<Float, Color>> {
    val clear = style.shine.copy(alpha = 0f)
    return arrayOf(
        0f to clear,
        0.10f to style.shine,
        0.22f to clear,
        0.36f to style.shine.copy(alpha = style.shine.alpha * 0.35f),
        0.46f to clear,
    )
}

private fun exteriorStops(style: PlasticStyle): Array<Pair<Float, Color>> {
    val clear = style.shine.copy(alpha = 0f)
    return arrayOf(
        0f to clear,
        0.12f to style.shine,
        0.24f to clear,
        0.40f to style.shine.copy(alpha = style.shine.alpha * 0.3f),
        0.5f to clear,
    )
}

private fun DrawScope.drawRims(g: PlasticGeometry, style: PlasticStyle) {
    val m = g.m
    drawPath(g.rimCenter, style.rim, style = Stroke(m.rim))
    drawPath(g.crimpShade, style.edgeShade, style = Stroke(0.5f))
    drawPath(g.crimpLight, style.edgeLight.copy(alpha = style.edgeLight.alpha * 0.75f), style = Stroke(0.6f))
    drawPath(g.rimInner, style.edgeShade.copy(alpha = style.edgeShade.alpha * 0.7f), style = Stroke(0.6f))
    drawPath(g.rimOuter, style.edgeLight.copy(alpha = style.edgeLight.alpha * 0.8f), style = Stroke(0.8f))
}

private fun DrawScope.drawFoldLight(g: PlasticGeometry, style: PlasticStyle) {
    val m = g.m
    val color = style.edgeLight.copy(alpha = style.edgeLight.alpha * 0.7f).toArgb()
    val clear = style.edgeLight.copy(alpha = 0f).toArgb()
    val y = m.foldGap * 0.25f
    val paint = android.graphics.Paint(android.graphics.Paint.ANTI_ALIAS_FLAG).apply {
        shader = LinearGradient(
            0f, 0f, m.pouchWidth, 0f,
            intArrayOf(clear, color, clear),
            floatArrayOf(0.45f, 0.78f, 0.95f),
            Shader.TileMode.CLAMP,
        )
        maskFilter = BlurMaskFilter(0.2f, BlurMaskFilter.Blur.NORMAL)
    }
    drawIntoCanvas { it.nativeCanvas.drawRect(0f, y, m.pouchWidth, y + 1.6f, paint) }
}

@Composable
internal fun PouchPocket(
    geometry: PlasticGeometry,
    style: PlasticStyle,
    stackEdges: Int,
    shine: () -> Float,
    stackAlpha: () -> Float,
    modifier: Modifier = Modifier,
    card: @Composable BoxScope.() -> Unit,
) {
    val m = geometry.m
    val frame = m.cardFrame
    val dark = AppTheme.isDark
    val stops = remember(style) { panelStops(style) }
    Box(modifier.size(m.pouchWidth.dp, m.halfHeight.dp)) {
        Canvas(Modifier.matchParentSize().graphicsLayer { compositingStrategy = CompositingStrategy.Offscreen }) {
            inPoints {
                drawPath(geometry.sheet, style.tint)
                drawCrease(geometry, style)
                drawFoldLight(geometry, style)
            }
        }
        Box(Modifier.matchParentSize().graphicsLayer { alpha = stackAlpha() }) {
            if (stackEdges > 0) {
                Canvas(Modifier.matchParentSize()) {
                    inPoints {
                        for (i in 0 until stackEdges) {
                            val n = stackEdges - i
                            drawPaperEdge(
                                Offset(frame.left, frame.top + n * 1.5f),
                                frame.size,
                                if (n % 2 == 0) PouchInk.paperBack(dark) else PouchInk.paperEdge(dark),
                            )
                        }
                    }
                }
            }
            Box(
                Modifier
                    .offset(frame.left.dp, frame.top.dp)
                    .size(frame.width.dp, frame.height.dp)
                    .dropShadow(
                        RoundedCornerShape(2.dp),
                        Shadow(
                            radius = 1.dp * ShadowRadiusScale,
                            color = Color.Black,
                            alpha = 0.10f,
                            offset = DpOffset(0.dp, 0.5.dp),
                        ),
                    ),
                content = card,
            )
        }
        Canvas(Modifier.matchParentSize().graphicsLayer { }) {
            val s = shine()
            inPoints {
                drawPath(geometry.panel, style.panel)
                drawPath(geometry.panel, shineBrush(style, m, s, stops))
            }
        }
        Canvas(Modifier.matchParentSize().graphicsLayer { compositingStrategy = CompositingStrategy.Offscreen }) {
            inPoints {
                drawPath(geometry.mouthEdgeShade, style.edgeShade, style = Stroke(0.8f))
                drawPath(geometry.mouthEdge, style.edgeLight, style = Stroke(1f))
                drawPath(geometry.embossShades, style.embossShade, style = Stroke(0.9f))
                drawPath(geometry.embossCells, style.emboss.copy(alpha = style.emboss.alpha * 0.28f))
                drawPath(geometry.embossCells, style.emboss, style = Stroke(0.9f))
                drawRims(geometry, style)
            }
        }
    }
}

private fun DrawScope.drawPaperEdge(topLeft: Offset, size: Size, fill: Color) {
    drawRoundRect(fill, topLeft, size, CornerRadius(2f))
    drawRoundRect(
        Color.Black.copy(alpha = 0.10f),
        Offset(topLeft.x + 0.25f, topLeft.y + 0.25f),
        Size(size.width - 0.5f, size.height - 0.5f),
        CornerRadius(1.75f),
        style = Stroke(0.5f),
    )
}

@Composable
internal fun PouchExterior(
    geometry: PlasticGeometry,
    style: PlasticStyle,
    shine: () -> Float,
    modifier: Modifier = Modifier,
    card: @Composable BoxScope.() -> Unit,
) {
    val m = geometry.m
    val frame = m.cardFrame
    val dark = AppTheme.isDark
    val stops = remember(style) { exteriorStops(style) }
    Box(modifier.size(m.pouchWidth.dp, m.halfHeight.dp)) {
        Canvas(Modifier.matchParentSize().graphicsLayer { compositingStrategy = CompositingStrategy.Offscreen }) {
            inPoints {
                drawPath(geometry.sheet, style.tint)
                drawPath(geometry.sheet, style.tint)
                for (i in 0 until 4) {
                    drawRoundRect(
                        if (i % 2 == 0) PouchInk.paperBack(dark) else PouchInk.paperEdge(dark),
                        Offset(frame.left, frame.top + (4 - i) * 1.5f),
                        frame.size,
                        CornerRadius(2f),
                    )
                }
            }
        }
        Box(
            Modifier
                .offset(frame.left.dp, frame.top.dp)
                .size(frame.width.dp, frame.height.dp),
            content = card,
        )
        Canvas(Modifier.matchParentSize().graphicsLayer { }) {
            val s = shine()
            inPoints { drawPath(geometry.sheet, shineBrush(style, m, s, stops)) }
        }
        Canvas(Modifier.matchParentSize().graphicsLayer { compositingStrategy = CompositingStrategy.Offscreen }) {
            inPoints {
                drawCrease(geometry, style)
                drawRect(
                    style.edgeLight.copy(alpha = style.edgeLight.alpha * 0.8f),
                    Offset.Zero,
                    Size(m.pouchWidth, 1f),
                )
                drawRims(geometry, style)
            }
        }
    }
}
