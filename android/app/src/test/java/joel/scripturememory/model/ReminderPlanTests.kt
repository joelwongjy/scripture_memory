package joel.scripturememory.model

import java.time.ZoneOffset
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class ReminderPlanTests {

    private fun fire(hour: Int, minute: Int, after: Date) =
        ReminderPlan.nextFireDate(hour, minute, after, ZoneOffset.UTC)

    private fun clockFields(date: Date): Pair<Int, Int> {
        val time = date.atZone(ZoneOffset.UTC)
        return time.hour to time.minute
    }

    @Test
    fun testShouldScheduleRequiresEnabledAndAuthorized() {
        assertTrue(ReminderPlan.shouldSchedule(enabled = true, authorized = true))
        assertFalse(ReminderPlan.shouldSchedule(enabled = true, authorized = false))
        assertFalse(ReminderPlan.shouldSchedule(enabled = false, authorized = true))
        assertFalse(ReminderPlan.shouldSchedule(enabled = false, authorized = false))
    }

    @Test
    fun testNormalizedTimePassesValid() {
        val t = ReminderPlan.normalizedTime(8, 30)
        assertEquals(8, t.hour)
        assertEquals(30, t.minute)
    }

    @Test
    fun testNormalizedTimeClamps() {
        assertEquals(0, ReminderPlan.normalizedTime(-1, -5).hour)
        assertEquals(0, ReminderPlan.normalizedTime(-1, -5).minute)
        assertEquals(23, ReminderPlan.normalizedTime(25, 99).hour)
        assertEquals(59, ReminderPlan.normalizedTime(25, 99).minute)
        assertEquals(23, ReminderPlan.normalizedTime(23, 59).hour)
        assertEquals(0, ReminderPlan.normalizedTime(0, 0).minute)
    }

    @Test
    fun testNextFireDateIsInFutureAtRequestedTime() {
        val now = Date.fromTimeIntervalSince1970(0.0)
        val next = fire(9, 0, now)
        assertNotNull(next)
        assertTrue(next!! > now)
        assertEquals(9 to 0, clockFields(next))
    }

    @Test
    fun testNextFireDateRollsToNextDayWhenTimePassed() {
        val now = Date.fromTimeIntervalSince1970(10.0 * 3600)
        val next = fire(9, 0, now)!!
        assertTrue(next > now)
        assertTrue(next.timeIntervalSince(now) >= 22.0 * 3600)
        assertEquals(9, clockFields(next).first)
    }

    @Test
    fun testNextFireDateClampsOutOfRangeTime() {
        val next = fire(30, 80, Date.fromTimeIntervalSince1970(0.0))!!
        assertEquals(23 to 59, clockFields(next))
    }

    @Test
    fun testReminderBodyWithReviewsAndNew() {
        assertEquals("3 reviews, 1 new verse", ReminderPlan.reminderBody(3, 1))
        assertEquals("1 review, 2 new verses", ReminderPlan.reminderBody(1, 2))
    }

    @Test
    fun testReminderBodyReviewsOnly() {
        assertEquals("1 review", ReminderPlan.reminderBody(1, 0))
        assertEquals("5 reviews", ReminderPlan.reminderBody(5, 0))
    }

    @Test
    fun testReminderBodyNewOnly() {
        assertEquals("1 new verse", ReminderPlan.reminderBody(0, 1))
        assertEquals("2 new verses", ReminderPlan.reminderBody(0, 2))
    }

    @Test
    fun testReminderBodyNothingDueReturnsNil() {
        assertNull(ReminderPlan.reminderBody(0, 0))
    }
}
