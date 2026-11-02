package joel.scripturememory.ui.packs

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.foundation.gestures.drag
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.ScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
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
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.RectangleShape
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.input.pointer.positionChange
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.layout.positionInWindow
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.zIndex
import joel.scripturememory.R
import joel.scripturememory.model.AnalyticsEvent
import joel.scripturememory.model.AnalyticsScreen
import joel.scripturememory.model.Pack
import joel.scripturememory.model.PackPreferencesStore
import joel.scripturememory.system.Analytics
import joel.scripturememory.system.HapticEngine
import joel.scripturememory.ui.components.AlertAction
import joel.scripturememory.ui.components.AppAlert
import joel.scripturememory.ui.components.AppSheet
import joel.scripturememory.ui.components.Divider
import joel.scripturememory.ui.components.Icon
import joel.scripturememory.ui.components.PackRowLabel
import joel.scripturememory.ui.components.SheetHeader
import joel.scripturememory.ui.components.Text
import joel.scripturememory.ui.components.TextButton
import joel.scripturememory.ui.components.TrackScreen
import joel.scripturememory.ui.components.dimOnPress
import joel.scripturememory.ui.components.softShadow
import joel.scripturememory.ui.theme.AppLayout
import joel.scripturememory.ui.theme.AppMotion
import joel.scripturememory.ui.theme.AppTheme
import joel.scripturememory.ui.theme.AppType
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
private class PackReorder(private val scroll: ScrollState, private val scope: CoroutineScope, private val zone: Float) {
    var dragging by mutableStateOf<String?>(null)
    var offset by mutableFloatStateOf(0f)
    var rowHeight by mutableFloatStateOf(1f)
    var viewportTop = 0f
    var viewportBottom = 0f
    private var pointerY = 0f
    private var autoScroll: Job? = null

    fun target(from: Int, count: Int): Int =
        (from + (offset / rowHeight).roundToInt()).coerceIn(0, count - 1)

    fun shift(row: Int, from: Int, count: Int): Float {
        if (from < 0 || row == from) return 0f
        val to = target(from, count)
        return when {
            row in (from + 1)..to -> -rowHeight
            row in to until from -> rowHeight
            else -> 0f
        }
    }

    fun begin(name: String, windowY: Float) {
        dragging = name
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

    fun move(delta: Float) {
        offset += delta
        pointerY += delta
    }

    fun end() {
        autoScroll?.cancel()
        dragging = null
        offset = 0f
    }
}

@Composable
fun PackOrganizerSheet(allPacks: List<Pack>, onDismiss: () -> Unit) {
    val store = PackPreferencesStore.shared
    val colors = AppTheme.colors
    var showResetConfirm by remember { mutableStateOf(false) }
    val scroll = rememberScrollState()
    val scope = rememberCoroutineScope()
    val zone = with(LocalDensity.current) { autoScrollZone.toPx() }
    val reorder = remember { PackReorder(scroll, scope, zone) }

    TrackScreen(AnalyticsScreen.organizePacks)

    val arranged = store.arranged(allPacks)
    val current by rememberUpdatedState(arranged)

    AppSheet(onDismiss = onDismiss, fullHeight = true) { sheet ->
        SheetHeader(
            "Edit Packs",
            leading = {
                TextButton(
                    "Reset",
                    enabled = store.hasCustomization,
                    style = AppType.body,
                    onClick = { showResetConfirm = true },
                )
            },
            trailing = {
                TextButton(
                    "Done",
                    style = AppType.body.copy(fontWeight = FontWeight.SemiBold),
                    onClick = sheet.dismiss,
                )
            },
        )
        Column(
            Modifier
                .weight(1f)
                .fillMaxWidth()
                .onGloballyPositioned {
                    reorder.viewportTop = it.positionInWindow().y
                    reorder.viewportBottom = reorder.viewportTop + it.size.height
                }
                .verticalScroll(scroll, enabled = reorder.dragging == null)
                .padding(horizontal = AppLayout.screenMargin)
                .padding(bottom = 24.dp),
        ) {
            Text(
                "Drag to reorder. Hidden packs don't appear in Packs, Daily Review, Quiz or Search.",
                Modifier.padding(horizontal = AppLayout.panelPadding, vertical = 8.dp),
                style = AppType.footnote,
                color = colors.secondaryLabel,
            )
            Column(Modifier.fillMaxWidth().background(colors.panel, rowPanelShape)) {
                val from = arranged.indexOfFirst { it.name == reorder.dragging }
                arranged.forEachIndexed { row, pack ->
                    key(pack.name) {
                        val isDragged = reorder.dragging == pack.name
                        val settling = remember { Animatable(0f) }
                        val shift by animateFloatAsState(
                            reorder.shift(row, from, arranged.size),
                            AppMotion.control(),
                            label = "rowShift",
                        )
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
                                        row == 0 -> RoundedCornerShape(topStart = AppLayout.cornerRadius, topEnd = AppLayout.cornerRadius)
                                        row == arranged.lastIndex -> RoundedCornerShape(bottomStart = AppLayout.cornerRadius, bottomEnd = AppLayout.cornerRadius)
                                        else -> RectangleShape
                                    },
                                )
                                .onSizeChanged { reorder.rowHeight = it.height.toFloat() },
                        ) {
                            OrganizerRow(
                                pack = pack,
                                isHidden = store.isHidden(pack.name),
                                onToggle = {
                                    val hidden = store.isHidden(pack.name)
                                    store.setHidden(pack.name, !hidden)
                                    Analytics.log(AnalyticsEvent.PackVisibilityChanged(!hidden))
                                    HapticEngine.light()
                                },
                                onDragStart = { reorder.begin(pack.name, it) },
                                onDrag = reorder::move,
                                onDragEnd = {
                                    val origin = current.indexOfFirst { it.name == pack.name }
                                    val to = reorder.target(origin, current.size)
                                    val remainder = reorder.offset - (to - origin) * reorder.rowHeight
                                    reorder.end()
                                    if (to != origin) {
                                        store.move(current, setOf(origin), if (to > origin) to + 1 else to)
                                        Analytics.log(AnalyticsEvent.PacksReordered)
                                    }
                                    scope.launch {
                                        settling.snapTo(remainder)
                                        settling.animateTo(0f, AppMotion.control())
                                    }
                                },
                            )
                            if (row < arranged.lastIndex) Divider(Modifier.padding(start = AppLayout.panelPadding))
                        }
                    }
                }
            }
        }
    }

    if (showResetConfirm) {
        AppAlert(
            title = "Reset Pack Order?",
            message = "Restores the original order and shows all packs.",
            actions = listOf(
                AlertAction("Cancel", isCancel = true),
                AlertAction("Reset", isDestructive = true) {
                    store.reset()
                    HapticEngine.light()
                },
            ),
            onDismiss = { showResetConfirm = false },
        )
    }
}

@Composable
private fun OrganizerRow(
    pack: Pack,
    isHidden: Boolean,
    onToggle: () -> Unit,
    onDragStart: (Float) -> Unit,
    onDrag: (Float) -> Unit,
    onDragEnd: () -> Unit,
) {
    val colors = AppTheme.colors
    var handleTop by remember { mutableFloatStateOf(0f) }
    val start by rememberUpdatedState(onDragStart)
    val move by rememberUpdatedState(onDrag)
    val end by rememberUpdatedState(onDragEnd)
    Row(
        Modifier
            .fillMaxWidth()
            .alpha(if (isHidden) 0.45f else 1f)
            .padding(start = AppLayout.panelPadding, end = 6.dp, top = 8.dp, bottom = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        PackRowLabel(pack, Modifier.weight(1f).alpha(if (isHidden) 0.5f else 1f))
        Box(
            Modifier
                .size(width = 44.dp, height = 30.dp)
                .semantics { contentDescription = if (isHidden) "Show ${pack.name}" else "Hide ${pack.name}" }
                .dimOnPress(onClick = onToggle),
            contentAlignment = Alignment.Center,
        ) {
            Icon(
                if (isHidden) R.drawable.ic_eye_slash else R.drawable.ic_eye,
                size = 20.dp,
                tint = if (isHidden) colors.secondaryLabel else colors.accent,
            )
        }
        Box(
            Modifier
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
            Icon(R.drawable.ic_list, size = 20.dp, tint = colors.tertiaryLabel)
        }
    }
}
