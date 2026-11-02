package joel.scripturememory.model

import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.ZonedDateTime
import kotlin.math.floor
import kotlinx.serialization.Serializable

@Serializable
@JvmInline
value class Date(val timeIntervalSinceReferenceDate: Double) : Comparable<Date> {

    val timeIntervalSince1970: Double
        get() = timeIntervalSinceReferenceDate + timeIntervalBetween1970AndReferenceDate

    fun addingTimeInterval(interval: Double): Date =
        Date(timeIntervalSinceReferenceDate + interval)

    fun timeIntervalSince(other: Date): Double =
        timeIntervalSinceReferenceDate - other.timeIntervalSinceReferenceDate

    override fun compareTo(other: Date): Int =
        timeIntervalSinceReferenceDate.compareTo(other.timeIntervalSinceReferenceDate)

    fun toInstant(): Instant {
        val seconds = timeIntervalSince1970
        val whole = floor(seconds)
        return Instant.ofEpochSecond(whole.toLong(), ((seconds - whole) * 1e9).toLong())
    }

    fun atZone(zone: ZoneId): ZonedDateTime = toInstant().atZone(zone)

    fun localDate(zone: ZoneId): LocalDate = atZone(zone).toLocalDate()

    companion object {
        const val timeIntervalBetween1970AndReferenceDate = 978_307_200.0

        fun now(): Date = AppClock.current.now()

        fun fromTimeIntervalSince1970(seconds: Double): Date =
            Date(seconds - timeIntervalBetween1970AndReferenceDate)

        fun from(instant: Instant): Date =
            fromTimeIntervalSince1970(instant.epochSecond + instant.nano / 1e9)
    }
}
