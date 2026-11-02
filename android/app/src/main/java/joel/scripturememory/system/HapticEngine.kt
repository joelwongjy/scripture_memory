package joel.scripturememory.system

import android.content.Context
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.view.HapticFeedbackConstants
import android.view.View

data class Beat(
    val timeMillis: Int,
    val intensity: Float,
    val sharpness: Float,
    val durationMillis: Int = 0,
)

object HapticEngine {
    val packOpen = listOf(
        Beat(0, 0.85f, 0.3f),
        Beat(340, 0.2f, 0.3f, 200),
        Beat(600, 0.55f, 0.75f),
        Beat(660, 0.42f, 0.8f),
        Beat(720, 0.3f, 0.85f),
    )

    val packClose = listOf(
        Beat(0, 0.3f, 0.85f),
        Beat(60, 0.42f, 0.8f),
        Beat(120, 0.55f, 0.75f),
        Beat(220, 0.2f, 0.3f, 200),
        Beat(660, 0.85f, 0.3f),
    )

    private var vibrator: Vibrator? = null

    fun start(context: Context) {
        vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            context.getSystemService(VibratorManager::class.java)?.defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            context.getSystemService(Vibrator::class.java)
        }
    }

    private fun predefined(effect: Int, fallbackMillis: Long, amplitude: Int) {
        val v = vibrator ?: return
        if (!v.hasVibrator()) return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            v.vibrate(VibrationEffect.createPredefined(effect))
        } else {
            v.vibrate(VibrationEffect.createOneShot(fallbackMillis, amplitude))
        }
    }

    fun light() = predefined(EFFECT_TICK, 10, 60)
    fun soft() = predefined(EFFECT_TEXTURE_TICK, 8, 40)
    fun medium() = predefined(EFFECT_CLICK, 16, 120)
    fun success() = predefined(EFFECT_DOUBLE_CLICK, 24, 140)
    fun error() = predefined(EFFECT_HEAVY_CLICK, 40, 200)

    fun play(beats: List<Beat>) {
        stop()
        val v = vibrator ?: return
        if (!v.hasVibrator()) return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R &&
            v.areAllPrimitivesSupported(
                VibrationEffect.Composition.PRIMITIVE_CLICK,
                VibrationEffect.Composition.PRIMITIVE_LOW_TICK,
            )
        ) {
            val composition = VibrationEffect.startComposition()
            var previous = 0
            for (beat in beats) {
                val primitive = if (beat.sharpness >= 0.6f) {
                    VibrationEffect.Composition.PRIMITIVE_CLICK
                } else {
                    VibrationEffect.Composition.PRIMITIVE_LOW_TICK
                }
                composition.addPrimitive(primitive, beat.intensity, beat.timeMillis - previous)
                previous = beat.timeMillis
            }
            v.vibrate(composition.compose())
            return
        }
        val timings = mutableListOf<Long>()
        val amplitudes = mutableListOf<Int>()
        var cursor = 0L
        for (beat in beats) {
            val length = (if (beat.durationMillis > 0) beat.durationMillis else 12).toLong()
            timings += (beat.timeMillis - cursor).coerceAtLeast(0)
            amplitudes += 0
            timings += length
            amplitudes += (beat.intensity * 255).toInt().coerceIn(1, 255)
            cursor = beat.timeMillis + length
        }
        v.vibrate(VibrationEffect.createWaveform(timings.toLongArray(), amplitudes.toIntArray(), -1))
    }

    fun stop() {
        vibrator?.cancel()
    }

    private const val EFFECT_CLICK = 0
    private const val EFFECT_DOUBLE_CLICK = 1
    private const val EFFECT_TICK = 2
    private const val EFFECT_HEAVY_CLICK = 5
    private const val EFFECT_TEXTURE_TICK = 21
}
