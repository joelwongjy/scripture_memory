package joel.scripturememory.widget

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import androidx.compose.runtime.mutableIntStateOf
import androidx.glance.appwidget.updateAll
import java.time.LocalTime
import joel.scripturememory.model.AppClock
import joel.scripturememory.model.AppDefaults
import joel.scripturememory.model.BibleVersion
import joel.scripturememory.model.Catalogue
import joel.scripturememory.model.Date
import joel.scripturememory.model.LearningStore
import joel.scripturememory.model.NewCardCap
import joel.scripturememory.model.PackPreferencesStore
import joel.scripturememory.model.ProgressJson
import joel.scripturememory.model.SRSQueueBuilder
import joel.scripturememory.model.SRSStore
import joel.scripturememory.model.StreakStore
import joel.scripturememory.system.Background
import kotlinx.serialization.Serializable

object WidgetBridge {

    @Serializable
    data class SharedVerse(
        val title: String,
        val verse: String,
        val book: String,
        val reference: String,
        val packName: String,
    )

    @Serializable
    data class WeekDay(val letter: String, val done: Boolean, val today: Boolean)

    @Serializable
    data class Snapshot(
        val verse: SharedVerse?,
        val isPinned: Boolean = false,
        val streak: Int,
        val dueToday: Int,
        val learned: Int,
        val week: List<WeekDay>,
    )

    private const val preferencesFile = "widget"
    private const val snapshotKey = "widget.snapshot.v1"

    private lateinit var context: Context

    val revision = mutableIntStateOf(0)

    fun configure(context: Context) {
        this.context = context.applicationContext
    }

    fun current(): Snapshot {
        val version = BibleVersion.saved()
        val visible = PackPreferencesStore.shared.visible(version.packs)
        val displayed = LearningStore.shared.displayed(Catalogue.verses(visible))
        val store = SRSStore.shared
        val dueToday = SRSQueueBuilder.dueSummary(
            activePacks = store.activePacks(visible),
            store = store,
            newCap = NewCardCap.current(),
            dailyReviewCap = AppDefaults.standard.getInt(NewCardCap.dailyReviewCapKey)
                ?: NewCardCap.dailyReviewCapDefault,
            now = Date.now(),
        ).total
        return Snapshot(
            verse = displayed?.verse?.let {
                SharedVerse(it.title, it.verse, it.book, it.reference, it.packName)
            },
            isPinned = displayed?.isPinned ?: false,
            streak = StreakStore.shared.current,
            dueToday = dueToday,
            learned = LearningStore.shared.learntKeys.size,
            week = StreakStore.shared.thisWeek().map { WeekDay(it.initial, it.done, it.isToday) },
        )
    }

    fun sync() = Background.launch {
        val raw = ProgressJson.encodeToString(Snapshot.serializer(), current())
        val preferences = context.getSharedPreferences(preferencesFile, Context.MODE_PRIVATE)
        scheduleMidnightRefresh()
        if (raw == preferences.getString(snapshotKey, null)) return@launch
        preferences.edit().putString(snapshotKey, raw).apply()
        reload()
    }

    suspend fun reload() {
        revision.intValue += 1
        ScriptureVerseWidget().updateAll(context)
        ScriptureProgressWidget().updateAll(context)
    }

    fun scheduleMidnightRefresh() {
        val alarms = context.getSystemService(AlarmManager::class.java)
        val refresh = PendingIntent.getBroadcast(
            context,
            0,
            Intent(context, WidgetRefreshReceiver::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        if (!hasWidgets) {
            alarms.cancel(refresh)
            return
        }
        val zone = AppClock.current.zone
        val midnight = Date.now().localDate(zone).plusDays(1).atTime(LocalTime.of(0, 1)).atZone(zone)
        alarms.setAndAllowWhileIdle(AlarmManager.RTC, midnight.toInstant().toEpochMilli(), refresh)
    }

    private val hasWidgets: Boolean
        get() {
            val manager = AppWidgetManager.getInstance(context) ?: return false
            return listOf(ScriptureVerseWidgetReceiver::class.java, ScriptureProgressWidgetReceiver::class.java)
                .any { manager.getAppWidgetIds(ComponentName(context, it)).isNotEmpty() }
        }
}

class WidgetRefreshReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val pending = goAsync()
        Background.launch {
            try {
                WidgetBridge.sync().join()
            } finally {
                pending.finish()
            }
        }
    }
}
