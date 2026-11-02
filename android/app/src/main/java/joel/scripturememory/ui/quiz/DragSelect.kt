package joel.scripturememory.ui.quiz

import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.input.pointer.PointerEventPass
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.boundsInRoot
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.layout.positionInRoot

class DragSelectFrames {
    private val frames = HashMap<Int, Rect>()

    fun record(id: Int, frame: Rect) {
        frames[id] = frame
    }

    fun forget(id: Int) {
        frames.remove(id)
    }

    fun row(at: Offset): Int? = frames.entries.firstOrNull { it.value.contains(at) }?.key
}

@Composable
fun Modifier.dragSelectRow(id: Int, store: DragSelectFrames): Modifier {
    DisposableEffect(id, store) {
        onDispose { store.forget(id) }
    }
    return onGloballyPositioned { store.record(id, it.boundsInRoot()) }
}

private const val panStartDistance = 10f

fun Modifier.twoFingerDragSelect(
    onDrag: (Offset, Boolean) -> Unit,
    onEnd: () -> Unit,
): Modifier {
    var origin = Offset.Zero
    return onGloballyPositioned { origin = it.positionInRoot() }.pointerInput(Unit) {
        awaitEachGesture {
            awaitFirstDown(requireUnconsumed = false, pass = PointerEventPass.Initial)
            var anchor: Offset? = null
            var active = false
            var first = true
            while (true) {
                val event = awaitPointerEvent(PointerEventPass.Initial)
                val pressed = event.changes.filter { it.pressed }
                if (pressed.isEmpty()) break
                if (pressed.size < 2) {
                    if (active) event.changes.forEach { it.consume() }
                    anchor = null
                    continue
                }
                val centroid = Offset(
                    pressed.map { it.position.x }.average().toFloat(),
                    pressed.map { it.position.y }.average().toFloat(),
                )
                val start = anchor ?: centroid.also { anchor = it }
                if (!active && (centroid - start).getDistance() > panStartDistance) active = true
                if (active) {
                    event.changes.forEach { it.consume() }
                    onDrag(centroid + origin, first)
                    first = false
                }
            }
            if (active) onEnd()
        }
    }
}
