package joel.scripturememory.model

import java.time.DayOfWeek
import java.time.Instant
import java.time.ZoneId
import java.time.temporal.WeekFields
import java.util.Locale

interface AppClock {
    fun now(): Date
    val zone: ZoneId
    val locale: Locale
    val firstDayOfWeek: DayOfWeek

    companion object {
        var current: AppClock = SystemAppClock
    }
}

object SystemAppClock : AppClock {
    override fun now(): Date = Date.from(Instant.now())
    override val zone: ZoneId get() = ZoneId.systemDefault()
    override val locale: Locale get() = Locale.getDefault()
    override val firstDayOfWeek: DayOfWeek get() = WeekFields.of(locale).firstDayOfWeek
}
