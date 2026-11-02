package joel.scripturememory.ui.components

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.foundation.gestures.drag
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.layout.wrapContentSize
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.input.pointer.positionChange
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import joel.scripturememory.R
import joel.scripturememory.model.ScrubberMath
import joel.scripturememory.system.HapticEngine
import joel.scripturememory.ui.theme.AppMotion
import joel.scripturememory.ui.theme.AppTheme
import joel.scripturememory.ui.theme.AppType
import joel.scripturememory.ui.theme.SerifFamily
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

private val thumbSize = 40.dp
private val thumbTrailingPad = 6.dp
private val trackInset = 8.dp
private val pillContentMaxWidth = 188.dp
private const val hideDelayMillis = 1400L

@Composable
fun VerseFastScrollOverlay(
    verseCount: Int,
    scrollFraction: Double,
    containerHeight: Dp,
    titleProvider: (Int) -> String,
    referenceProvider: (Int) -> String,
    onScrubTo: (Int) -> Unit,
    modifier: Modifier = Modifier,
) {
    val colors = AppTheme.colors
    val density = LocalDensity.current
    val scope = rememberCoroutineScope()
    var isDragging by remember { mutableStateOf(false) }
    var dragFraction by remember { mutableFloatStateOf(0f) }
    var visible by remember { mutableStateOf(false) }
    var hideJob by remember { mutableStateOf<Job?>(null) }
    var lastDragIndex by remember { mutableIntStateOf(-1) }

    val travel = with(density) {
        ScrubberMath.trackTravel(containerHeight.toPx().toDouble(), thumbSize.toPx().toDouble(), trackInset.toPx().toDouble())
    }
    val inset = with(density) { trackInset.toPx().toDouble() }
    val activeFraction = if (isDragging) dragFraction.toDouble() else scrollFraction.coerceIn(0.0, 1.0)
    val effectiveIndex = ScrubberMath.index(activeFraction, verseCount)
    val thumbY = ScrubberMath.thumbY(activeFraction, travel, inset).toFloat()
    val currentThumbY by rememberUpdatedState(thumbY)
    val currentTravel by rememberUpdatedState(travel)
    val currentOnScrub by rememberUpdatedState(onScrubTo)

    fun flash() {
        visible = true
        hideJob?.cancel()
        hideJob = scope.launch {
            delay(hideDelayMillis)
            if (!isDragging) visible = false
        }
    }

    LaunchedEffect(scrollFraction) { if (!isDragging) flash() }

    val shownAlpha by animateFloatAsState(if (visible || isDragging) 1f else 0f, AppMotion.control(), label = "scrubberAlpha")
    val thumbScale by animateFloatAsState(if (isDragging) 1.12f else 1f, AppMotion.control(), label = "scrubberScale")
    val thumbAlpha by animateFloatAsState(if (isDragging) 1f else 0.9f, AppMotion.control(), label = "scrubberOpacity")

    Box(
        modifier
            .fillMaxHeight()
            .graphicsLayer { alpha = shownAlpha },
    ) {
        AnimatedVisibility(
            visible = isDragging && effectiveIndex in 0 until verseCount,
            enter = fadeIn(AppMotion.control()),
            exit = fadeOut(AppMotion.control()),
            modifier = Modifier
                .align(Alignment.TopEnd)
                .offset { IntOffset(-(thumbSize + thumbTrailingPad + 12.dp).roundToPx(), thumbY.toInt() - 6.dp.roundToPx()) }
                .wrapContentSize(unbounded = true, align = Alignment.TopEnd),
        ) {
            val capsule = RoundedCornerShape(percent = 50)
            Column(
                Modifier
                    .softShadow(capsule, 6.dp)
                    .clip(capsule)
                    .background(colors.panelRaised)
                    .hairlineBorder(capsule)
                    .padding(horizontal = 14.dp, vertical = 9.dp)
                    .widthIn(max = pillContentMaxWidth),
                horizontalAlignment = Alignment.End,
                verticalArrangement = Arrangement.spacedBy(1.dp),
            ) {
                Text(
                    titleProvider(effectiveIndex),
                    style = AppType.body.copy(
                        fontFamily = SerifFamily,
                        fontWeight = FontWeight.Bold,
                        fontSize = 15.sp,
                        lineHeight = 19.sp,
                    ),
                    color = colors.label,
                    textAlign = TextAlign.End,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
                Text(
                    referenceProvider(effectiveIndex),
                    style = AppType.caption.copy(fontWeight = FontWeight.Medium),
                    color = colors.secondaryLabel,
                    textAlign = TextAlign.End,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
            }
        }
        Box(
            Modifier
                .align(Alignment.TopEnd)
                .offset { IntOffset(-thumbTrailingPad.roundToPx(), thumbY.toInt()) }
                .size(thumbSize)
                .graphicsLayer {
                    scaleX = thumbScale
                    scaleY = thumbScale
                    alpha = thumbAlpha
                }
                .softShadow(CircleShape, 4.dp)
                .clip(CircleShape)
                .background(colors.panelRaised)
                .hairlineBorder(CircleShape)
                .clearAndSetSemantics { }
                .pointerInput(verseCount) {
                    awaitEachGesture {
                        val down = awaitFirstDown(requireUnconsumed = false)
                        down.consume()
                        val start = currentThumbY.toDouble()
                        var translation = 0f
                        dragFraction = ScrubberMath.fractionForDrag(start, 0.0, inset, currentTravel).toFloat()
                        isDragging = true
                        val update = {
                            dragFraction = ScrubberMath
                                .fractionForDrag(start, translation.toDouble(), inset, currentTravel)
                                .toFloat()
                            val i = ScrubberMath.index(dragFraction.toDouble(), verseCount)
                            if (i != lastDragIndex) {
                                currentOnScrub(i)
                                HapticEngine.light()
                                lastDragIndex = i
                            }
                        }
                        update()
                        drag(down.id) { change ->
                            translation += change.positionChange().y
                            change.consume()
                            update()
                        }
                        isDragging = false
                        lastDragIndex = -1
                        flash()
                    }
                },
            contentAlignment = Alignment.Center,
        ) {
            Icon(R.drawable.ic_caret_up_down, size = 16.dp, tint = colors.accent)
        }
    }
}
