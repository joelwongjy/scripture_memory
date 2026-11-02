package joel.scripturememory.ui.components

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.detectVerticalDragGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import joel.scripturememory.R
import joel.scripturememory.model.LearningStore
import joel.scripturememory.model.Verse
import joel.scripturememory.system.HapticEngine
import joel.scripturememory.ui.theme.AppLayout
import joel.scripturememory.ui.theme.AppMotion
import joel.scripturememory.ui.theme.AppTheme
import joel.scripturememory.ui.theme.AppType
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import java.util.UUID

data class UndoToastState(
    val message: String,
    val id: UUID = UUID.randomUUID(),
    val undo: () -> Unit,
) {
    companion object {
        fun markedComplete(verse: Verse, learning: LearningStore) =
            UndoToastState("Marked as complete") { learning.unmarkLearnt(verse) }
    }
}

private const val undoToastMillis = 3000L
private val dismissDistance = 24.dp

@Composable
fun UndoToast(message: String, onUndo: () -> Unit, onDismiss: () -> Unit, modifier: Modifier = Modifier) {
    val colors = AppTheme.colors
    val scope = rememberCoroutineScope()
    val drag = remember { Animatable(0f) }
    val threshold = with(LocalDensity.current) { dismissDistance.toPx() }
    val shape = RoundedCornerShape(percent = 50)
    var total by remember { mutableStateOf(0f) }
    Row(
        modifier
            .fillMaxWidth()
            .graphicsLayer { translationY = drag.value }
            .softShadow(shape, 12.dp)
            .clip(shape)
            .background(colors.panelRaised)
            .hairlineBorder(shape)
            .pointerInput(Unit) {
                detectVerticalDragGestures(
                    onDragStart = { total = 0f },
                    onVerticalDrag = { _, amount ->
                        total += amount
                        scope.launch { drag.snapTo(if (total > 0) total else total / 4) }
                    },
                    onDragEnd = {
                        if (total > threshold) {
                            HapticEngine.light()
                            onDismiss()
                        } else {
                            scope.launch { drag.animateTo(0f, AppMotion.control()) }
                        }
                    },
                )
            }
            .padding(start = 14.dp, end = 2.dp, top = 6.dp, bottom = 6.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Icon(R.drawable.ic_check_circle_fill, size = 18.dp, tint = colors.green)
        Text(
            message,
            Modifier.weight(1f),
            style = AppType.subheadline.copy(fontWeight = FontWeight.Medium),
            maxLines = 1,
        )
        Box(Modifier.dimOnPress(onClick = onUndo).padding(horizontal = 12.dp, vertical = 8.dp)) {
            Text(
                "Undo",
                style = AppType.subheadline.copy(fontWeight = FontWeight.SemiBold),
                color = colors.accent,
            )
        }
    }
}

@Composable
fun BoxScope.UndoToastHost(state: UndoToastState?, onChange: (UndoToastState?) -> Unit) {
    LaunchedEffect(state?.id) {
        if (state != null) {
            delay(undoToastMillis)
            onChange(null)
        }
    }
    var shown by remember { mutableStateOf(state) }
    if (state != null) shown = state
    AnimatedVisibility(
        visible = state != null,
        modifier = Modifier
            .align(Alignment.BottomCenter)
            .padding(horizontal = AppLayout.screenMargin)
            .padding(bottom = 10.dp),
        enter = slideInVertically(AppMotion.content()) { it } + fadeIn(AppMotion.content()),
        exit = slideOutVertically(AppMotion.content()) { it } + fadeOut(AppMotion.content()),
    ) {
        val current = shown
        if (current != null) {
            UndoToast(
                message = current.message,
                onUndo = {
                    current.undo()
                    HapticEngine.light()
                    onChange(null)
                },
                onDismiss = { onChange(null) },
            )
        }
    }
}
