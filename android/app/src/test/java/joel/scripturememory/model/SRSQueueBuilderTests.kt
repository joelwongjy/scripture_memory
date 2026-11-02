package joel.scripturememory.model

import joel.scripturememory.model.SRSQueueBuilder.NewCardPolicy
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

class SRSQueueBuilderTests {

    private val day = SRSStore.secondsPerDay
    private lateinit var clock: TestClock
    private lateinit var srs: SRSStore
    private val now get() = clock.now()
    private val noPolicy = NewCardPolicy(emptySet(), true)
    private val bigCap = NewCardCap(100, NewCapUnit.day)
    private val noNew = NewCardCap(0, NewCapUnit.day)

    @Before
    fun setUp() {
        clock = TestClock(Date.fromTimeIntervalSince1970(1_800_000_000.0))
        installModel(clock)
        srs = SRSStore.shared
    }

    private fun ids(verses: List<Verse>) = verses.map { it.id }

    private fun makeLearning(v: Verse) {
        srs.grade(v, SRSGrade.again, now = now.addingTimeInterval(-3600.0))
    }

    private fun makeReviewDue(v: Verse, overdueBy: Double) {
        val past = now.addingTimeInterval(-overdueBy - 4 * day)
        srs.grade(v, SRSGrade.easy, now = past)
    }

    @Test
    fun orderIsLearningThenReviewThenNew() {
        val a = pack("A", 1, 2, 3)
        val b = pack("B", 4, 5)
        makeReviewDue(a.verses[0], 100.0)
        makeLearning(a.verses[1])
        val session = SRSQueueBuilder.buildAllPacksSession(listOf(a, b), srs, bigCap, 50, noPolicy, now)
        assertEquals(listOf(2, 1, 3, 4, 5), ids(session))
    }

    @Test
    fun reviewsComeMostOverdueFirstAcrossPacks() {
        val a = pack("A", 1, 2)
        val b = pack("B", 3)
        makeReviewDue(a.verses[0], 100.0)
        makeReviewDue(a.verses[1], 300.0)
        makeReviewDue(b.verses[0], 200.0)
        val cards = SRSQueueBuilder.reviewCards(listOf(a, b), srs, 50, noPolicy, now)
        assertEquals(listOf(2, 3, 1), ids(cards))
    }

    @Test
    fun learningCardsAreNeverCapped() {
        val a = pack("A", 1, 2, 3, 4)
        a.verses.take(3).forEach(::makeLearning)
        makeReviewDue(a.verses[3], 10.0)
        val cards = SRSQueueBuilder.reviewCards(listOf(a), srs, 0, noPolicy, now)
        assertEquals(listOf(1, 2, 3), ids(cards))
    }

    @Test
    fun reviewCapCountsReviewsAlreadyAnsweredToday() {
        val a = pack("A", 1, 2, 3, 4)
        a.verses.forEach { makeReviewDue(it, 10.0) }
        srs.grade(a.verses[0], SRSGrade.good, now = now)
        val cards = SRSQueueBuilder.reviewCards(listOf(a), srs, 3, noPolicy, now)
        assertEquals(2, cards.size)
    }

    @Test
    fun capAlreadySpentLeavesNothingEvenWithBacklog() {
        val a = pack("A", 1, 2, 3)
        a.verses.take(2).forEach { makeReviewDue(it, 10.0) }
        srs.grade(a.verses[0], SRSGrade.good, now = now)
        val policy = NewCardPolicy(setOf(a.verses[2].srsKey), true)
        assertEquals(emptyList<Verse>(), SRSQueueBuilder.reviewCards(listOf(a), srs, 1, policy, now))
    }

    @Test
    fun oneSlotIsKeptForTheBacklogWhenReviewsWouldFillTheCap() {
        val a = pack("A", 1, 2, 3, 4)
        a.verses.take(3).forEach { makeReviewDue(it, 10.0) }
        val policy = NewCardPolicy(setOf(a.verses[3].srsKey), true)
        val cards = SRSQueueBuilder.reviewCards(listOf(a), srs, 2, policy, now)
        assertEquals(2, cards.size)
        assertEquals(4, cards.last().id)
    }

    @Test
    fun backlogFillsWhatReviewsLeave() {
        val a = pack("A", 1, 2, 3, 4)
        makeReviewDue(a.verses[0], 10.0)
        val learnt = a.verses.drop(1).map { it.srsKey }.toSet()
        val cards = SRSQueueBuilder.reviewCards(listOf(a), srs, 3, NewCardPolicy(learnt, true), now)
        assertEquals(listOf(1, 4, 3), ids(cards))
    }

    @Test
    fun backlogTakesTurnsFromTheLatestPackBackMostRecentFirst() {
        val a = pack("A", 1, 2, 3)
        val b = pack("B", 4, 5, 6)
        val learnt = listOf(1, 2, 4, 5).map { "uid-$it" }.toSet()
        val cards = SRSQueueBuilder.reviewCards(listOf(a, b), srs, 4, NewCardPolicy(learnt, true), now)
        assertEquals(listOf(5, 2, 4, 1), ids(cards))
    }

    @Test
    fun takingTurnsCarriesOnPastAShortList() {
        val a = pack("A", 1)
        val b = pack("B", 2, 3, 4)
        val learnt = listOf(1, 2, 3, 4).map { "uid-$it" }.toSet()
        val cards = SRSQueueBuilder.reviewCards(listOf(a, b), srs, 10, NewCardPolicy(learnt, true), now)
        assertEquals(listOf(4, 1, 3, 2), ids(cards))
    }

    @Test
    fun turningOffReviewsKnownHidesTheBacklogButNotFromNew() {
        val a = pack("A", 1, 2)
        val policy = NewCardPolicy(setOf(a.verses[0].srsKey), false)
        assertEquals(emptyList<Verse>(), policy.known(a.verses, srs))
        assertEquals(listOf(2), ids(policy.fresh(a.verses, srs)))
    }

    @Test
    fun learntVersesNeverTakeANewSlot() {
        val a = pack("A", 1, 2, 3)
        val policy = NewCardPolicy(setOf(a.verses[0].srsKey), true)
        val session = SRSQueueBuilder.buildAllPacksSession(
            listOf(a),
            srs,
            NewCardCap(1, NewCapUnit.day),
            0,
            policy,
            now,
        )
        assertEquals(listOf(2), ids(session))
    }

    @Test
    fun newCapIsGlobalAcrossPacksAndSpills() {
        val a = pack("A", 1, 2)
        val b = pack("B", 3, 4)
        val session = SRSQueueBuilder.buildAllPacksSession(
            listOf(a, b),
            srs,
            NewCardCap(3, NewCapUnit.day),
            10,
            noPolicy,
            now,
        )
        assertEquals(listOf(1, 2, 3), ids(session))
    }

    @Test
    fun weeklyCapRemembersEarlierDaysAndDailyDoesNot() {
        val a = pack("A", 1, 2, 3, 4)
        clock.firstDayOfWeek = java.time.DayOfWeek.SUNDAY
        val weekStart = java.time.Instant.parse("2027-02-07T12:00:00Z")
        clock.date = Date.from(weekStart)
        srs.grade(a.verses[0], SRSGrade.good, now = now)
        val tuesday = now.addingTimeInterval(2 * day)
        assertEquals(1, SRSQueueBuilder.globalNewRemaining(srs, NewCardCap(2, NewCapUnit.week), tuesday))
        assertEquals(2, SRSQueueBuilder.globalNewRemaining(srs, NewCardCap(2, NewCapUnit.day), tuesday))
        val nextWeek = now.addingTimeInterval(7 * day)
        assertEquals(2, SRSQueueBuilder.globalNewRemaining(srs, NewCardCap(2, NewCapUnit.week), nextWeek))
    }

    @Test
    fun newRemainingNeverGoesNegative() {
        val a = pack("A", 1, 2)
        a.verses.forEach { srs.grade(it, SRSGrade.good, now = now) }
        assertEquals(0, SRSQueueBuilder.globalNewRemaining(srs, NewCardCap(1, NewCapUnit.day), now))
    }

    @Test
    fun dueSummaryAgreesWithTheSessionItCounts() {
        val a = pack("A", 1, 2, 3, 4, 5)
        val b = pack("B", 6, 7, 8)
        makeLearning(a.verses[0])
        makeReviewDue(a.verses[1], 10.0)
        makeReviewDue(a.verses[2], 20.0)
        val policy = NewCardPolicy(setOf("uid-4"), true)
        val cap = NewCardCap(10, NewCapUnit.week)
        val summary = SRSQueueBuilder.dueSummary(listOf(a, b), srs, cap, 2, policy, now)
        val session = SRSQueueBuilder.buildAllPacksSession(listOf(a, b), srs, cap, 2, policy, now)
        assertEquals(session.size, summary.total)
    }

    @Test
    fun dueSummaryNewIsBoundedByCandidates() {
        val a = pack("A", 1, 2)
        val summary = SRSQueueBuilder.dueSummary(listOf(a), srs, bigCap, 5, noPolicy, now)
        assertEquals(0, summary.review)
        assertEquals(2, summary.new)
    }

    @Test
    fun futureNowProjectsThatDaysFullCap() {
        val a = pack("A", 1, 2, 3)
        srs.grade(a.verses[0], SRSGrade.good, now = now)
        val cap = NewCardCap(1, NewCapUnit.day)
        assertEquals(0, SRSQueueBuilder.dueSummary(listOf(a), srs, cap, 5, noPolicy, now).new)
        val tomorrow = now.addingTimeInterval(day)
        assertEquals(1, SRSQueueBuilder.dueSummary(listOf(a), srs, cap, 5, noPolicy, tomorrow).new)
    }

    @Test
    fun defaultPolicyReadsTheLearningStoreAndTheSetting() {
        val a = pack("A", 1, 2)
        LearningStore.shared.setProgress(a.verses[1], a.verses)
        assertTrue(NewCardPolicy.current.reviewsKnown)
        assertEquals(setOf("uid-1"), NewCardPolicy.current.learntKeys)
        AppDefaults.standard.putBool(NewCardPolicy.reviewsKnownKey, false)
        assertFalse(NewCardPolicy.current.reviewsKnown)
    }

    @Test
    fun dailyReviewIsNilWhenNothingIsDue() {
        assertEquals(null, TestSession.dailyReview(emptyList(), noNew, 5))
        val session = TestSession.dailyReview(listOf(pack("A", 1)), bigCap, 5)
        assertEquals(SessionKind.srs, session?.kind)
    }
}
