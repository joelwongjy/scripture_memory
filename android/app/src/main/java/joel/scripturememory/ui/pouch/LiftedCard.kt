package joel.scripturememory.ui.pouch

import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.derivedStateOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.dropShadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.CustomAccessibilityAction
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.customActions
import androidx.compose.ui.semantics.onClick
import androidx.compose.ui.semantics.role
import androidx.compose.ui.unit.dp
import joel.scripturememory.model.PackListLayout
import joel.scripturememory.model.Verse
import joel.scripturememory.ui.packs.ShadowRadiusScale
import joel.scripturememory.ui.theme.AppLayout
import joel.scripturememory.ui.theme.AppMotion
import kotlin.math.PI
import kotlin.math.cos

internal data class LiftedCard(val index: Int, val source: Rect)

private val paperShape = RoundedCornerShape(2.dp)

@Composable
internal fun LiftedCardView(
    verse: Verse,
    isLearnt: Boolean,
    source: Rect,
    area: Rect,
    lift: () -> Float,
    angle: () -> Float,
    onFlip: () -> Unit,
    onPutBack: () -> Unit,
) {
    val density = LocalDensity.current.density
    val still = AppMotion.reduceMotion
    val widthDp = PackListLayout.liftedWidth(
        source.width / density,
        area.width / density,
        area.height / density,
        AppLayout.cardAspect,
        AppLayout.screenMargin.value,
    )
    val width = widthDp.dp
    val height = width / AppLayout.cardAspect
    val showsReference by remember { derivedStateOf { angle() > 90f } }

    Box(Modifier.fillMaxSize()) {
        Box(
            Modifier
                .matchParentSize()
                .clickable(remember { MutableInteractionSource() }, null, onClick = onPutBack)
                .clearAndSetSemantics { },
        )
        Box(
            Modifier
                .size(width, height)
                .graphicsLayer {
                    val moved = if (still) 1f else lift()
                    val s = 1f + (source.width / size.width - 1f) * (1f - moved)
                    scaleX = s
                    scaleY = s
                    translationX = source.center.x + (area.center.x - source.center.x) * moved - size.width / 2
                    translationY = source.center.y + (area.center.y - source.center.y) * moved - size.height / 2
                    rotationY = if (still) 0f else angle()
                    cameraDistance = 12f * this.density
                    alpha = if (still) lift() else 1f
                }
                .dropShadow(paperShape) {
                    radius = 22.dp.toPx() * ShadowRadiusScale
                    color = Color.Black
                    alpha = 0.28f * lift()
                    offset = Offset(0f, 12.dp.toPx())
                }
                .clearAndSetSemantics {
                    contentDescription = if (showsReference) {
                        "${verse.book} ${verse.reference}"
                    } else {
                        "${verse.title}, ${verse.book} ${verse.reference}. ${verse.verse}"
                    }
                    role = Role.Button
                    onClick("Turns the card over") {
                        onFlip()
                        true
                    }
                    customActions = listOf(
                        CustomAccessibilityAction("Put Back") {
                            onPutBack()
                            true
                        },
                    )
                }
                .clickable(remember { MutableInteractionSource() }, null, onClick = onFlip),
        ) {
            Box(
                Modifier
                    .matchParentSize()
                    .graphicsLayer {
                        val turn = cos(angle() * PI.toFloat() / 180f)
                        alpha = if (still) (1f + turn) / 2f else if (turn >= 0f) 1f else 0f
                    },
            ) {
                PaperAppearance { PouchVerseCard(verse, isLearnt, width) }
            }
            Box(
                Modifier
                    .matchParentSize()
                    .graphicsLayer {
                        val turn = cos(angle() * PI.toFloat() / 180f)
                        scaleX = if (still) 1f else -1f
                        alpha = if (still) (1f - turn) / 2f else if (turn >= 0f) 0f else 1f
                    },
            ) {
                PaperAppearance { PouchCardBack(verse, width) }
            }
        }
    }
}
