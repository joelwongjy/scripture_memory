package joel.scripturememory.model

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class SRSAlgorithmTests {

    private val now = Date.fromTimeIntervalSince1970(1_000_000.0)
    private val day = 86_400.0

    private fun dueOffset(s: SRSCardState) = s.due.timeIntervalSince(now)

    private fun reviewState(interval: Double, ease: Double) = SRSCardState(
        key = "k",
        phase = SRSPhase.review,
        interval = interval,
        ease = ease,
        reps = 3,
        lapses = 0,
        learningStep = 0,
        due = now,
        lastReviewed = null,
    )

    private val fresh get() = SRSCardState.newCard("k", now)

    @Test
    fun testNewCardGoodWalksLearningStepsThenGraduates() {
        val s1 = updateSRS(fresh, SRSGrade.good, now)
        assertEquals(SRSPhase.learning, s1.phase)
        assertEquals(1, s1.learningStep)
        assertEquals(600.0, dueOffset(s1), 0.001)

        val s2 = updateSRS(s1, SRSGrade.good, now)
        assertEquals(SRSPhase.review, s2.phase)
        assertEquals(1.0, s2.interval, 1e-9)
        assertEquals(day, dueOffset(s2), 0.001)
        assertTrue(s2.reps >= 1)
    }

    @Test
    fun testNewCardEasyGraduatesImmediately() {
        val s = updateSRS(fresh, SRSGrade.easy, now)
        assertEquals(SRSPhase.review, s.phase)
        assertEquals(4.0, s.interval, 1e-9)
        assertEquals(4 * day, dueOffset(s), 0.001)
    }

    @Test
    fun testKnownCardStartsInReviewAndIsDueNow() {
        val s = SRSCardState.knownCard("k", now)
        assertEquals(SRSPhase.review, s.phase)
        assertEquals(SRSConfig.default.knownCardInterval, s.interval, 1e-9)
        assertEquals(0.0, dueOffset(s), 0.001)
    }

    @Test
    fun testKnownCardGoodGoesOutAboutAWeekNotTenMinutes() {
        val s = updateSRS(SRSCardState.knownCard("k", now), SRSGrade.good, now)
        assertEquals(SRSPhase.review, s.phase)
        assertEquals(7.5, s.interval, 1e-9)
        assertEquals(7.5 * day, dueOffset(s), 0.001)
    }

    @Test
    fun testJustLearntIsFirstDueAfterTheKnownInterval() {
        val s = SRSCardState.justLearnt("k", now)
        assertEquals(SRSPhase.review, s.phase)
        assertEquals(SRSConfig.default.knownCardInterval * day, dueOffset(s), 0.001)
        assertTrue(s.isUngraded)
    }

    @Test
    fun testGradingClearsUngraded() {
        val s = updateSRS(SRSCardState.justLearnt("k", now), SRSGrade.good, now)
        assertFalse(s.isUngraded)
    }

    @Test
    fun testKnownCardAgainLapsesBackToLearning() {
        val s = updateSRS(SRSCardState.knownCard("k", now), SRSGrade.again, now)
        assertEquals(SRSPhase.learning, s.phase)
        assertEquals(1, s.lapses)
    }

    @Test
    fun testNewCardAgainResetsToFirstStep() {
        val s = updateSRS(fresh, SRSGrade.again, now)
        assertEquals(SRSPhase.learning, s.phase)
        assertEquals(0, s.learningStep)
        assertEquals(60.0, dueOffset(s), 0.001)
    }

    @Test
    fun testNewCardHardSitsBetweenAgainAndGood() {
        val s = updateSRS(fresh, SRSGrade.hard, now)
        assertEquals(SRSPhase.learning, s.phase)
        assertEquals(0, s.learningStep)
        assertEquals(330.0, dueOffset(s), 0.001)
    }

    @Test
    fun testReviewGoodMultipliesByEase() {
        val s = updateSRS(reviewState(10.0, 2.5), SRSGrade.good, now)
        assertEquals(25.0, s.interval, 1e-9)
        assertEquals(4, s.reps)
    }

    @Test
    fun testReviewHardTrimsEaseAndScales() {
        val s = updateSRS(reviewState(10.0, 2.5), SRSGrade.hard, now)
        assertEquals(2.35, s.ease, 1e-9)
        assertEquals(12.0, s.interval, 1e-9)
    }

    @Test
    fun testReviewEasyAppliesBonusBeforeInterval() {
        val s = updateSRS(reviewState(10.0, 2.5), SRSGrade.easy, now)
        assertEquals(2.65, s.ease, 1e-9)
        assertEquals(10 * 2.65 * 1.3, s.interval, 1e-9)
    }

    @Test
    fun testReviewAgainLapsesBackToLearning() {
        val s = updateSRS(reviewState(10.0, 2.5), SRSGrade.again, now)
        assertEquals(SRSPhase.learning, s.phase)
        assertEquals(1, s.lapses)
        assertEquals(2.3, s.ease, 1e-9)
        assertEquals(60.0, dueOffset(s), 0.001)
    }

    @Test
    fun testEaseNeverDropsBelowFloor() {
        val hard = updateSRS(reviewState(5.0, 1.3), SRSGrade.hard, now)
        assertEquals(1.3, hard.ease, 1e-9)
        val again = updateSRS(reviewState(5.0, 1.3), SRSGrade.again, now)
        assertEquals(1.3, again.ease, 1e-9)
    }

    @Test
    fun testSuggestedGrade() {
        assertEquals(SRSGrade.again, suggestedGrade(false, 0))
        assertEquals(SRSGrade.good, suggestedGrade(true, 0))
        assertEquals(SRSGrade.hard, suggestedGrade(true, 3))
    }

    @Test
    fun testPredictedIntervalLabelsForFreshCard() {
        assertEquals("1m", predictedIntervalLabel(fresh, SRSGrade.again, now))
        assertEquals("5m", predictedIntervalLabel(fresh, SRSGrade.hard, now))
        assertEquals("10m", predictedIntervalLabel(fresh, SRSGrade.good, now))
        assertEquals("4d", predictedIntervalLabel(fresh, SRSGrade.easy, now))
    }

    @Test
    fun testRandomWalkKeepsInvariants() {
        val rng = SplitMix64(0x5EED1234uL)
        val grades = SRSGrade.entries
        repeat(3_000) {
            var s = fresh
            repeat(rng.nextInt(1, 31)) {
                s = updateSRS(s, grades.random(rng), now)
                assertTrue(s.ease >= 1.3 - 1e-9)
                assertTrue(dueOffset(s) >= -1e-6)
                assertTrue(s.reps >= 0)
                assertTrue(s.lapses >= 0)
                if (s.phase == SRSPhase.review) assertTrue(s.interval >= 1.0 - 1e-9)
            }
        }
    }
}
