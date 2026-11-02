package joel.scripturememory.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.snapping.SnapPosition
import androidx.compose.foundation.gestures.snapping.rememberSnapFlingBehavior
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyListState
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.derivedStateOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.snapshotFlow
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clipToBounds
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.semantics.CustomAccessibilityAction
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.customActions
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.unit.dp
import joel.scripturememory.system.HapticEngine
import joel.scripturememory.ui.theme.AppTheme
import joel.scripturememory.ui.theme.AppType
import kotlin.math.abs
import kotlin.math.min
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.drop
import kotlinx.coroutines.launch

private val WheelRowHeight = 44.dp
private const val WheelVisibleRows = 5
private const val LoopRepeats = 2_000

private fun LazyListState.centeredIndex(): Int? {
    val layout = layoutInfo
    val middle = (layout.viewportStartOffset + layout.viewportEndOffset) / 2
    return layout.visibleItemsInfo.minByOrNull { abs(it.offset + it.size / 2 - middle) }?.index
}

@Composable
fun WheelColumn(
    labels: List<String>,
    selected: Int,
    label: String,
    loops: Boolean,
    onSelect: (Int) -> Unit,
    modifier: Modifier = Modifier,
) {
    val colors = AppTheme.colors
    val count = if (loops) labels.size * LoopRepeats else labels.size
    val origin = if (loops) labels.size * (LoopRepeats / 2) else 0
    val state = rememberLazyListState(initialFirstVisibleItemIndex = origin + selected)
    val fling = rememberSnapFlingBehavior(state, SnapPosition.Center)
    val scope = rememberCoroutineScope()
    val latestSelect by rememberUpdatedState(onSelect)
    val centered by remember { derivedStateOf { state.centeredIndex() } }
    val centeredValue = (centered ?: (origin + selected)) % labels.size

    LaunchedEffect(state) {
        snapshotFlow { state.centeredIndex() }
            .distinctUntilChanged()
            .drop(1)
            .collect { HapticEngine.soft() }
    }
    LaunchedEffect(state) {
        snapshotFlow { state.isScrollInProgress to state.centeredIndex() }
            .distinctUntilChanged()
            .collect { (scrolling, index) ->
                if (!scrolling && index != null) latestSelect(index % labels.size)
            }
    }

    fun nudge(delta: Int) {
        val target = (centered ?: (origin + selected)) + delta
        if (target in 0 until count) scope.launch { state.animateScrollToItem(target) }
    }

    LazyColumn(
        state = state,
        flingBehavior = fling,
        modifier = modifier
            .height(WheelRowHeight * WheelVisibleRows)
            .clipToBounds()
            .clearAndSetSemantics {
                contentDescription = label
                stateDescription = labels[centeredValue]
                customActions = listOf(
                    CustomAccessibilityAction("Increase") {
                        nudge(1)
                        true
                    },
                    CustomAccessibilityAction("Decrease") {
                        nudge(-1)
                        true
                    },
                )
            },
        contentPadding = PaddingValues(vertical = WheelRowHeight * (WheelVisibleRows / 2)),
    ) {
        items(count) { index ->
            val value = index % labels.size
            Box(
                Modifier
                    .fillMaxWidth()
                    .height(WheelRowHeight)
                    .graphicsLayer {
                        val info = state.layoutInfo
                        val middle = (info.viewportStartOffset + info.viewportEndOffset) / 2f
                        val item = info.visibleItemsInfo.firstOrNull { it.index == index }
                        val distance = item?.let { abs(it.offset + it.size / 2f - middle) / it.size } ?: 2f
                        val t = min(distance / (WheelVisibleRows / 2f + 0.5f), 1f)
                        alpha = 1f - t * 0.8f
                        val s = 1f - t * 0.16f
                        scaleX = s
                        scaleY = s
                        rotationX = t * 42f * if ((item?.offset ?: 0) + (item?.size ?: 0) / 2f < middle) 1f else -1f
                        cameraDistance = 14f * density
                    },
                contentAlignment = Alignment.Center,
            ) {
                Text(labels[value], style = AppType.title2.copy(fontFeatureSettings = "tnum"), color = colors.label, maxLines = 1)
            }
        }
    }
}

@Composable
fun TimeWheelPicker(
    hour: Int,
    minute: Int,
    is24Hour: Boolean,
    onChange: (hour: Int, minute: Int) -> Unit,
    modifier: Modifier = Modifier,
) {
    val colors = AppTheme.colors
    val hourNow by rememberUpdatedState(hour)
    val minuteNow by rememberUpdatedState(minute)
    val hourLabels = remember(is24Hour) {
        if (is24Hour) (0..23).map { "%02d".format(it) } else (1..12).map(Int::toString)
    }
    val minuteLabels = remember { (0..59).map { "%02d".format(it) } }

    Box(modifier.fillMaxWidth(), contentAlignment = Alignment.Center) {
        Box(
            Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp)
                .height(WheelRowHeight)
                .background(colors.fill, RoundedCornerShape(12.dp)),
        )
        Row(
            Modifier.padding(horizontal = 32.dp),
            horizontalArrangement = Arrangement.spacedBy(8.dp, Alignment.CenterHorizontally),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            WheelColumn(
                labels = hourLabels,
                selected = if (is24Hour) hour else (hour + 11) % 12,
                label = "Hour",
                loops = true,
                onSelect = { index ->
                    val next = if (is24Hour) index else (index + 1) % 12 + if (hourNow >= 12) 12 else 0
                    if (next != hourNow) onChange(next, minuteNow)
                },
                modifier = Modifier.width(72.dp),
            )
            WheelColumn(
                labels = minuteLabels,
                selected = minute,
                label = "Minute",
                loops = true,
                onSelect = { if (it != minuteNow) onChange(hourNow, it) },
                modifier = Modifier.width(72.dp),
            )
            if (!is24Hour) {
                val symbols = remember { java.text.DateFormatSymbols.getInstance().amPmStrings.toList() }
                WheelColumn(
                    labels = symbols,
                    selected = if (hour >= 12) 1 else 0,
                    label = "AM or PM",
                    loops = false,
                    onSelect = { index ->
                        val next = hourNow % 12 + if (index == 1) 12 else 0
                        if (next != hourNow) onChange(next, minuteNow)
                    },
                    modifier = Modifier.width(72.dp),
                )
            }
        }
    }
}
