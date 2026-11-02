package joel.scripturememory.ui.components

import androidx.activity.compose.BackHandler
import androidx.activity.compose.PredictiveBackHandler
import androidx.compose.animation.core.Animatable
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.Stable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.key
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.SaveableStateHolder
import androidx.compose.runtime.saveable.rememberSaveableStateHolder
import androidx.compose.runtime.setValue
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalDensity
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.launch
import joel.scripturememory.ui.theme.AppMotion
import joel.scripturememory.ui.theme.AppTheme

@Stable
class StackEntry(val key: String, val content: @Composable () -> Unit)

@Stable
class Navigator {
    internal val entries = mutableStateListOf<StackEntry>()
    internal var pendingPop by mutableIntStateOf(0)
    internal var handledPop = 0

    val depth: Int get() = entries.size
    val canPop: Boolean get() = entries.isNotEmpty()

    fun push(key: String, content: @Composable () -> Unit) {
        if (entries.lastOrNull()?.key == key) return
        entries.add(StackEntry(key, content))
    }

    fun pop() {
        if (entries.isNotEmpty()) pendingPop += 1
    }

    fun popToRoot() {
        entries.clear()
    }

    fun popToRootAnimated() {
        while (entries.size > 1) entries.removeAt(0)
        pop()
    }
}

val LocalNavigator = staticCompositionLocalOf<Navigator> { error("No Navigator") }

@Composable
fun StackHost(
    navigator: Navigator,
    modifier: Modifier = Modifier,
    backEnabled: Boolean = true,
    holder: SaveableStateHolder = rememberSaveableStateHolder(),
    root: @Composable () -> Unit,
) {
    val scope = rememberCoroutineScope()
    val progress = remember { Animatable(0f) }
    var settledDepth by remember { mutableIntStateOf(navigator.entries.size) }
    val depth = navigator.entries.size

    LaunchedEffect(depth) {
        if (depth > settledDepth) {
            progress.snapTo(1f)
            settledDepth = depth
            progress.animateTo(0f, AppMotion.snappy(320))
        } else {
            settledDepth = depth
            progress.snapTo(0f)
        }
    }

    suspend fun finishPop() {
        progress.animateTo(1f, AppMotion.snappy(260))
        if (navigator.entries.isNotEmpty()) navigator.entries.removeAt(navigator.entries.lastIndex)
    }

    LaunchedEffect(navigator.pendingPop) {
        if (navigator.pendingPop > navigator.handledPop) {
            navigator.handledPop = navigator.pendingPop
            finishPop()
        }
    }

    PredictiveBackHandler(enabled = backEnabled && depth > 0) { gesture ->
        try {
            gesture.collect { event -> progress.snapTo(event.progress * 0.6f) }
            finishPop()
        } catch (cancelled: CancellationException) {
            scope.launch { progress.animateTo(0f, AppMotion.control()) }
            throw cancelled
        }
    }

    CompositionLocalProvider(LocalNavigator provides navigator) {
        BoxWithConstraints(modifier.fillMaxSize()) {
            val width = with(LocalDensity.current) { maxWidth.toPx() }
            val top = navigator.entries.lastOrNull()
            val under = if (navigator.entries.size >= 2) navigator.entries[navigator.entries.lastIndex - 1] else null
            val moving = progress.isRunning || progress.value > 0f
            val background = AppTheme.colors.background

            if (top == null || moving) {
                Box(
                    Modifier
                        .fillMaxSize()
                        .graphicsLayer { translationX = -0.28f * width * (1f - progress.value) * if (top == null) 0f else 1f },
                ) {
                    if (under != null) {
                        key(under.key) { holder.SaveableStateProvider(under.key) { under.content() } }
                    } else {
                        holder.SaveableStateProvider("root") { root() }
                    }
                }
            }
            if (top != null) {
                Box(
                    Modifier
                        .fillMaxSize()
                        .graphicsLayer {
                            translationX = width * progress.value
                            shadowElevation = if (progress.value > 0f) 24f else 0f
                        }
                        .background(background),
                ) {
                    key(top.key) { holder.SaveableStateProvider(top.key) { top.content() } }
                }
            }
        }
    }
}

enum class CoverTransition { SlideUp, SlideDownOnly, None }

@Stable
class CoverEntry(
    val key: String,
    val transition: CoverTransition,
    val background: Boolean,
    val content: @Composable (dismiss: () -> Unit) -> Unit,
) {
    internal var closing by mutableStateOf(false)
}

@Stable
class Covers {
    internal val entries = mutableStateListOf<CoverEntry>()

    val isPresenting: Boolean get() = entries.isNotEmpty()

    fun isPresenting(key: String): Boolean = entries.any { it.key == key }

    fun present(
        key: String,
        transition: CoverTransition = CoverTransition.SlideUp,
        background: Boolean = true,
        content: @Composable (dismiss: () -> Unit) -> Unit,
    ) {
        if (entries.any { it.key == key }) return
        entries.add(CoverEntry(key, transition, background, content))
    }

    fun dismiss(key: String? = null) {
        val entry = if (key == null) entries.lastOrNull() else entries.firstOrNull { it.key == key }
        entry?.closing = true
    }
}

val LocalCovers = staticCompositionLocalOf<Covers> { error("No Covers") }

@Composable
fun CoverHost(covers: Covers) {
    covers.entries.toList().forEach { entry ->
        key(entry.key) {
            CoverLayer(entry) { covers.entries.remove(entry) }
        }
    }
}

@Composable
private fun CoverLayer(entry: CoverEntry, onGone: () -> Unit) {
    val offset = remember { Animatable(if (entry.transition == CoverTransition.SlideUp) 1f else 0f) }
    val background = AppTheme.colors.background

    LaunchedEffect(Unit) {
        if (entry.transition == CoverTransition.SlideUp) offset.animateTo(0f, AppMotion.snappy(340))
    }
    LaunchedEffect(entry.closing) {
        if (entry.closing) {
            if (entry.transition != CoverTransition.None) offset.animateTo(1f, AppMotion.snappy(280))
            onGone()
        }
    }
    BoxWithConstraints(Modifier.fillMaxSize()) {
        val height = with(LocalDensity.current) { maxHeight.toPx() }
        Box(
            Modifier
                .fillMaxSize()
                .graphicsLayer { translationY = height * offset.value }
                .then(if (entry.background) Modifier.background(background) else Modifier)
                .pointerInput(Unit) {
                    awaitPointerEventScope {
                        while (true) awaitPointerEvent()
                    }
                },
        ) {
            entry.content { entry.closing = true }
        }
    }
}

@Composable
fun DismissOnBack(enabled: Boolean = true, onBack: () -> Unit) {
    BackHandler(enabled = enabled, onBack = onBack)
}
