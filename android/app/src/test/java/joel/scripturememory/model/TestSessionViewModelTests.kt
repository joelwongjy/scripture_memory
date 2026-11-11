package joel.scripturememory.model

import kotlinx.serialization.json.Json
import kotlinx.serialization.json.jsonObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

class TestSessionViewModelTests {

    private val v1 = verse(1, title = "One", text = "alpha beta")
    private val v2 = verse(2, title = "Two", text = "gamma")
    private val verses = listOf(v1, v2)
    private lateinit var clock: TestClock
    private lateinit var store: InMemoryStore

    @Before
    fun setUp() {
        clock = TestClock(Date.fromTimeIntervalSince1970(1_800_000_000.0))
        store = InMemoryStore()
        installModel(clock, store)
    }

    private fun setMode(mode: StudyMode) {
        AppDefaults.standard.putString(StudyMode.storageKey, mode.rawValue)
    }

    private fun session(kind: SessionKind = SessionKind.custom, deck: List<Verse> = verses) =
        TestSessionViewModel(deck, kind)

    private fun submit(m: TestSessionViewModel, title: String, verse: String): SubmitResult? {
        m.titleInput = title
        m.verseInput = verse
        return m.handleSubmit()
    }

    @Test
    fun onlyEntireVerseModeCountsMistakes() {
        val m = session()
        m.recordMistake()
        assertEquals(0, m.mistakes(1))
        setMode(StudyMode.submit)
        m.recordMistake()
        assertEquals(1, m.mistakes(1))
    }

    @Test
    fun wrongLettersAndWordsCountAsMissesWithoutScoring() {
        val m = session()
        m.processFirstLetterInput("x")
        m.processFirstLetterInput("o")
        assertEquals(1, m.misses)
        m.processFullWordInput("delta ")
        assertEquals(2, m.misses)
        assertEquals(0, m.mistakes(1))
    }

    @Test
    fun mistakesStopAtFivePerVerse() {
        setMode(StudyMode.submit)
        val m = session()
        repeat(9) { m.recordMistake() }
        assertEquals(5, m.mistakes(1))
        assertEquals(-5, m.sessionScore)
    }

    @Test
    fun submitCountsEveryWrongWordAndRemembersPerfectCards() {
        setMode(StudyMode.submit)
        val m = session()
        submit(m, "One", "alpha wrong extra")
        assertEquals(2, m.mistakes(1))
        assertTrue(1 !in m.completedVerseIds)

        m.retrySubmit()
        assertEquals(0, m.mistakes(1))

        submit(m, "One", "alpha beta")
        assertEquals(0, m.mistakes(1))
        assertTrue(1 in m.completedVerseIds)
        assertEquals(1, m.perfectCount)
    }

    @Test
    fun sessionIsCompleteOnlyWhenEveryCardIs() {
        setMode(StudyMode.submit)
        val m = session()
        assertFalse(m.isSessionComplete)
        submit(m, "One", "alpha beta")
        assertFalse(m.isSessionComplete)
        m.goForward()
        submit(m, "Two", "gamma")
        assertTrue(m.isSessionComplete)
        assertEquals(2, m.completedCount)
    }

    @Test
    fun anImperfectSubmissionCountsAsDoneButNotComplete() {
        setMode(StudyMode.submit)
        val m = session()
        submit(m, "One", "wrong")
        assertEquals(1, m.completedCount)
        assertEquals(0, m.perfectCount)
        assertFalse(m.isSessionComplete)
    }

    @Test
    fun anEmptySessionIsNeverComplete() {
        assertFalse(session(deck = emptyList()).isSessionComplete)
    }

    @Test
    fun progressSurvivesLeavingAndComingBack() {
        val m = session()
        m.processFirstLetterInput("o")
        m.processFirstLetterInput("a")

        val back = session()
        assertEquals(1, back.revealedCount(1, CardSection.title))
        assertEquals(1, back.revealedCount(1, CardSection.verse))
        assertEquals(0, back.currentIndex)
        assertEquals(CardSection.verse, back.activeSection)
    }

    @Test
    fun restoreJumpsToTheFirstIncompleteCard() {
        val m = session()
        listOf("o", "a", "b").forEach { m.processFirstLetterInput(it) }
        assertEquals(1, session().currentIndex)
    }

    @Test
    fun restoreKeepsTheSavedIndexWhenEverythingIsDone() {
        val m = session()
        listOf("o", "a", "b").forEach { m.processFirstLetterInput(it) }
        m.goForward()
        listOf("t", "g").forEach { m.processFirstLetterInput(it) }
        assertEquals(1, session().currentIndex)
    }

    @Test
    fun aSavedIndexPastTheEndIsClamped() {
        store.putString(
            "currentSessionProgress",
            """{"currentIndex":9,"mistakeCounts":{},"titleRevealedCounts":{"1":1,"2":1},
            "verseRevealedCounts":{"1":2,"2":1},"completedVerseIds":[]}""",
        )
        assertEquals(1, session().currentIndex)
    }

    @Test
    fun slotsAreSeparateAndPracticeIsNeverSaved() {
        session(SessionKind.custom).processFirstLetterInput("o")
        assertNotNull(store.getString("currentSessionProgress"))
        assertNull(store.getString("srsSessionProgress"))
        assertEquals(0, session(SessionKind.srs).revealedCount(1, CardSection.title))

        val before = store.values.toMap()
        session(SessionKind.pack).processFirstLetterInput("o")
        assertEquals(before, store.values.filterKeys { it in before })
        assertEquals(0, session(SessionKind.pack).revealedCount(1, CardSection.title))
    }

    @Test
    fun savedJsonUsesTheIosFieldNames() {
        setMode(StudyMode.submit)
        val m = session()
        submit(m, "One", "alpha wrong")
        val saved = Json.parseToJsonElement(store.getString("currentSessionProgress")!!).jsonObject
        assertEquals(
            setOf(
                "currentIndex",
                "mistakeCounts",
                "titleRevealedCounts",
                "verseRevealedCounts",
                "completedVerseIds",
                "submitResultsSnapshot",
            ),
            saved.keys,
        )
    }

    @Test
    fun anEmptySnapshotIsLeftOutLikeIos() {
        session().saveProgress()
        val saved = Json.parseToJsonElement(store.getString("currentSessionProgress")!!).jsonObject
        assertFalse("submitResultsSnapshot" in saved)
    }

    @Test
    fun readsASessionSavedByIos() {
        setMode(StudyMode.submit)
        store.putString(
            "srsSessionProgress",
            """{"completedVerseIds":["1"],"currentIndex":0,"mistakeCounts":{"2":3},
            "submitResultsSnapshot":{"2":{"titleDiffs":[{"kind":"c","text":"Two"}],
            "verseDiffs":[{"correction":"gamma","kind":"w","text":"gama"}]}},
            "titleRevealedCounts":{},"verseRevealedCounts":{}}""",
        )
        val m = session(SessionKind.srs)
        assertEquals(3, m.mistakes(2))
        assertEquals("gamma", m.submitResults.getValue(2).verseDiffs[0].correction)
        assertTrue(m.submitResults.getValue(1).isAllCorrect)
    }

    @Test
    fun olderSavesRebuildAllGreenDiffsForPerfectCards() {
        setMode(StudyMode.submit)
        store.putString(
            "currentSessionProgress",
            """{"currentIndex":0,"mistakeCounts":{},"titleRevealedCounts":{},
            "verseRevealedCounts":{},"completedVerseIds":["1","99","x"]}""",
        )
        val m = session()
        assertEquals(setOf(1), m.submitResults.keys)
        assertEquals(listOf("alpha", "beta"), m.submitResults.getValue(1).verseDiffs.map { it.text })
        assertEquals(1, m.currentIndex)
    }

    @Test
    fun aCorruptSaveStartsFresh() {
        store.putString("currentSessionProgress", "{broken")
        assertEquals(0, session().currentIndex)
    }

    @Test
    fun clearingOnlyWipesThatKind() {
        session(SessionKind.custom).processFirstLetterInput("o")
        session(SessionKind.srs).processFirstLetterInput("o")
        TestSessionViewModel.clearPersistedProgress(SessionKind.custom)
        assertNull(store.getString("currentSessionProgress"))
        assertNotNull(store.getString("srsSessionProgress"))
        TestSessionViewModel.clearPersistedProgress(SessionKind.pack)
    }

    @Test
    fun savedCompletedCountReadsTheSlot() {
        assertEquals(0, TestSessionViewModel.savedCompletedCount(SessionKind.custom, verses))
        val m = session()
        listOf("o", "a", "b").forEach { m.processFirstLetterInput(it) }
        assertEquals(1, TestSessionViewModel.savedCompletedCount(SessionKind.custom, verses))
        assertEquals(0, TestSessionViewModel.savedCompletedCount(SessionKind.pack, verses))
    }

    @Test
    fun resetClearsEverythingAndSaves() {
        setMode(StudyMode.submit)
        val m = session()
        submit(m, "One", "wrong")
        m.goForward()
        m.titleInput = "left over"
        m.resetAllProgress()
        assertEquals(0, m.currentIndex)
        assertEquals(CardSection.title, m.activeSection)
        assertTrue(m.mistakeCounts.isEmpty())
        assertTrue(m.submitResults.isEmpty())
        assertEquals("", m.titleInput)
        assertEquals(0, session().mistakes(1))
    }

    @Test
    fun cardLabelUsesTheFooter() {
        assertEquals("Pack", session().cardLabel(v1))
    }

    @Test
    fun firstRatingSchedulesAndRecordsTheDay() {
        val m = session(SessionKind.srs)
        m.grade(SRSGrade.good)
        assertEquals(SRSGrade.good, m.sessionGrades[1])
        assertEquals(listOf(1), m.gradedOrder)
        assertEquals(1, SRSStore.shared.state(v1)!!.learningStep)
        assertEquals(1, SRSStore.shared.newIntroducedToday())
        assertTrue(StreakStore.shared.isTodayDone)
        assertEquals(false, m.unscheduledAtStart[1])
    }

    @Test
    fun reratingRecomputesFromThePreGradeStateAndUsesNoSecondSlot() {
        val m = session(SessionKind.srs)
        m.grade(SRSGrade.good)
        m.grade(SRSGrade.easy)
        val state = SRSStore.shared.state(v1)!!
        assertEquals(SRSPhase.review, state.phase)
        assertEquals(4.0, state.interval, 1e-9)
        assertEquals(1, SRSStore.shared.newIntroducedToday())
        assertEquals(listOf(1), m.gradedOrder)
    }

    @Test
    fun aLearntVerseWithNoScheduleIsGradedAsKnown() {
        LearningStore.shared.setProgress(v2, verses)
        val m = session(SessionKind.srs)
        m.grade(SRSGrade.good)
        assertEquals(7.5, SRSStore.shared.state(v1)!!.interval, 1e-9)
        assertEquals(0, SRSStore.shared.newIntroducedToday())
        assertEquals(true, m.unscheduledAtStart[1])
    }

    @Test
    fun undoOfANewCardRemovesItAndHandsTheSlotBack() {
        val m = session(SessionKind.srs)
        m.grade(SRSGrade.good)
        assertEquals(0, m.undoLastGrade())
        assertNull(SRSStore.shared.state(v1))
        assertEquals(0, SRSStore.shared.newIntroducedToday())
        assertTrue(m.sessionGrades.isEmpty())
        assertTrue(m.gradedOrder.isEmpty())
        assertTrue(m.preGradeStates.isEmpty())
        assertTrue(m.unscheduledAtStart.isEmpty())
    }

    @Test
    fun undoOfAKnownCardTakesNoSlotBack() {
        SRSStore.shared.grade(v2, SRSGrade.good)
        LearningStore.shared.setProgress(v2, verses)
        val m = session(SessionKind.srs)
        m.grade(SRSGrade.good)
        assertEquals(1, SRSStore.shared.reviewedToday())
        m.undoLastGrade()
        assertNull(SRSStore.shared.state(v1))
        assertEquals(1, SRSStore.shared.newIntroducedToday())
        assertEquals(0, SRSStore.shared.reviewedToday())
    }

    @Test
    fun undoOfAScheduledCardRestoresItsScheduleAndReviewSlot() {
        SRSStore.shared.grade(v1, SRSGrade.easy)
        val prior = SRSStore.shared.state(v1)
        val m = session(SessionKind.srs)
        m.grade(SRSGrade.good)
        assertEquals(1, SRSStore.shared.reviewedToday())
        m.undoLastGrade()
        assertEquals(prior, SRSStore.shared.state(v1))
        assertEquals(0, SRSStore.shared.reviewedToday())
    }

    @Test
    fun undoWalksBackThroughRatingsInOrder() {
        val m = session(SessionKind.srs)
        m.grade(SRSGrade.good)
        m.goForward()
        m.grade(SRSGrade.good)
        assertEquals(1, m.undoLastGrade())
        assertEquals(0, m.undoLastGrade())
        assertNull(m.undoLastGrade())
    }

    @Test
    fun goodOnTheCurrentVerseMovesTheCursorAndUndoPutsItBack() {
        val first = packsNIV84[0].verses[0]
        val second = packsNIV84[0].verses[1]
        val learning = LearningStore.shared
        val m = TestSessionViewModel(listOf(first, second), SessionKind.srs)

        m.grade(SRSGrade.good)
        assertTrue(learning.isLearnt(first))
        assertEquals(second.srsKey, learning.currentKey)
        assertTrue(first.id in m.autoLearntIds)

        m.undoLastGrade()
        assertFalse(learning.isLearnt(first))
        assertEquals(first.srsKey, learning.currentKey)
        assertTrue(m.autoLearntIds.isEmpty())
    }

    @Test
    fun hardDoesNotMoveTheCursor() {
        val first = packsNIV84[0].verses[0]
        val m = TestSessionViewModel(listOf(first), SessionKind.srs)
        m.grade(SRSGrade.hard)
        assertFalse(LearningStore.shared.isLearnt(first))
    }

    @Test
    fun reratingAfterTheCursorMovedStaysOnTheCapturedState() {
        val first = packsNIV84[0].verses[0]
        val m = TestSessionViewModel(listOf(first), SessionKind.srs)
        m.grade(SRSGrade.good)
        m.grade(SRSGrade.hard)
        val prior = SRSCardState.newCard(first.srsKey, clock.now())
        assertEquals(updateSRS(prior, SRSGrade.hard, clock.now()), SRSStore.shared.state(first))
    }

    @Test
    fun displayStateIsThePreGradeStateOnceRated() {
        val m = session(SessionKind.srs)
        assertEquals(SRSCardState.newCard(v1.srsKey, clock.now()), m.displayState(v1))
        m.grade(SRSGrade.good)
        clock.advance(100.0)
        assertEquals(m.preGradeStates[1], m.displayState(v1))
    }

    @Test
    fun displayStateForALearntVerseIsKnown() {
        LearningStore.shared.setProgress(v2, verses)
        val m = session(SessionKind.srs)
        assertEquals(SRSPhase.review, m.displayState(v1).phase)
    }

    @Test
    fun displayStateUsesTheStoredSchedule() {
        SRSStore.shared.grade(v1, SRSGrade.easy)
        assertEquals(SRSStore.shared.state(v1), session(SessionKind.srs).displayState(v1))
    }

    @Test
    fun suggestionsExistOnlyInEntireVerseMode() {
        val m = session(SessionKind.srs)
        assertNull(m.suggestedGradeFor(v1))

        setMode(StudyMode.submit)
        assertEquals(SRSGrade.again, m.suggestedGradeFor(v1))
        submit(m, "One", "alpha beta")
        assertEquals(SRSGrade.good, m.suggestedGradeFor(v1))
        m.notePeek(v1)
        assertEquals(SRSGrade.again, m.suggestedGradeFor(v1))
    }

    @Test
    fun aRatingWithNoCurrentCardDoesNothing() {
        val m = session(SessionKind.srs, emptyList())
        m.grade(SRSGrade.good)
        assertTrue(m.sessionGrades.isEmpty())
        assertNull(m.undoLastGrade())
    }

    @Test
    fun allCardsGradedNeedsEveryCard() {
        val m = session(SessionKind.srs)
        assertFalse(m.allCardsGraded)
        m.grade(SRSGrade.good)
        assertFalse(m.allCardsGraded)
        m.goForward()
        m.grade(SRSGrade.good)
        assertTrue(m.allCardsGraded)
    }

    @Test
    fun testPracticeHoldsTheWholePackAndOpensOnTheChosenCard() {
        val session = TestSession.practice(verses, 1, PracticeEntry.titleButton)!!
        assertEquals(verses, session.verses)
        assertEquals(1, session.startIndex)
        assertEquals(v2, TestSessionViewModel(session.verses, session.kind, session.startIndex).currentVerse)
    }

    @Test
    fun testPracticeSavesNoProgress() {
        val session = TestSession.practice(verses, 1, PracticeEntry.titleButton)!!
        TestSessionViewModel(session.verses, session.kind, session.startIndex).saveProgress()
        assertEquals(0, TestSessionViewModel(session.verses, session.kind).currentIndex)
    }
}
