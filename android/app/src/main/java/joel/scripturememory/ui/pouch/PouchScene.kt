package joel.scripturememory.ui.pouch

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.Composable
import androidx.compose.runtime.Immutable
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.TransformOrigin
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.unit.dp
import kotlin.math.max
import kotlin.math.min

@Immutable
internal sealed interface PouchCard {
    data class Verse(val index: Int) : PouchCard
    data object BackPage : PouchCard
    data object CoverBack : PouchCard
    data object None : PouchCard
}

@Immutable
internal data class PouchSlots(
    val top: PouchCard,
    val bottom: PouchCard,
    val topEdges: Int,
    val bottomEdges: Int,
)

private const val perspective = 0.35f
private const val pointsPerInch = 72f

@Composable
internal fun PouchScene(
    m: PouchMetrics,
    style: PlasticStyle,
    slots: PouchSlots,
    openness: () -> Float,
    lift: () -> Float,
    tilt: () -> Float,
    modifier: Modifier = Modifier,
    face: @Composable (PouchCard) -> Unit,
    cover: @Composable () -> Unit,
) {
    val geometry = remember(m) { PlasticGeometry(m) }
    val shine = { min(1f, max(0f, 0.35f + tilt() * 0.5f + (1f - openness()) * 0.3f)) }
    Box(
        modifier
            .size(m.pouchWidth.dp, (m.halfHeight * 2).dp)
            .graphicsLayer { translationY = -(1f - openness()) * (m.halfHeight / 2).dp.toPx() },
    ) {
        Box(
            Modifier
                .offset(y = m.halfHeight.dp)
                .size(m.pouchWidth.dp, m.halfHeight.dp)
                .graphicsLayer {
                    val lidAngle = (1f - openness()) * 180f
                    alpha = if (lidAngle > 90f) max(0f, (180f - lidAngle) / 60f - 0.5f) else 1f
                },
        ) {
            PouchPocket(
                geometry,
                style,
                slots.bottomEdges,
                shine = shine,
                stackAlpha = { if (lift() > 0.02f) 0f else 1f },
            ) { face(slots.bottom) }
        }

        Box(
            Modifier
                .size(m.pouchWidth.dp, m.halfHeight.dp)
                .graphicsLayer {
                    rotationX = -(1f - openness()) * 180f
                    transformOrigin = TransformOrigin(0.5f, 1f)
                    cameraDistance = m.pouchWidth.dp.toPx() / perspective / pointsPerInch
                },
        ) {
            Box(
                Modifier
                    .matchParentSize()
                    .graphicsLayer {
                        alpha = if ((1f - openness()) * 180f > 90f) 1f else 0f
                        scaleY = -1f
                    },
            ) {
                PouchExterior(geometry, style, shine = { 1f - shine() }) { cover() }
            }
            Box(
                Modifier
                    .matchParentSize()
                    .graphicsLayer {
                        alpha = if ((1f - openness()) * 180f > 90f) 0f else 1f
                        rotationZ = 180f
                    },
            ) {
                PouchPocket(
                    geometry,
                    style,
                    slots.topEdges,
                    shine = { 1f - shine() },
                    stackAlpha = { 1f },
                ) { face(slots.top) }
            }
        }
    }
}
