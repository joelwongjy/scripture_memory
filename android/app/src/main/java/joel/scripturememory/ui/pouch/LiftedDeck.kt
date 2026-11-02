package joel.scripturememory.ui.pouch

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.dropShadow
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.CompositingStrategy
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.DpOffset
import androidx.compose.ui.unit.dp
import joel.scripturememory.model.PackListLayout
import joel.scripturememory.ui.packs.ShadowRadiusScale
import joel.scripturememory.ui.theme.AppTheme
import joel.scripturememory.ui.theme.PouchInk
import kotlin.math.abs
import kotlin.math.max
import kotlin.math.min

private val paperShape = RoundedCornerShape(2.dp)

@Composable
internal fun LiftedDeck(
    lift: () -> Float,
    spread: () -> Float,
    pocketCenter: Offset,
    listCenter: () -> Offset,
    pocketWidth: Float,
    listWidth: Dp,
    listHeight: Dp,
    listPitch: Float,
    columnPitch: Float,
    layout: PackListLayout,
    frontCard: Int,
    around: (Int) -> PouchCard,
    edges: Int,
    drift: () -> Float,
    modifier: Modifier = Modifier,
    face: @Composable (PouchCard) -> Unit,
) {
    val dark = AppTheme.isDark
    val paper = PouchInk.paper(dark)
    val edgeLine = PouchInk.edgeLine(dark)
    val startScale = pocketWidth / listWidth.value

    fun scale() = startScale + (1f - startScale) * lift()
    fun down() = listPitch / max(scale(), 0.01f) * spread()
    fun across() = columnPitch / max(scale(), 0.01f) * spread()
    val reach = 3 * layout.columns

    Box(
        modifier
            .size(listWidth, listHeight)
            .graphicsLayer {
                val s = scale()
                val t = lift()
                val target = listCenter()
                scaleX = s
                scaleY = s
                translationX = pocketCenter.x + (target.x - pocketCenter.x) * t - size.width / 2 + drift()
                translationY = pocketCenter.y + (target.y - pocketCenter.y) * t - size.height / 2
                alpha = if (t > 0.02f) 1f else 0f
            }
            .dropShadow(paperShape) {
                radius = 1.5.dp.toPx() * ShadowRadiusScale
                color = Color.Black
                alpha = 0.14f * lift() * (1f - spread())
                offset = Offset(0f, 1.dp.toPx())
            }
            .dropShadow(paperShape) {
                radius = 16.dp.toPx() * ShadowRadiusScale
                color = Color.Black
                alpha = 0.09f * lift() * (1f - spread())
                offset = Offset(0f, (8f * lift()).dp.toPx())
            },
    ) {
        if (edges > 0) {
            Canvas(Modifier.matchParentSize().graphicsLayer { alpha = 1f - spread() }) {
                val density = this.density
                for (i in 0 until edges) {
                    val n = edges - i
                    val top = n * 1.1f * density
                    drawRoundRect(paper, Offset(0f, top), size, CornerRadius(2f * density))
                    drawRect(
                        edgeLine,
                        Offset(0f, top + size.height - 0.5f * density),
                        Size(size.width, 0.5f * density),
                    )
                }
            }
        }
        for (k in reach downTo 1) {
            val below = layout.offset(frontCard, k)
            val above = layout.offset(frontCard, -k)
            DeckCard(
                around(k),
                { across() * below.first },
                { down() * below.second },
                { 1f },
                spread,
                listWidth,
                listHeight,
                face,
            )
            DeckCard(
                around(-k),
                { across() * above.first },
                { down() * above.second },
                {
                    val s = spread()
                    if (s > 0f) min(1f, max(0f, s * 2f - (abs(above.second) - 1) * 0.5f)) else 0f
                },
                spread,
                listWidth,
                listHeight,
                face,
            )
        }
        DeckCard(around(0), { 0f }, { 0f }, { 1f }, spread, listWidth, listHeight, face)
    }
}

@Composable
private fun DeckCard(
    card: PouchCard,
    offsetX: () -> Float,
    offsetY: () -> Float,
    opacity: () -> Float,
    spread: () -> Float,
    width: Dp,
    height: Dp,
    face: @Composable (PouchCard) -> Unit,
) {
    if (card == PouchCard.None) return
    Box(
        Modifier
            .size(width, height)
            .graphicsLayer {
                translationX = offsetX()
                translationY = offsetY()
                alpha = opacity()
            }
            .listCardShadow(spread),
    ) {
        Box(
            Modifier
                .matchParentSize()
                .graphicsLayer { compositingStrategy = CompositingStrategy.Offscreen },
            contentAlignment = Alignment.TopStart,
        ) { face(card) }
    }
}
