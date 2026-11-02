package joel.scripturememory.system

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import androidx.compose.runtime.Stable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.setValue
import joel.scripturememory.ui.theme.AppMotion
import kotlin.math.abs
import kotlin.math.atan2

@Stable
class TiltMonitor(context: Context) : SensorEventListener {
    var roll by mutableFloatStateOf(0f)
        private set

    private val manager = context.getSystemService(SensorManager::class.java)
    private val sensor = manager?.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
    private var active = false

    fun start() {
        if (sensor == null || AppMotion.reduceMotion || active) return
        active = true
        manager?.registerListener(this, sensor, updateIntervalMicros)
    }

    fun stop() {
        if (!active) return
        active = false
        manager?.unregisterListener(this)
    }

    override fun onSensorChanged(event: SensorEvent) {
        val attitudeRoll = atan2(-event.values[0], event.values[2])
        val target = (attitudeRoll / fullTiltRadians).coerceIn(-1f, 1f)
        val next = roll + (target - roll) * smoothing
        if (abs(next - roll) > threshold) roll = next
    }

    override fun onAccuracyChanged(sensor: Sensor, accuracy: Int) {}

    private companion object {
        const val updateIntervalMicros = 33_333
        const val fullTiltRadians = 0.6f
        const val smoothing = 0.18f
        const val threshold = 0.002f
    }
}
