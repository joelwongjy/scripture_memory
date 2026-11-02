package joel.scripturememory.model

import java.time.DayOfWeek
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

class StreakStoreTests {

    private val day = SRSStore.secondsPerDay
    private lateinit var clock: TestClock
    private lateinit var store: InMemoryStore
    private lateinit var streak: StreakStore

    @Before
    fun setUp() {
        clock = TestClock(Date.from(Instant.parse("2027-02-10T12:00:00Z")))
        store = InMemoryStore()
        installModel(clock, store)
        streak = StreakStore.shared
    }

    private fun seed(vararg daysAgo: Int) {
        for (ago in daysAgo) streak.recordToday(clock.now().addingTimeInterval(-ago * day))
    }

    @Test
    fun recordTodayIsIdempotent() {
        streak.recordToday()
        streak.recordToday()
        assertEquals(1, streak.totalDays)
    }

    @Test
    fun noDaysIsNoStreak() {
        assertEquals(0, streak.current)
        assertEquals(0, streak.longest)
        assertFalse(streak.isTodayDone)
    }

    @Test
    fun currentCountsConsecutiveDaysEndingToday() {
        seed(0, 1, 2, 5)
        assertEquals(3, streak.current)
        assertTrue(streak.isTodayDone)
    }

    @Test
    fun streakIsStillAliveUntilTheDayPasses() {
        seed(1, 2)
        assertEquals(2, streak.current)
        assertFalse(streak.isTodayDone)
    }

    @Test
    fun missingTwoDaysEndsTheStreak() {
        seed(2, 3)
        assertEquals(0, streak.current)
    }

    @Test
    fun longestFindsTheBestRunNotTheLatest() {
        seed(0, 1, 5, 6, 7, 8, 20)
        assertEquals(4, streak.longest)
    }

    @Test
    fun longestIgnoresMalformedKeys() {
        store.putString(
            "streak.days.v1",
            """["2027-02-08","2027-02-09","garbage","2027-02","x-y-z"]""",
        )
        assertEquals(2, StreakStore(ProgressStorage(store)).longest)
    }

    @Test
    fun longestRunsAcrossMonthAndYearEnds() {
        store.putString(
            "streak.days.v1",
            """["2026-12-30","2026-12-31","2027-01-01","2027-02-28","2027-03-01"]""",
        )
        assertEquals(3, StreakStore(ProgressStorage(store)).longest)
    }

    @Test
    fun onlyThe400MostRecentDaysAreKept() {
        for (ago in 400 downTo 0) seed(ago)
        assertEquals(400, streak.totalDays)
        assertFalse(StreakStore.dayKey(clock.now().addingTimeInterval(-400 * day)) in streak.days)
        assertTrue(StreakStore.dayKey(clock.now().addingTimeInterval(-399 * day)) in streak.days)
    }

    @Test
    fun currentHoldsAcrossDaylightSavingDays() {
        clock.zone = ZoneId.of("America/New_York")
        clock.date = Date.from(Instant.parse("2027-03-15T16:00:00Z"))
        seed(0, 1, 2, 3)
        assertEquals(4, streak.current)
        assertEquals(4, streak.longest)
    }

    @Test
    fun dayRollsAtLocalMidnight() {
        clock.zone = ZoneId.of("Asia/Singapore")
        clock.date = Date.from(Instant.parse("2027-02-10T15:59:59Z"))
        streak.recordToday()
        assertTrue(streak.isTodayDone)
        clock.advance(1.0)
        assertFalse(streak.isTodayDone)
        assertEquals(1, streak.current)
    }

    @Test
    fun isDoneChecksTheGivenDay() {
        seed(3)
        assertTrue(streak.isDone(clock.now().addingTimeInterval(-3 * day)))
        assertFalse(streak.isDone(clock.now()))
    }

    @Test
    fun thisWeekStartsOnTheLocalesFirstDay() {
        clock.firstDayOfWeek = DayOfWeek.SUNDAY
        val sundayFirst = streak.thisWeek()
        assertEquals(listOf("S", "M", "T", "W", "T", "F", "S"), sundayFirst.map { it.initial })
        clock.firstDayOfWeek = DayOfWeek.MONDAY
        assertEquals(listOf("M", "T", "W", "T", "F", "S", "S"), streak.thisWeek().map { it.initial })
    }

    @Test
    fun thisWeekMarksDoneTodayAndFuture() {
        seed(0, 1)
        val week = streak.thisWeek()
        assertEquals(7, week.size)
        assertEquals(listOf(3), week.indices.filter { week[it].isToday })
        assertEquals(listOf(4, 5, 6), week.indices.filter { week[it].isFuture })
        assertEquals(listOf(2, 3), week.indices.filter { week[it].done })
    }

    @Test
    fun daysSurviveAReload() {
        seed(0, 4)
        assertEquals(streak.days, StreakStore(ProgressStorage(store)).days)
    }

    @Test
    fun recordedKeysAreTheStoredDayFormat() {
        streak.recordToday()
        assertEquals(LocalDate.of(2027, 2, 10).toString(), streak.days.single())
    }
}
