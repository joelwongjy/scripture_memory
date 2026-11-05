package joel.scripturememory.system

import android.content.Context
import android.content.SharedPreferences
import android.os.Build
import android.util.Log
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.telemetrydeck.sdk.TelemetryDeck
import com.telemetrydeck.sdk.providers.DefaultParameterProvider
import joel.scripturememory.BuildConfig
import joel.scripturememory.model.AnalyticsBuild
import joel.scripturememory.model.AnalyticsEvent
import joel.scripturememory.model.UserPackStore

interface AnalyticsSink {
    fun start(context: Context)
    fun stop()
    fun send(event: AnalyticsEvent)
}

object Analytics {
    const val shareUsageKey = "analytics.shareUsage"
    const val shareUsageDefault = true

    private const val deviceOnlyFile = "analytics"

    var sinks: List<AnalyticsSink> = buildList {
        add(TelemetryDeckSink())
        if (BuildConfig.DEBUG) add(ConsoleSink())
    }

    private var started = false
    private var context: Context? = null
    private var preferences: SharedPreferences? = null

    private var shareUsage: Boolean by mutableStateOf(shareUsageDefault)

    val isEnabled: Boolean get() = shareUsage

    fun configure(context: Context) {
        this.context = context.applicationContext
        val saved = context.getSharedPreferences(deviceOnlyFile, Context.MODE_PRIVATE)
        preferences = saved
        shareUsage = saved.getBoolean(shareUsageKey, shareUsageDefault)
    }

    fun start() {
        val context = context ?: return
        if (!isEnabled || started) return
        started = true
        sinks.forEach { it.start(context) }
    }

    fun setEnabled(enabled: Boolean) {
        shareUsage = enabled
        preferences?.edit()?.putBoolean(shareUsageKey, enabled)?.apply()
        if (enabled) {
            start()
        } else if (started) {
            started = false
            sinks.forEach { it.stop() }
        }
    }

    fun log(event: AnalyticsEvent) {
        if (!started) return
        val own = UserPackStore.packs.map { it.name }.toSet()
        val safe = event.redactingPacks { it in own }
        sinks.forEach { it.send(safe) }
    }
}

class TelemetryDeckSink : AnalyticsSink {
    override fun start(context: Context) {
        val isTest = AnalyticsBuild.isTest(BuildConfig.DEBUG, isEmulator, context.installer())
        TelemetryDeck.start(
            context,
            TelemetryDeck.Builder()
                .appID("0215C34A-0573-47A2-861A-A405B0F98961")
                .namespace("com.joelwong")
                .testMode(isTest)
                .addProvider(
                    DefaultParameterProvider(
                        mapOf(
                            "platform" to "android",
                            "TelemetryDeck.RunContext.isAppStore" to (!isTest).toString(),
                        ),
                    ),
                ),
        )
    }

    override fun stop() = TelemetryDeck.stop()

    private val isEmulator: Boolean
        get() = Build.HARDWARE in setOf("ranchu", "goldfish") || Build.FINGERPRINT.startsWith("generic")

    private fun Context.installer(): String? = runCatching {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            packageManager.getInstallSourceInfo(packageName).installingPackageName
        } else {
            @Suppress("DEPRECATION")
            packageManager.getInstallerPackageName(packageName)
        }
    }.getOrNull()

    override fun send(event: AnalyticsEvent) {
        if (event is AnalyticsEvent.ScreenViewed) {
            TelemetryDeck.navigate(event.screen.rawValue)
        } else {
            TelemetryDeck.signal(event.name, params = event.parameters)
        }
    }
}

class ConsoleSink : AnalyticsSink {
    private val tag = "analytics"

    override fun start(context: Context) {
        Log.d(tag, "analytics on")
    }

    override fun stop() {
        Log.d(tag, "analytics off")
    }

    override fun send(event: AnalyticsEvent) {
        val params = event.parameters.toSortedMap().map { "${it.key}=${it.value}" }
        Log.d(tag, "${event.name} ${params.joinToString(" ")}")
    }
}
