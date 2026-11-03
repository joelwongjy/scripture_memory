package joel.scripturememory.model

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import java.time.LocalDate
import java.time.format.DateTimeFormatter
import java.time.temporal.ChronoUnit
import java.time.temporal.TemporalAdjusters
import kotlin.math.max

class StreakStore(private val storage: ProgressStorage) {

    data class WeekDay(
        val initial: String,
        val done: Boolean,
        val isToday: Boolean,
        val isFuture: Boolean,
    )

    var days: Set<String> by mutableStateOf(storage.stringArray(storageKey).orEmpty().toSet())
        private set

    fun recordToday(now: Date = Date.now()) {
        val key = dayKey(now)
        if (key in days) return
        var updated = days + key
        if (updated.size > 400) {
            updated = updated.sorted().takeLast(400).toSet()
        }
        days = updated
        persist()
    }

    private fun persist() {
        storage.set(days.toList(), storageKey)
    }

    val current: Int
        get() {
            var day = today()
            if (SRSStore.dayKey(day) !in days) day = day.minusDays(1)
            var streak = 0
            while (SRSStore.dayKey(day) in days) {
                streak += 1
                day = day.minusDays(1)
            }
            return streak
        }

    val isTodayDone: Boolean get() = dayKey(Date.now()) in days

    val totalDays: Int get() = days.size

    val longest: Int
        get() {
            val dates = days.mapNotNull(::date).sorted()
            var best = 0
            var run = 0
            var previous: LocalDate? = null
            for (d in dates) {
                val p = previous
                run = if (p != null && ChronoUnit.DAYS.between(p, d) == 1L) run + 1 else 1
                best = max(best, run)
                previous = d
            }
            return best
        }

    val firstDay: LocalDate? get() = days.mapNotNull(::date).minOrNull()

    fun isDone(date: Date): Boolean = dayKey(date) in days

    fun thisWeek(): List<WeekDay> {
        val clock = AppClock.current
        val today = today()
        val start = today.with(TemporalAdjusters.previousOrSame(clock.firstDayOfWeek))
        val formatter = DateTimeFormatter.ofPattern("EEEEE", clock.locale)
        return (0L until 7L).map { offset ->
            val d = start.plusDays(offset)
            WeekDay(
                initial = formatter.format(d),
                done = SRSStore.dayKey(d) in days,
                isToday = d == today,
                isFuture = d > today,
            )
        }
    }

    private fun today(): LocalDate = Date.now().localDate(AppClock.current.zone)

    companion object {
        lateinit var shared: StreakStore
            internal set

        private const val storageKey = "streak.days.v1"

        private fun date(key: String): LocalDate? {
            val parts = key.split("-").filter { it.isNotEmpty() }.mapNotNull { it.toIntOrNull() }
            if (parts.size != 3) return null
            return LocalDate.of(parts[0], 1, 1)
                .plusMonths(parts[1] - 1L)
                .plusDays(parts[2] - 1L)
        }

        fun dayKey(date: Date): String = SRSStore.dayKey(date)
    }
}
