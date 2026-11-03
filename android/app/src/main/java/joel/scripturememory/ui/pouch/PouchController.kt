package joel.scripturememory.ui.pouch

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.AnimationSpec
import androidx.compose.foundation.gestures.animateScrollBy
import androidx.compose.foundation.lazy.LazyListState
import androidx.compose.runtime.Stable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.runtime.snapshotFlow
import androidx.compose.runtime.withFrameNanos
import androidx.compose.ui.geometry.Rect
import joel.scripturememory.model.ActiveTimer
import joel.scripturememory.model.AnalyticsEvent
import joel.scripturememory.model.PackCloseMethod
import joel.scripturememory.model.PackListLayout
import joel.scripturememory.model.Verse
import joel.scripturememory.system.Analytics
import joel.scripturememory.system.HapticEngine
import joel.scripturememory.ui.theme.AppMotion
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
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
    val layout: PackListLayout,
    private val density: Float,
) {
    val pitch = cardHeight + spacing
    val columnPitch: Float get() = layout.columnPitch * density
    val rows: Int get() = layout.rows(count)
    private val contentHeight = rows * pitch + spacing + below
    private val rawMost = contentHeight - viewport
    private val most = max(0, rawMost)

    fun scrollFor(i: Int): Int {
        val mid = spacing + layout.row(i) * pitch + cardHeight / 2f
        return min(max(0f, mid - viewport / 2f), most.toFloat()).roundToInt()
    }

    fun scrollAt(fraction: Double): Int = (fraction.coerceIn(0.0, 1.0) * most).roundToInt()

    fun fraction(offset: Int): Double? = if (most > 0) (offset.toDouble() / most).coerceIn(0.0, 1.0) else null

    fun midY(i: Int, scroll: Int = scrollFor(i)): Float = spacing + layout.row(i) * pitch + cardHeight / 2f - scroll

    fun centerX(i: Int): Float = sceneWidth / 2f + layout.centerOffset(i) * density

    fun cardShown(offset: Float, fallback: Int): Int {
        if (rawMost <= 0) return fallback
        val half = viewport / 2f
        val reading = offset + if (offset < rawMost / 2f) {
            min(max(offset, 0f), half)
        } else {
            max(half, viewport - max(rawMost - offset, 0f))
        }
        val row = ((reading - spacing / 2f) / pitch).toInt()
        return min(max(layout.firstCard(row), 0), count - 1)
    }
}

@Stable
internal class PouchProgress(initial: Float) {
    var value by mutableFloatStateOf(initial)
}

private class PouchSegment(
    val progress: PouchProgress,
    val to: Float,
    val delay: Float,
    val curve: SpringCurve,
) {
    private val from = progress.value

    fun apply(t: Float) {
        progress.value = from + (to - from) * curve.at(t - delay)
    }

    fun finish() {
        progress.value = to
    }
}

@Stable
internal class PouchController(
    verses: List<Verse>,
    start: Int,
    private val reduce: Boolean,
    private val hasShelf: Boolean,
    private val animatesPouch: Boolean,
    private val scope: CoroutineScope,
) {
    var verses by mutableStateOf(verses)
    var index by mutableIntStateOf(start)
    var listFraction by mutableStateOf<Double?>(null)
    val openness = PouchProgress(if (reduce) 1f else 0f)
    val lift = PouchProgress(if (reduce) 1f else 0f)
    val spread = PouchProgress(if (reduce) 1f else 0f)
    val flight = PouchProgress(if (hasShelf && !reduce) 1f else 0f)
    val swipeOffset = Animatable(0f)
    var fanned by mutableStateOf(reduce)
    var listSettled by mutableStateOf(false)
    var closing by mutableStateOf(false)
    var lifted by mutableStateOf<LiftedCard?>(null)
    val liftAmount = Animatable(0f)
    val liftedAngle = Animatable(0f)
    val liftedDragX = Animatable(0f)
    val liftedDragY = Animatable(0f)
    var columns by mutableIntStateOf(1)
    private var flipCount = 0
    var listScrolled = false
    var closeCenterY by mutableStateOf<Float?>(null)
    var listState: LazyListState? = null
    var geometry: ListGeometry? = null
    var onClosed: () -> Unit = {}

    val openTime = ActiveTimer()
    private var opening: Job? = null

    private suspend fun awaitComposedFrame() {
        withFrameNanos {}
        withFrameNanos {}
    }

    private suspend fun play(segments: List<PouchSegment>, end: Float, cueAt: Float = 0f, cue: () -> Unit = {}) {
        val start = withFrameNanos { it }
        var cued = false
        while (true) {
            val t = (withFrameNanos { it } - start) / 1_000_000_000f
            segments.forEach { it.apply(t) }
            if (!cued && t >= cueAt) {
                cued = true
                cue()
            }
            if (t >= end) break
        }
        segments.forEach { it.finish() }
    }

    fun appeared() {
        if (fanned) return
        opening = scope.launch {
            awaitComposedFrame()
            val fromShelf = flight.value > 0f
            val lead = if (fromShelf) 0.08f else 0f
            val spreading = PouchMotion.snappy(0.4f)
            play(
                listOfNotNull(
                    if (fromShelf) PouchSegment(flight, 0f, 0f, PouchMotion.smooth(0.35f)) else null,
                    PouchSegment(openness, 1f, lead, PouchMotion.smooth(0.4f)),
                    PouchSegment(lift, 1f, lead + 0.3f, PouchMotion.smooth(0.4f)),
                    PouchSegment(spread, 1f, lead + 0.6f, spreading),
                ),
                end = lead + 0.6f + spreading.settling,
                cueAt = lead,
                cue = { HapticEngine.play(HapticEngine.packOpen) },
            )
            if (!closing && !fanned) fanned = true
        }
    }

    fun finishOpening(flick: Float, pitch: Float, columns: Int) {
        if (fanned || closing) return
        HapticEngine.stop()
        opening?.cancel()
        val target = (index - (flick / pitch).roundToInt() * columns).coerceIn(0, verses.lastIndex)
        flight.value = 0f
        openness.value = 1f
        lift.value = 1f
        spread.value = 1f
        fanned = true
        if (target == index) return
        scope.launch {
            snapshotFlow { listSettled }.first { it }
            index = target
            scrollTo(target, PouchMotion.smoothSpec(0.5f))
        }
    }

    private fun cardMotion(): AnimationSpec<Float> = AppMotion.repeated()

    private fun cardBounce(): AnimationSpec<Float> = AppMotion.recoil()

    fun liftCard(i: Int, source: Rect) {
        if (lifted != null) return
        HapticEngine.light()
        flipCount += 1
        lifted = LiftedCard(i, source)
        scope.launch { liftAmount.animateTo(1f, cardMotion()) }
        scope.launch { liftedAngle.animateTo(180f, cardMotion()) }
    }

    fun flipLiftedCard() {
        HapticEngine.light()
        val to = if (liftedAngle.targetValue > 90f) 0f else 180f
        scope.launch { liftedAngle.animateTo(to, cardMotion()) }
    }

    fun followCardSwipe(x: Float, y: Float) {
        scope.launch {
            liftedDragX.snapTo(x)
            liftedDragY.snapTo(y)
        }
    }

    fun releaseCardSwipe(putBack: Boolean) {
        if (putBack) {
            putCardBack(cardBounce())
            return
        }
        scope.launch { liftedDragX.animateTo(0f, cardBounce()) }
        scope.launch { liftedDragY.animateTo(0f, cardBounce()) }
    }

    fun putCardBack() = putCardBack(cardMotion())

    private fun putCardBack(motion: AnimationSpec<Float>) {
        if (lifted == null || liftAmount.targetValue != 1f) return
        scope.launch {
            listOf(
                launch { liftAmount.animateTo(0f, motion) },
                launch { liftedAngle.animateTo(0f, motion) },
                launch { liftedDragX.animateTo(0f, motion) },
                launch { liftedDragY.animateTo(0f, motion) },
            ).forEach { it.join() }
            lifted = null
        }
    }

    fun dropLiftedCard() {
        lifted = null
        scope.launch {
            liftAmount.snapTo(0f)
            liftedAngle.snapTo(0f)
            liftedDragX.snapTo(0f)
            liftedDragY.snapTo(0f)
        }
    }

    fun close(how: PackCloseMethod) {
        if (closing) return
        closing = true
        Analytics.log(AnalyticsEvent.PackClosed(how, openTime.elapsed(), flipCount))
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
            awaitComposedFrame()
            launch { swipeOffset.animateTo(0f, PouchMotion.snappySpec(0.32f)) }
            val putBack = 0.4f + 0.34f
            val flying = PouchMotion.smooth(0.35f)
            play(
                listOfNotNull(
                    PouchSegment(spread, 0f, 0f, PouchMotion.snappy(0.32f)),
                    PouchSegment(lift, 0f, 0.2f, PouchMotion.smooth(0.32f)),
                    PouchSegment(openness, 0f, 0.4f, PouchMotion.smooth(0.34f)),
                    if (hasShelf) PouchSegment(flight, 1f, putBack, flying) else null,
                ),
                end = if (hasShelf) putBack + flying.duration else putBack,
            )
            if (hasShelf) HapticEngine.soft()
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

    fun scrubTo(fraction: Double) {
        val g = geometry ?: return
        val list = listState ?: return
        val target = g.scrollAt(fraction)
        scope.launch { list.scrollToItem(target / g.pitch, target % g.pitch) }
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
