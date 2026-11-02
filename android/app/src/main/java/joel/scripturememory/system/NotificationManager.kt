package joel.scripturememory.system

import android.annotation.SuppressLint
import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.compose.ui.graphics.toArgb
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import joel.scripturememory.R
import joel.scripturememory.model.AppDefaults
import joel.scripturememory.model.BibleVersion
import joel.scripturememory.model.Date
import joel.scripturememory.model.NewCardCap
import joel.scripturememory.model.PackPreferencesStore
import joel.scripturememory.model.ReminderPlan
import joel.scripturememory.model.SRSQueueBuilder
import joel.scripturememory.model.SRSStore
import joel.scripturememory.ui.theme.LightColors

object NotificationManager {

    const val reminderId = "daily-review-reminder"
    const val windowDays = 7

    object Keys {
        const val enabled = "notif.reminderEnabled"
        const val hour = "notif.reminderHour"
        const val minute = "notif.reminderMinute"
    }

    const val defaultHour = 8
    const val defaultMinute = 0

    private const val channelId = "daily-review"
    private const val bodyExtra = "body"
    private const val indexExtra = "index"
    private const val title = "Daily review"
    private const val onTimeWindowMillis = 10 * 60 * 1000L

    private lateinit var context: Context

    fun configure(context: Context) {
        this.context = context.applicationContext
        val channel = NotificationChannel(
            channelId,
            title,
            android.app.NotificationManager.IMPORTANCE_DEFAULT,
        )
        NotificationManagerCompat.from(context).createNotificationChannel(channel)
    }

    val isAuthorized: Boolean
        get() {
            val manager = NotificationManagerCompat.from(context)
            if (!manager.areNotificationsEnabled()) return false
            val channel = manager.getNotificationChannel(channelId) ?: return true
            return channel.importance != NotificationManagerCompat.IMPORTANCE_NONE
        }

    fun scheduleReminders(hour: Int, minute: Int) {
        val (h, m) = ReminderPlan.normalizedTime(hour, minute)
        val alarms = context.getSystemService(AlarmManager::class.java)

        val defaults = AppDefaults.standard
        val activePacks = PackPreferencesStore.shared.visible(BibleVersion.saved().packs)
            .filter { SRSStore.shared.isActive(it.name) }
        val cap = NewCardCap.current()
        val reviewCap = defaults.getInt(NewCardCap.dailyReviewCapKey) ?: NewCardCap.dailyReviewCapDefault

        clearPending()

        var fire = Date.now()
        for (i in 0 until windowDays) {
            fire = ReminderPlan.nextFireDate(h, m, fire) ?: continue
            val summary = SRSQueueBuilder.dueSummary(
                activePacks = activePacks,
                store = SRSStore.shared,
                newCap = cap,
                dailyReviewCap = reviewCap,
                now = fire,
            )
            val body = ReminderPlan.reminderBody(summary.review, summary.new) ?: continue
            val trigger = fire.toInstant().toEpochMilli()
            alarms.setWindow(AlarmManager.RTC_WAKEUP, trigger, onTimeWindowMillis, reminder(i, body))
            alarms.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, trigger, reminder(windowDays + i, body))
        }
    }

    fun cancelDailyReminder() {
        clearPending()
    }

    fun refreshFromSettings() {
        val defaults = AppDefaults.standard
        val enabled = defaults.getBool(Keys.enabled) ?: false
        if (!ReminderPlan.shouldSchedule(enabled, isAuthorized)) {
            cancelDailyReminder()
            return
        }
        scheduleReminders(
            hour = defaults.getInt(Keys.hour) ?: defaultHour,
            minute = defaults.getInt(Keys.minute) ?: defaultMinute,
        )
    }

    @SuppressLint("MissingPermission")
    internal fun post(intent: Intent) {
        val body = intent.getStringExtra(bodyExtra) ?: return
        val index = intent.getIntExtra(indexExtra, 0)
        cancel(if (index < windowDays) index + windowDays else index - windowDays)
        if (!isAuthorized) return
        val open = PendingIntent.getActivity(
            context,
            0,
            DeepLink.intent(context, DeepLink.review, DeepLink.reminderSource),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val notification = NotificationCompat.Builder(context, channelId)
            .setSmallIcon(R.drawable.ic_notification)
            .setColor(LightColors.accent.toArgb())
            .setContentTitle(title)
            .setContentText(body)
            .setCategory(NotificationCompat.CATEGORY_REMINDER)
            .setAutoCancel(true)
            .setOnlyAlertOnce(true)
            .setContentIntent(open)
            .build()
        NotificationManagerCompat.from(context).notify(reminderId, 0, notification)
    }

    private fun reminderIntent(index: Int): Intent =
        Intent(context, ReminderReceiver::class.java).setAction("$reminderId-$index")

    private fun reminder(index: Int, body: String): PendingIntent =
        PendingIntent.getBroadcast(
            context,
            index,
            reminderIntent(index).putExtra(bodyExtra, body).putExtra(indexExtra, index),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

    private fun clearPending() {
        for (i in 0 until windowDays * 2) cancel(i)
    }

    private fun cancel(index: Int) {
        val pending = PendingIntent.getBroadcast(
            context,
            index,
            reminderIntent(index),
            PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE,
        ) ?: return
        context.getSystemService(AlarmManager::class.java).cancel(pending)
        pending.cancel()
    }

    val needsPermissionPrompt: Boolean
        get() = Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            context.checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS) !=
            android.content.pm.PackageManager.PERMISSION_GRANTED
}
