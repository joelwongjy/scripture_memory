package joel.scripturememory.model

import java.time.DayOfWeek
import java.time.ZoneId
import java.util.Locale
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.jsonObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

class SRSStoreTests {

    private val day = SRSStore.secondsPerDay
    private lateinit var clock: TestClock
    private lateinit var store: InMemoryStore
    private lateinit var srs: SRSStore
    private val v = verse(1)
    private val now get() = clock.now()

    @Before
    fun setUp() {
        clock = TestClock(Date.fromTimeIntervalSince1970(1_800_000_000.0))
        store = InMemoryStore()
        installModel(clock, store)
        srs = SRSStore.shared
    }

    private fun reloaded() = SRSStore(ProgressStorage(store))

    @Test
    fun firstGradeOfANewCardBumpsTheCounter() {
        srs.grade(v, SRSGrade.good)
        assertEquals(1, srs.newIntroducedToday())
        assertEquals(mapOf("Pack" to 1), srs.dailyNewByDate[SRSStore.dayKey(now)])
    }

    @Test
    fun laterGradesDoNotBumpTheCounter() {
        srs.grade(v, SRSGrade.good)
        srs.grade(v, SRSGrade.good)
        assertEquals(1, srs.newIntroducedToday())
    }

    @Test
    fun alreadyKnownCardSeedsReviewAndNeverTakesANewSlot() {
        val state = srs.grade(v, SRSGrade.good, alreadyKnew = true)
        assertEquals(SRSPhase.review, state.phase)
        assertEquals(7.5, state.interval, 1e-9)
        assertEquals(0, srs.newIntroducedToday())
        assertEquals(1, srs.reviewedToday())
    }

    @Test
    fun verseWithoutPackDoesNotCount() {
        srs.grade(verse(2, packName = ""), SRSGrade.good)
        assertEquals(0, srs.newIntroducedToday())
    }

    @Test
    fun onlyCardsGradedFromReviewCountAsReviewed() {
        srs.grade(v, SRSGrade.easy)
        assertEquals(0, srs.reviewedToday())
        srs.grade(v, SRSGrade.good)
        assertEquals(1, srs.reviewedToday())
        srs.grade(v, SRSGrade.good)
        assertEquals(1, srs.reviewedToday())
    }

    @Test
    fun regradeComputesFromThePriorStateWithoutCompounding() {
        val prior = SRSCardState.knownCard(v.srsKey, now)
        srs.grade(v, SRSGrade.good, alreadyKnew = true)
        val again = srs.regrade(v, SRSGrade.easy, prior)
        assertEquals(updateSRS(prior, SRSGrade.easy, now), again)
        assertEquals(again, srs.state(v))
    }

    @Test
    fun revertToNothingRemovesTheCardAndGivesTheSlotBack() {
        srs.grade(v, SRSGrade.good)
        srs.revert(v, null, wasNewlyIntroduced = true)
        assertNull(srs.state(v))
        assertEquals(0, srs.newIntroducedToday())
    }

    @Test
    fun revertFloorsTheCounterAtZero() {
        srs.revert(v, null, wasNewlyIntroduced = true)
        assertEquals(0, srs.newIntroducedToday())
        srs.grade(v, SRSGrade.good)
        srs.revert(v, null, wasNewlyIntroduced = true)
        srs.revert(v, null, wasNewlyIntroduced = true)
        assertEquals(0, srs.newIntroducedToday())
    }

    @Test
    fun revertGivesTheReviewSlotBack() {
        srs.grade(v, SRSGrade.easy)
        val prior = srs.state(v)
        srs.grade(v, SRSGrade.good)
        assertEquals(1, srs.reviewedToday())
        srs.revert(v, prior, wasNewlyIntroduced = false, wasReview = true)
        assertEquals(0, srs.reviewedToday())
        assertEquals(prior, srs.state(v))
    }

    @Test
    fun scheduleLearntNeverOverwritesARealSchedule() {
        srs.grade(v, SRSGrade.good)
        val graded = srs.state(v)
        srs.scheduleLearnt(v)
        assertEquals(graded, srs.state(v))
    }

    @Test
    fun scheduleLearntIsDueAfterTheKnownInterval() {
        srs.scheduleLearnt(v)
        assertEquals(3 * day, srs.state(v)!!.due.timeIntervalSince(now), 0.001)
        assertTrue(srs.state(v)!!.isUngraded)
    }

    @Test
    fun unscheduleOnlyDropsUngradedCards() {
        srs.scheduleLearnt(v)
        srs.unscheduleLearnt(v)
        assertNull(srs.state(v))

        srs.grade(v, SRSGrade.good)
        srs.unscheduleLearnt(v)
        assertNotNull(srs.state(v))
    }

    @Test
    fun dueCardsIncludesExactlyDueAndNotFuture() {
        srs.scheduleLearnt(v)
        val due = srs.state(v)!!.due
        assertEquals(listOf(v), srs.dueCards(listOf(v), due))
        assertEquals(emptyList<Verse>(), srs.dueCards(listOf(v), due.addingTimeInterval(-0.001)))
    }

    @Test
    fun activePacksIsAnOptOutThatKeepsOrder() {
        val packs = listOf(pack("A", 1), pack("B", 2), pack("C", 3))
        srs.setActive("B", false)
        assertEquals(listOf("A", "C"), srs.activePacks(packs).map { it.name })
        srs.setActive("B", true)
        assertEquals(listOf("A", "B", "C"), srs.activePacks(packs).map { it.name })
    }

    @Test
    fun resetAllKeepsInactivePacks() {
        srs.setActive("B", false)
        srs.grade(v, SRSGrade.good)
        srs.resetAll()
        assertTrue(srs.states.isEmpty())
        assertTrue(srs.dailyNewByDate.isEmpty())
        assertFalse(srs.isActive("B"))
        assertFalse(reloaded().isActive("B"))
    }

    @Test
    fun weekCountUsesTheLocalesFirstWeekday() {
        clock.zone = ZoneId.of("UTC")
        val sunday = Date.from(java.time.Instant.parse("2027-02-07T12:00:00Z"))
        val saturdayBefore = sunday.addingTimeInterval(-day)
        srs.grade(verse(1), SRSGrade.good, now = saturdayBefore)
        srs.grade(verse(2), SRSGrade.good, now = sunday)

        clock.firstDayOfWeek = DayOfWeek.SUNDAY
        assertEquals(1, srs.newIntroducedThisWeek(sunday))
        clock.firstDayOfWeek = DayOfWeek.MONDAY
        assertEquals(2, srs.newIntroducedThisWeek(sunday))
    }

    @Test
    fun newIntroducedFollowsTheCapUnit() {
        srs.grade(verse(1), SRSGrade.good, now = now.addingTimeInterval(-3600.0))
        val tomorrow = now.addingTimeInterval(day)
        assertEquals(0, srs.newIntroduced(NewCapUnit.day, tomorrow))
        assertEquals(srs.newIntroducedThisWeek(tomorrow), srs.newIntroduced(NewCapUnit.week, tomorrow))
    }

    @Test
    fun dayKeyRollsAtLocalMidnightNotUtc() {
        clock.zone = ZoneId.of("Asia/Singapore")
        val beforeMidnight = Date.from(java.time.Instant.parse("2027-02-07T15:59:59Z"))
        val afterMidnight = Date.from(java.time.Instant.parse("2027-02-07T16:00:00Z"))
        assertEquals("2027-02-07", SRSStore.dayKey(beforeMidnight))
        assertEquals("2027-02-08", SRSStore.dayKey(afterMidnight))
    }

    @Test
    fun dayKeyUsesAsciiDigitsInEveryLocale() {
        val previous = Locale.getDefault()
        try {
            Locale.setDefault(Locale.forLanguageTag("ar-SA-u-nu-arab"))
            assertEquals("2027-02-07", SRSStore.dayKey(Date.from(java.time.Instant.parse("2027-02-07T12:00:00Z"))))
        } finally {
            Locale.setDefault(previous)
        }
    }

    @Test
    fun countsOlderThanFourteenDaysArePruned() {
        val cutoffDay = now.addingTimeInterval(-14 * day)
        val tooOld = now.addingTimeInterval(-15 * day)
        srs.grade(verse(1), SRSGrade.good, now = cutoffDay)
        srs.grade(verse(2), SRSGrade.good, now = tooOld)
        assertEquals(setOf(SRSStore.dayKey(cutoffDay)), srs.dailyNewByDate.keys)
    }

    @Test
    fun everythingSurvivesAReload() {
        srs.grade(verse(1), SRSGrade.easy)
        srs.grade(verse(1), SRSGrade.good)
        srs.grade(verse(2), SRSGrade.again)
        srs.setActive("Z", false)

        val fresh = reloaded()
        assertEquals(srs.states, fresh.states)
        assertEquals(srs.dailyNewByDate, fresh.dailyNewByDate)
        assertEquals(srs.reviewedByDate, fresh.reviewedByDate)
        assertEquals(srs.inactivePackNames, fresh.inactivePackNames)
    }

    @Test
    fun storedJsonUsesTheIosKeysAndOmitsNil() {
        srs.scheduleLearnt(v)
        val raw = store.getString("srs.cardStates.v1")!!
        val record = Json.parseToJsonElement(raw).jsonObject.getValue(v.srsKey).jsonObject
        assertEquals(
            setOf("key", "phase", "interval", "ease", "reps", "lapses", "learningStep", "due"),
            record.keys,
        )
        assertEquals("\"review\"", record.getValue("phase").toString())
    }

    @Test
    fun readsJsonWrittenByIos() {
        val ios = """
            {"uid-1":{"due":815356800.5,"ease":2.35,"interval":12,"key":"uid-1","lapses":1,
            "lastReviewed":815000000,"learningStep":0,"phase":"review","reps":4}}
        """.trimIndent()
        store.putString("srs.cardStates.v1", ios)
        store.putString("srs.dailyNewByDate.v1", """{"2027-02-07":{"TMS 60":2}}""")
        store.putString("srs.reviewedByDate.v1", """{"2027-02-07":["uid-1"]}""")
        store.putString("srs.inactivePackNames.v1", """["DEP 2: Quiet Time"]""")

        val fresh = reloaded()
        val state = fresh.states.getValue("uid-1")
        assertEquals(815356800.5, state.due.timeIntervalSinceReferenceDate, 0.0)
        assertEquals(12.0, state.interval, 0.0)
        assertEquals(815000000.0, state.lastReviewed!!.timeIntervalSinceReferenceDate, 0.0)
        assertEquals(SRSPhase.review, state.phase)
        assertEquals(mapOf("TMS 60" to 2), fresh.dailyNewByDate["2027-02-07"])
        assertEquals(setOf("uid-1"), fresh.reviewedByDate["2027-02-07"])
        assertFalse(fresh.isActive("DEP 2: Quiet Time"))
    }

    @Test
    fun corruptStoredJsonIsIgnored() {
        store.putString("srs.cardStates.v1", "{not json")
        assertTrue(reloaded().states.isEmpty())
    }
}
