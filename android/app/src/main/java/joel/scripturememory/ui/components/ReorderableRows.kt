package joel.scripturememory.ui.components

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.ScrollState
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.foundation.gestures.drag
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.Stable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.key
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.runtime.withFrameNanos
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.RectangleShape
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.input.pointer.positionChange
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.layout.positionInWindow
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.unit.dp
import androidx.compose.ui.zIndex
import joel.scripturememory.R
import joel.scripturememory.system.HapticEngine
import joel.scripturememory.ui.theme.AppLayout
import joel.scripturememory.ui.theme.AppMotion
import joel.scripturememory.ui.theme.AppTheme
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlin.math.roundToInt

private val rowPanelShape = RoundedCornerShape(AppLayout.cornerRadius)
private val liftedRowShape = RoundedCornerShape(12.dp)
private val autoScrollZone = 72.dp
private const val autoScrollMaxPerFrame = 18f

@Stable
class RowReorder internal constructor(private val scroll: ScrollState, private val scope: CoroutineScope, private val zone: Float) {
    var dragging by mutableStateOf<String?>(null)
        private set
    internal var offset by mutableFloatStateOf(0f)
    internal var rowHeight by mutableFloatStateOf(1f)
    internal var viewportTop = 0f
    internal var viewportBottom = 0f
    private var pointerY = 0f
    private var autoScroll: Job? = null

    val isDragging: Boolean get() = dragging != null

    internal fun target(from: Int, count: Int): Int =
        (from + (offset / rowHeight).roundToInt()).coerceIn(0, count - 1)

    internal fun shift(row: Int, from: Int, count: Int): Float {
        if (from < 0 || row == from) return 0f
        val to = target(from, count)
        return when {
            row in (from + 1)..to -> -rowHeight
            row in to until from -> rowHeight
            else -> 0f
        }
    }

    internal fun begin(key: String, windowY: Float) {
        dragging = key
        offset = 0f
        pointerY = windowY
        HapticEngine.light()
        autoScroll = scope.launch {
            while (isActive) {
                withFrameNanos {}
                val top = pointerY - viewportTop
                val bottom = viewportBottom - pointerY
                val speed = when {
                    top < zone -> -(1 - (top / zone).coerceAtLeast(0f)) * autoScrollMaxPerFrame
                    bottom < zone -> (1 - (bottom / zone).coerceAtLeast(0f)) * autoScrollMaxPerFrame
                    else -> 0f
                }
                if (speed != 0f) {
                    val before = scroll.value
                    scroll.scrollTo(before + speed.roundToInt())
                    offset += scroll.value - before
                }
            }
        }
    }

    internal fun move(delta: Float) {
        offset += delta
        pointerY += delta
    }

    internal fun end() {
        autoScroll?.cancel()
        dragging = null
        offset = 0f
    }
}

fun Modifier.reorderViewport(reorder: RowReorder): Modifier = onGloballyPositioned {
    reorder.viewportTop = it.positionInWindow().y
    reorder.viewportBottom = reorder.viewportTop + it.size.height
}

@Composable
fun rememberRowReorder(scroll: ScrollState): RowReorder {
    val scope = rememberCoroutineScope()
    val zone = with(LocalDensity.current) { autoScrollZone.toPx() }
    return remember(scroll) { RowReorder(scroll, scope, zone) }
}

class ReorderHandle internal constructor(
    internal val onStart: (Float) -> Unit,
    internal val onDrag: (Float) -> Unit,
    internal val onEnd: () -> Unit,
)

@Composable
fun ReorderableRows(
    keys: List<String>,
    reorder: RowReorder,
    onMove: (from: Int, to: Int) -> Unit,
    modifier: Modifier = Modifier,
    row: @Composable (index: Int, handle: ReorderHandle) -> Unit,
) {
    val colors = AppTheme.colors
    val scope = rememberCoroutineScope()
    val current by rememberUpdatedState(keys)
    Column(modifier.fillMaxWidth().background(colors.panel, rowPanelShape)) {
        val from = keys.indexOf(reorder.dragging)
        keys.forEachIndexed { index, rowKey ->
            key(rowKey) {
                val isDragged = reorder.dragging == rowKey
                val settling = remember { Animatable(0f) }
                val shift by animateFloatAsState(reorder.shift(index, from, keys.size), AppMotion.control(), label = "rowShift")
                val lifted by animateFloatAsState(if (isDragged) 1f else 0f, AppMotion.control(), label = "rowLift")
                Column(
                    Modifier
                        .zIndex(if (isDragged) 1f else 0f)
                        .then(if (lifted > 0f) Modifier.softShadow(liftedRowShape, 12.dp * lifted) else Modifier)
                        .graphicsLayer {
                            translationY = (if (isDragged) reorder.offset else shift) + settling.value
                            val s = 1f + 0.02f * lifted
                            scaleX = s
                            scaleY = s
                        }
                        .then(if (lifted > 0f) Modifier.clip(liftedRowShape) else Modifier)
                        .background(
                            colors.panel,
                            when {
                                isDragged -> liftedRowShape
                                keys.size == 1 -> rowPanelShape
                                index == 0 -> RoundedCornerShape(topStart = AppLayout.cornerRadius, topEnd = AppLayout.cornerRadius)
                                index == keys.lastIndex -> RoundedCornerShape(bottomStart = AppLayout.cornerRadius, bottomEnd = AppLayout.cornerRadius)
                                else -> RectangleShape
                            },
                        )
                        .onSizeChanged { reorder.rowHeight = it.height.toFloat() },
                ) {
                    val handle = ReorderHandle(
                        onStart = { reorder.begin(rowKey, it) },
                        onDrag = reorder::move,
                        onEnd = {
                            val origin = current.indexOf(rowKey)
                            val to = reorder.target(origin, current.size)
                            val remainder = reorder.offset - (to - origin) * reorder.rowHeight
                            reorder.end()
                            if (to != origin) onMove(origin, if (to > origin) to + 1 else to)
                            scope.launch {
                                settling.snapTo(remainder)
                                settling.animateTo(0f, AppMotion.control())
                            }
                        },
                    )
                    row(index, handle)
                    if (index < keys.lastIndex) Divider(Modifier.padding(start = AppLayout.panelPadding))
                }
            }
        }
    }
}

@Composable
fun ReorderGrip(handle: ReorderHandle, modifier: Modifier = Modifier) {
    var handleTop by remember { mutableFloatStateOf(0f) }
    val start by rememberUpdatedState(handle.onStart)
    val move by rememberUpdatedState(handle.onDrag)
    val end by rememberUpdatedState(handle.onEnd)
    Box(
        modifier
            .width(40.dp)
            .height(44.dp)
            .onGloballyPositioned { handleTop = it.positionInWindow().y }
            .pointerInput(Unit) {
                awaitEachGesture {
                    val down = awaitFirstDown(requireUnconsumed = false)
                    down.consume()
                    start(handleTop + down.position.y)
                    drag(down.id) { change ->
                        move(change.positionChange().y)
                        change.consume()
                    }
                    end()
                }
            },
        contentAlignment = Alignment.Center,
    ) {
        Icon(R.drawable.ic_list, size = 20.dp, tint = AppTheme.colors.tertiaryLabel)
    }
}
