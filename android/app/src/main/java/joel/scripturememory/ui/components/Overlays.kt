package joel.scripturememory.ui.components

import android.view.WindowManager
import androidx.activity.compose.BackHandler
import androidx.compose.animation.core.Animatable
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.Orientation
import androidx.compose.foundation.gestures.draggable
import androidx.compose.foundation.gestures.rememberDraggableState
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.clickable
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
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.DpOffset
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.IntRect
import androidx.compose.ui.unit.IntSize
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import androidx.compose.ui.window.DialogWindowProvider
import androidx.compose.ui.window.Popup
import androidx.compose.ui.window.PopupPositionProvider
import androidx.compose.ui.window.PopupProperties
import kotlinx.coroutines.launch
import joel.scripturememory.ui.theme.AppMotion
import joel.scripturememory.ui.theme.AppTheme
import joel.scripturememory.ui.theme.AppType

@Composable
private fun FullWindowDialog(onBack: () -> Unit, content: @Composable () -> Unit) {
    Dialog(
        onDismissRequest = onBack,
        properties = DialogProperties(
            usePlatformDefaultWidth = false,
            decorFitsSystemWindows = false,
            dismissOnBackPress = true,
            dismissOnClickOutside = false,
        ),
    ) {
        val window = (LocalView.current.parent as? DialogWindowProvider)?.window
        LaunchedEffect(window) {
            window?.clearFlags(WindowManager.LayoutParams.FLAG_DIM_BEHIND)
            window?.setWindowAnimations(0)
        }
        content()
    }
}

class SheetController internal constructor(val dismiss: () -> Unit)

@Composable
fun AppSheet(
    onDismiss: () -> Unit,
    fullHeight: Boolean = false,
    content: @Composable ColumnScope.(SheetController) -> Unit,
) {
    val colors = AppTheme.colors
    val scope = rememberCoroutineScope()
    val offset = remember { Animatable(1f) }
    var closing by remember { mutableStateOf(false) }

    fun close() {
        if (closing) return
        closing = true
        scope.launch {
            offset.animateTo(1f, AppMotion.snappy(240))
            onDismiss()
        }
    }

    LaunchedEffect(Unit) { offset.animateTo(0f, AppMotion.snappy(340)) }

    FullWindowDialog(onBack = ::close) {
        BoxWithConstraints(Modifier.fillMaxSize()) {
            val height = with(LocalDensity.current) { maxHeight.toPx() }
            Box(
                Modifier
                    .fillMaxSize()
                    .graphicsLayer { alpha = 1f - offset.value }
                    .background(colors.scrim)
                    .clickable(
                        interactionSource = remember { MutableInteractionSource() },
                        indication = null,
                        onClick = ::close,
                    ),
            )
            Column(
                Modifier
                    .align(Alignment.BottomCenter)
                    .widthIn(max = 640.dp)
                    .fillMaxWidth()
                    .statusBarsPadding()
                    .padding(top = 12.dp)
                    .then(if (fullHeight) Modifier.fillMaxHeight() else Modifier)
                    .graphicsLayer { translationY = height * offset.value }
                    .clip(RoundedCornerShape(topStart = 28.dp, topEnd = 28.dp))
                    .background(colors.background)
                    .imePadding(),
            ) {
                Box(
                    Modifier
                        .fillMaxWidth()
                        .height(24.dp)
                        .draggable(
                            orientation = Orientation.Vertical,
                            state = rememberDraggableState { delta ->
                                scope.launch {
                                    offset.snapTo((offset.value + delta / height).coerceIn(0f, 1f))
                                }
                            },
                            onDragStopped = { velocity ->
                                if (offset.value > 0.18f || velocity > 1400f) close()
                                else scope.launch { offset.animateTo(0f, AppMotion.control()) }
                            },
                        ),
                    contentAlignment = Alignment.Center,
                ) {
                    Box(
                        Modifier
                            .size(width = 36.dp, height = 4.dp)
                            .clip(RoundedCornerShape(2.dp))
                            .background(colors.tertiaryLabel),
                    )
                }
                Column(Modifier.then(if (fullHeight) Modifier.weight(1f) else Modifier).navigationBarsPadding()) {
                    content(SheetController(::close))
                }
            }
        }
    }
}

@Composable
fun SheetHeader(
    title: String,
    modifier: Modifier = Modifier,
    leading: (@Composable () -> Unit)? = null,
    trailing: (@Composable () -> Unit)? = null,
) {
    Box(modifier.fillMaxWidth().height(48.dp).padding(horizontal = 16.dp)) {
        Box(Modifier.align(Alignment.CenterStart)) { leading?.invoke() }
        Text(title, Modifier.align(Alignment.Center), style = AppType.headline)
        Box(Modifier.align(Alignment.CenterEnd)) { trailing?.invoke() }
    }
}

data class AlertAction(
    val title: String,
    val isDestructive: Boolean = false,
    val isCancel: Boolean = false,
    val onClick: () -> Unit = {},
)

@Composable
fun AppAlert(
    title: String,
    message: String? = null,
    actions: List<AlertAction>,
    onDismiss: () -> Unit,
) {
    val colors = AppTheme.colors
    val scope = rememberCoroutineScope()
    val progress = remember { Animatable(0f) }

    fun close(then: () -> Unit) {
        scope.launch {
            progress.animateTo(0f, AppMotion.snappy(140))
            onDismiss()
            then()
        }
    }

    LaunchedEffect(Unit) { progress.animateTo(1f, AppMotion.snappy(220)) }

    FullWindowDialog(onBack = { close {} }) {
        Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
            Box(
                Modifier
                    .matchParentSize()
                    .graphicsLayer { alpha = progress.value }
                    .background(colors.scrim),
            )
            Column(
                Modifier
                    .padding(horizontal = 28.dp)
                    .widthIn(max = 340.dp)
                    .fillMaxWidth()
                    .graphicsLayer {
                        alpha = progress.value
                        val s = 0.94f + 0.06f * progress.value
                        scaleX = s
                        scaleY = s
                    }
                    .clip(RoundedCornerShape(28.dp))
                    .background(colors.panelRaised)
                    .padding(top = 22.dp, start = 22.dp, end = 22.dp, bottom = 14.dp),
            ) {
                Text(title, style = AppType.title3, color = colors.label)
                if (message != null) {
                    Text(message, Modifier.padding(top = 8.dp), style = AppType.callout, color = colors.secondaryLabel)
                }
                Row(
                    Modifier.fillMaxWidth().padding(top = 14.dp),
                    horizontalArrangement = Arrangement.spacedBy(8.dp, Alignment.End),
                ) {
                    actions.forEach { action ->
                        TextButton(
                            title = action.title,
                            tint = when {
                                action.isDestructive -> colors.red
                                action.isCancel -> colors.secondaryLabel
                                else -> colors.accent
                            },
                            style = AppType.headline,
                            onClick = { close(action.onClick) },
                        )
                    }
                }
            }
        }
    }
}

data class MenuAction(
    val title: String,
    val icon: Int? = null,
    val isDestructive: Boolean = false,
    val onClick: () -> Unit,
)

private class BelowAnchor(private val margin: Int) : PopupPositionProvider {
    override fun calculatePosition(
        anchorBounds: IntRect,
        windowSize: IntSize,
        layoutDirection: LayoutDirection,
        popupContentSize: IntSize,
    ): IntOffset {
        val x = (anchorBounds.right - popupContentSize.width).coerceIn(margin, windowSize.width - popupContentSize.width - margin)
        val below = anchorBounds.bottom + margin
        val y = if (below + popupContentSize.height <= windowSize.height - margin) below
        else (anchorBounds.top - popupContentSize.height - margin).coerceAtLeast(margin)
        return IntOffset(x, y)
    }
}

@Composable
fun AppMenu(actions: List<MenuAction>, onDismiss: () -> Unit) {
    val colors = AppTheme.colors
    val progress = remember { Animatable(0f) }
    val margin = with(LocalDensity.current) { 8.dp.roundToPx() }
    LaunchedEffect(Unit) { progress.animateTo(1f, AppMotion.snappy(180)) }
    Popup(
        popupPositionProvider = remember(margin) { BelowAnchor(margin) },
        onDismissRequest = onDismiss,
        properties = PopupProperties(focusable = true),
    ) {
        Column(
            Modifier
                .width(236.dp)
                .graphicsLayer {
                    alpha = progress.value
                    val s = 0.92f + 0.08f * progress.value
                    scaleX = s
                    scaleY = s
                }
                .softShadow(RoundedCornerShape(20.dp), 16.dp)
                .clip(RoundedCornerShape(20.dp))
                .background(colors.panelRaised)
                .padding(vertical = 6.dp),
        ) {
            actions.forEach { action ->
                Row(
                    Modifier
                        .fillMaxWidth()
                        .dimOnPress {
                            onDismiss()
                            action.onClick()
                        }
                        .heightIn(min = 46.dp)
                        .padding(horizontal = 16.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(12.dp),
                ) {
                    val tint = if (action.isDestructive) colors.red else colors.label
                    Text(action.title, Modifier.weight(1f), style = AppType.body, color = tint)
                    if (action.icon != null) Icon(action.icon, size = 20.dp, tint = tint)
                }
            }
        }
    }
}
