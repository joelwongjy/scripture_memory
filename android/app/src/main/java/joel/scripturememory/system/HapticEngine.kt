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
)

object HapticEngine {
    val packOpen = listOf(
        Beat(0, 0.85f, 0.3f),
        Beat(340, 0.2f, 0.3f),
        Beat(600, 0.55f, 0.75f),
        Beat(660, 0.42f, 0.8f),
        Beat(720, 0.3f, 0.85f),
    )

    val packClose = listOf(
        Beat(0, 0.3f, 0.85f),
        Beat(60, 0.42f, 0.8f),
        Beat(120, 0.55f, 0.75f),
        Beat(220, 0.2f, 0.3f),
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

    private fun predefined(effect: Int) {
        val v = vibrator ?: return
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R || !v.hasVibrator()) return
        val native = v.areAllEffectsSupported(effect) == Vibrator.VIBRATION_EFFECT_SUPPORT_YES
        if (!native && !hasPrimitives(v)) return
        v.vibrate(VibrationEffect.createPredefined(effect))
    }

    private fun hasPrimitives(v: Vibrator): Boolean =
        Build.VERSION.SDK_INT >= Build.VERSION_CODES.R &&
            v.areAllPrimitivesSupported(
                VibrationEffect.Composition.PRIMITIVE_CLICK,
                VibrationEffect.Composition.PRIMITIVE_LOW_TICK,
            )

    fun light() = predefined(EFFECT_TICK)
    fun soft() = predefined(EFFECT_TEXTURE_TICK)
    fun medium() = predefined(EFFECT_CLICK)
    fun success() = predefined(EFFECT_DOUBLE_CLICK)
    fun error() = predefined(EFFECT_HEAVY_CLICK)

    fun play(beats: List<Beat>) {
        stop()
        val v = vibrator ?: return
        if (!v.hasVibrator() || !hasPrimitives(v)) return
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
