package joel.scripturememory.model

import java.time.Duration
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.LocalTime
import java.time.ZoneId
import kotlin.math.max
import kotlin.math.min

object ReminderPlan {

    data class Time(val hour: Int, val minute: Int)

    fun shouldSchedule(enabled: Boolean, authorized: Boolean): Boolean = enabled && authorized

    fun normalizedTime(hour: Int, minute: Int): Time =
        Time(min(max(hour, 0), 23), min(max(minute, 0), 59))

    fun nextFireDate(
        hour: Int,
        minute: Int,
        after: Date,
        zone: ZoneId = AppClock.current.zone,
    ): Date? {
        val (h, m) = normalizedTime(hour, minute)
        val time = LocalTime.of(h, m)
        var day = after.localDate(zone).minusDays(1)
        while (true) {
            fireMoment(day, time, zone, after)?.let { return it }
            day = day.plusDays(1)
        }
    }

    private fun fireMoment(day: LocalDate, time: LocalTime, zone: ZoneId, after: Date): Date? {
        val local = LocalDateTime.of(day, time)
        val transition = zone.rules.getTransition(local)
            ?: return Date.from(local.atZone(zone).toInstant()).takeIf { it > after }
        val spansWholeHour = transition.duration.abs() >= Duration.ofHours(1)
        if (transition.isGap) {
            return Date.from(transition.instant).takeIf { spansWholeHour && it > after }
        }
        val first = Date.from(local.toInstant(transition.offsetBefore))
        val second = Date.from(local.toInstant(transition.offsetAfter))
        return when {
            after < first -> first
            after == first -> null
            after < second && spansWholeHour -> second
            else -> null
        }
    }

    fun reminderBody(review: Int, new: Int): String? {
        val parts = ArrayList<String>()
        if (review > 0) parts.add("$review ${if (review == 1) "review" else "reviews"}")
        if (new > 0) parts.add("$new new ${if (new == 1) "verse" else "verses"}")
        return if (parts.isEmpty()) null else parts.joinToString(", ")
    }
}
