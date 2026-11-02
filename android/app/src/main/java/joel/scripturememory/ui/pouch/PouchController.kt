package joel.scripturememory.ui.pouch

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.AnimationSpec
import androidx.compose.foundation.gestures.animateScrollBy
import androidx.compose.foundation.lazy.LazyListState
import androidx.compose.runtime.Stable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.runtime.snapshotFlow
import androidx.compose.runtime.withFrameNanos
import joel.scripturememory.model.AnalyticsEvent
import joel.scripturememory.model.PackCloseMethod
import joel.scripturememory.model.Verse
import joel.scripturememory.system.Analytics
import joel.scripturememory.system.HapticEngine
import joel.scripturememory.ui.theme.AppMotion
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt

internal class ListGeometry(
    val sceneWidth: Int,
    val cardWidth: Int,
    val cardHeight: Int,
    val spacing: Int,
    val below: Int,
    val viewport: Int,
    val count: Int,
) {
    val pitch = cardHeight + spacing
    val left = ((sceneWidth - cardWidth) / 2f).roundToInt()
    private val contentHeight = count * pitch + spacing + below
    private val rawMost = contentHeight - viewport
    private val most = max(0, rawMost)

    fun scrollFor(i: Int): Int {
        val mid = spacing + i * pitch + cardHeight / 2f
        return min(max(0f, mid - viewport / 2f), most.toFloat()).roundToInt()
    }

    fun midY(i: Int, scroll: Int = scrollFor(i)): Float = spacing + i * pitch + cardHeight / 2f - scroll

    val centerX: Float get() = left + cardWidth / 2f

    fun cardShown(offset: Float, fallback: Int): Int {
        if (rawMost <= 0) return fallback
        val half = viewport / 2f
        val reading = offset + if (offset < rawMost / 2f) {
            min(max(offset, 0f), half)
        } else {
            max(half, viewport - max(rawMost - offset, 0f))
        }
        val i = ((reading - spacing / 2f) / pitch).toInt()
        return min(max(i, 0), count - 1)
    }
}

@Stable
internal class PouchController(
    val verses: List<Verse>,
    start: Int,
    private val reduce: Boolean,
    private val hasShelf: Boolean,
    private val animatesPouch: Boolean,
    private val scope: CoroutineScope,
) {
    var index by mutableIntStateOf(start)
    val openness = Animatable(if (reduce) 1f else 0f, motionThreshold)
    val lift = Animatable(if (reduce) 1f else 0f, motionThreshold)
    val spread = Animatable(if (reduce) 1f else 0f, motionThreshold)
    val flight = Animatable(if (hasShelf && !reduce) 1f else 0f, motionThreshold)
    val swipeOffset = Animatable(0f)
    var fanned by mutableStateOf(reduce)
    var listSettled by mutableStateOf(false)
    var closing by mutableStateOf(false)
    var listScrolled = false
    var closeCenterY by mutableStateOf<Float?>(null)
    var listState: LazyListState? = null
    var geometry: ListGeometry? = null
    var onClosed: () -> Unit = {}

    private val openedAt = System.currentTimeMillis()
    private var opening: Job? = null

    fun appeared() {
        if (fanned) return
        opening = scope.launch {
            val fromShelf = flight.value > 0f
            if (fromShelf) launch { flight.animateTo(0f, PouchMotion.smooth(0.35f)) }
            if (fromShelf) delay(80)
            unfoldAndFanOut()
        }
    }

    private fun CoroutineScope.unfoldAndFanOut() {
        launch { openness.animateTo(1f, PouchMotion.smooth(0.4f)) }
        launch {
            delay(300)
            lift.animateTo(1f, PouchMotion.smooth(0.4f))
        }
        HapticEngine.play(HapticEngine.packOpen)
        launch {
            delay(600)
            spread.animateTo(1f, PouchMotion.snappy(0.4f))
            if (!closing && !fanned) fanned = true
        }
    }

    fun finishOpening(flick: Float, pitch: Float) {
        if (fanned || closing) return
        HapticEngine.stop()
        opening?.cancel()
        val target = (index - (flick / pitch).roundToInt()).coerceIn(0, verses.lastIndex)
        scope.launch {
            flight.snapTo(0f)
            openness.snapTo(1f)
            lift.snapTo(1f)
            spread.snapTo(1f)
            fanned = true
            if (target == index) return@launch
            snapshotFlow { listSettled }.first { it }
            index = target
            scrollTo(target, PouchMotion.smooth(0.5f))
        }
    }

    fun close(how: PackCloseMethod) {
        if (closing) return
        closing = true
        val seconds = (System.currentTimeMillis() - openedAt) / 1000.0
        Analytics.log(AnalyticsEvent.PackClosed(how, seconds))
        if (AppMotion.reduceMotion || !animatesPouch) {
            HapticEngine.light()
            onClosed()
            return
        }
        opening?.cancel()
        HapticEngine.play(HapticEngine.packClose)
        closeCenterY = currentCardCenterY()
        fanned = false
        scope.launch {
            withFrameNanos {}
            withFrameNanos {}
            launch { swipeOffset.animateTo(0f, PouchMotion.snappy(0.32f)) }
            launch { spread.animateTo(0f, PouchMotion.snappy(0.32f)) }
            launch {
                delay(200)
                lift.animateTo(0f, PouchMotion.smooth(0.32f))
            }
            launch {
                delay(400)
                openness.animateTo(0f, PouchMotion.smooth(0.34f))
            }
            delay(740)
            if (!hasShelf) {
                onClosed()
                return@launch
            }
            launch { flight.animateTo(1f, PouchMotion.smooth(0.35f)) }
            delay(350)
            HapticEngine.soft()
            onClosed()
        }
    }

    private fun currentCardCenterY(): Float? {
        val g = geometry ?: return null
        val list = listState ?: return null
        if (!listSettled) return null
        return g.midY(index, list.firstVisibleItemIndex * g.pitch + list.firstVisibleItemScrollOffset)
    }

    fun followSwipe(offset: Float) {
        scope.launch { swipeOffset.snapTo(offset) }
    }

    fun releaseSwipe() {
        scope.launch { swipeOffset.animateTo(0f, AppMotion.control()) }
    }

    fun scrollTo(i: Int, spec: AnimationSpec<Float>?) {
        val g = geometry ?: return
        val list = listState ?: return
        val target = g.scrollFor(i)
        scope.launch {
            if (spec == null) {
                list.scrollToItem(target / g.pitch, target % g.pitch)
            } else {
                val current = list.firstVisibleItemIndex * g.pitch + list.firstVisibleItemScrollOffset
                list.animateScrollBy((target - current).toFloat(), spec)
            }
        }
    }
}
