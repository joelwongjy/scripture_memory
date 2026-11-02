package joel.scripturememory.model

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class SRSScheduleTests {

    private val day = 86_400.0
    private val start = Date.fromTimeIntervalSince1970(1_700_000_000.0)

    private fun later(a: Date, b: Date) = if (a >= b) a else b

    private fun reviewOnDueDates(
        grade: SRSGrade,
        times: Int,
        initial: SRSCardState? = null,
    ): List<Pair<Date, SRSCardState>> {
        var s = initial ?: SRSCardState.newCard("k", start)
        var now = start
        return List(times) {
            now = later(now, s.due)
            s = updateSRS(s, grade, now)
            now to s
        }
    }

    @Test
    fun testGoodEveryDueDateGrowsIntervalsIntoTheFuture() {
        val traj = reviewOnDueDates(SRSGrade.good, 8)

        for ((now, state) in traj) assertTrue(state.due > now)

        val intervals = traj.map { it.second }.filter { it.phase == SRSPhase.review }.map { it.interval }
        assertFalse(intervals.isEmpty())
        for (i in 1 until intervals.size) {
            assertTrue(intervals[i] >= intervals[i - 1] - 1e-9)
        }

        val last = traj.last().second
        assertEquals(SRSPhase.review, last.phase)
        assertTrue(last.interval > 5)
    }

    @Test
    fun testEasyGraduatesAndIsDueFourDaysOut() {
        val s = updateSRS(SRSCardState.newCard("k", start), SRSGrade.easy, start)
        assertEquals(SRSPhase.review, s.phase)
        assertTrue(s.due > start.addingTimeInterval(3 * day))
        assertEquals(4 * day, s.due.timeIntervalSince(start), 1.0)
    }

    @Test
    fun testLapseAfterBuildupResetsTheSchedule() {
        var s = reviewOnDueDates(SRSGrade.good, 5).last().second
        assertEquals(SRSPhase.review, s.phase)
        assertTrue(s.interval > 2)

        val now = s.due
        s = updateSRS(s, SRSGrade.again, now)
        assertEquals(SRSPhase.learning, s.phase)
        assertEquals(1, s.lapses)
        assertEquals(0.0, s.interval, 0.0)
        assertEquals(60.0, s.due.timeIntervalSince(now), 1.0)
    }

    @Test
    fun testTwoWeekGoodStudyKeepsEaseStable() {
        var s = SRSCardState.newCard("k", start)
        var now = start
        var reviews = 0
        val end = start.addingTimeInterval(14 * day)
        while (now < end && reviews < 60) {
            now = later(now, s.due)
            if (now >= end) break
            s = updateSRS(s, SRSGrade.good, now)
            reviews += 1
        }
        assertTrue(reviews > 0)
        assertTrue(s.reps >= 1)
        assertEquals(2.5, s.ease, 1e-9)
        if (s.phase == SRSPhase.review) assertTrue(s.interval >= 1.0)
    }

    @Test
    fun testHardSchedulesSoonerThanGood() {
        val base = SRSCardState("k", SRSPhase.review, 10.0, 2.5, 3, 0, 0, start, null)
        val good = updateSRS(base, SRSGrade.good, start)
        val hard = updateSRS(base, SRSGrade.hard, start)
        assertTrue(hard.due < good.due)
    }

    @Test
    fun testMixedGradeWalkNeverDueInThePast() {
        val rng = SplitMix64(0xDA175EEDuL)
        var s = SRSCardState.newCard("k", start)
        var now = start
        repeat(300) {
            now = later(now, s.due)
            s = updateSRS(s, SRSGrade.entries.random(rng), now)
            assertTrue(s.due > now.addingTimeInterval(-1e-6))
            assertTrue(s.ease >= 1.3 - 1e-9)
        }
    }
}
