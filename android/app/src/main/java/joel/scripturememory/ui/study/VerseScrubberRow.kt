package joel.scripturememory.ui.study

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.input.pointer.positionChange
import androidx.compose.ui.semantics.ProgressBarRangeInfo
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.progressBarRangeInfo
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.setProgress
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import joel.scripturememory.R
import joel.scripturememory.model.ScrubberMath
import joel.scripturememory.system.HapticEngine
import joel.scripturememory.ui.components.ChromeIconButton
import joel.scripturememory.ui.components.softShadow
import joel.scripturememory.ui.theme.AppMotion
import joel.scripturememory.ui.theme.AppTheme
import kotlin.math.abs
import kotlin.math.roundToInt

private val thumbSize = 26.dp

@Composable
fun VerseScrubberRow(
    verseCount: Int,
    currentIndex: Int,
    onIndexChange: (Int) -> Unit,
    onScrubbingChange: (Boolean) -> Unit,
    onStepBack: () -> Unit,
    onStepForward: () -> Unit,
) {
    if (verseCount <= 1) return
    val colors = AppTheme.colors
    Row(
        Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        ChromeIconButton(
            R.drawable.ic_caret_left,
            "Previous Verse",
            enabled = currentIndex != 0,
            iconSize = 16.dp,
            onClick = onStepBack,
        )
        PositionSlider(
            verseCount = verseCount,
            currentIndex = currentIndex,
            onIndexChange = onIndexChange,
            onScrubbingChange = onScrubbingChange,
            modifier = Modifier.weight(1f),
        )
        ChromeIconButton(
            R.drawable.ic_caret_right,
            "Next Verse",
            enabled = currentIndex < verseCount - 1,
            iconSize = 16.dp,
            onClick = onStepForward,
        )
    }
}

@Composable
private fun PositionSlider(
    verseCount: Int,
    currentIndex: Int,
    onIndexChange: (Int) -> Unit,
    onScrubbingChange: (Boolean) -> Unit,
    modifier: Modifier,
) {
    val colors = AppTheme.colors
    val index by rememberUpdatedState(currentIndex)
    val change by rememberUpdatedState(onIndexChange)
    val scrubbing by rememberUpdatedState(onScrubbingChange)
    val fraction by animateFloatAsState(
        ScrubberMath.fraction(currentIndex, verseCount).toFloat(),
        AppMotion.control(),
        label = "scrubberThumb",
    )

    fun move(position: Float, width: Float, thumb: Float) {
        val value = ((position - thumb / 2) / (width - thumb)).coerceIn(0f, 1f) * (verseCount - 1)
        if (abs(value - index) < 0.6f) return
        val target = value.roundToInt()
        if (target == index || target !in 0 until verseCount) return
        change(target)
        HapticEngine.light()
    }

    BoxWithConstraints(
        modifier
            .height(44.dp)
            .semantics {
                contentDescription = "Verse position"
                stateDescription = "${currentIndex + 1} of $verseCount"
                progressBarRangeInfo = ProgressBarRangeInfo(
                    currentIndex.toFloat(),
                    0f..(verseCount - 1).toFloat(),
                    steps = (verseCount - 2).coerceAtLeast(0),
                )
                setProgress { value ->
                    val target = value.roundToInt().coerceIn(0, verseCount - 1)
                    if (target != index) change(target)
                    true
                }
            }
            .pointerInput(verseCount) {
                val thumb = thumbSize.toPx()
                val widthPx = size.width.toFloat()
                awaitEachGesture {
                    val down = awaitFirstDown()
                    down.consume()
                    scrubbing(true)
                    move(down.position.x, widthPx, thumb)
                    var dragging = true
                    while (dragging) {
                        val event = awaitPointerEvent()
                        val pointer = event.changes.firstOrNull { it.id == down.id }
                        if (pointer == null || !pointer.pressed) {
                            dragging = false
                        } else {
                            if (pointer.positionChange() != Offset.Zero) move(pointer.position.x, widthPx, thumb)
                            pointer.consume()
                        }
                    }
                    scrubbing(false)
                }
            },
        contentAlignment = Alignment.CenterStart,
    ) {
        val full = maxWidth
        val track = full - thumbSize
        Box(Modifier.fillMaxWidth().height(4.dp).clip(CircleShape).background(colors.fill)) {
            Box(
                Modifier
                    .fillMaxHeight()
                    .fillMaxWidth((fraction * track.value + thumbSize.value / 2) / full.value)
                    .background(colors.accent),
            )
        }
        Box(
            Modifier
                .offset { IntOffset((fraction * track.toPx()).roundToInt(), 0) }
                .size(thumbSize)
                .softShadow(CircleShape, 3.dp)
                .clip(CircleShape)
                .background(Color.White),
        )
    }
}
