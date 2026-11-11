package joel.scripturememory.model

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class AnalyticsEventTests {

    @Test
    fun testCountsAreSentAsRanges() {
        assertEquals("0", AnalyticsRange.count(0))
        assertEquals("1", AnalyticsRange.count(1))
        assertEquals("2-5", AnalyticsRange.count(5))
        assertEquals("6-10", AnalyticsRange.count(6))
        assertEquals("11-20", AnalyticsRange.count(20))
        assertEquals("21-50", AnalyticsRange.count(50))
        assertEquals("50+", AnalyticsRange.count(51))
    }

    @Test
    fun testDurationsAreSentAsRanges() {
        assertEquals("<30s", AnalyticsRange.duration(12.0))
        assertEquals("30s-1m", AnalyticsRange.duration(45.0))
        assertEquals("1-3m", AnalyticsRange.duration(120.0))
        assertEquals("3-10m", AnalyticsRange.duration(400.0))
        assertEquals("10-30m", AnalyticsRange.duration(900.0))
        assertEquals("30m+", AnalyticsRange.duration(4000.0))
    }

    @Test
    fun testSessionNamesFollowTheKind() {
        val start = StudySessionStart(StudySessionKind.review, 8, "firstLetter", false)
        assertEquals("Review.started", AnalyticsEvent.SessionStarted(start).name)
        val extra = start.copy(kind = StudySessionKind.extraRound)
        assertEquals("Review.extraRound.started", AnalyticsEvent.SessionStarted(extra).name)
        val end = StudySessionSummary(StudySessionKind.quiz, true, 3, 3, 70.0)
        assertEquals("Quiz.ended", AnalyticsEvent.SessionEnded(end).name)
    }

    @Test
    fun testReviewStartCarriesQueueMixOnlyForReviews() {
        val start = StudySessionStart(
            StudySessionKind.review,
            12,
            "fullWord",
            true,
            newCards = 2,
            learningCards = 1,
            dueCards = 9,
        )
        assertEquals("6-10", start.parameters["due"])
        assertEquals("2-5", start.parameters["new"])
        assertEquals("true", start.parameters["hardMode"])
        assertNull(start.copy(kind = StudySessionKind.quiz).parameters["due"])
    }

    @Test
    fun testReviewEndSendsRatingsAndQuizEndSendsMistakes() {
        val review = StudySessionSummary(
            StudySessionKind.review,
            false,
            10,
            4,
            200.0,
            again = 1,
            good = 3,
        )
        assertEquals("1", review.parameters["again"])
        assertEquals("2-5", review.parameters["good"])
        assertEquals("false", review.parameters["finished"])
        assertNull(review.parameters["mistakes"])

        val quiz = StudySessionSummary(StudySessionKind.quiz, true, 5, 5, 90.0)
        assertEquals("true", quiz.parameters["allCorrect"])
        val withMistakes = quiz.copy(mistakes = 2)
        assertEquals("false", withMistakes.parameters["allCorrect"])
        assertNull(withMistakes.parameters["again"])
    }

    @Test
    fun testOwnPackEventsCarryNoNamesOrText() {
        assertEquals(mapOf("source" to "pasted"), AnalyticsEvent.OwnVerseAdded(OwnVerseSource.pasted).parameters)
        assertEquals(
            mapOf("verses" to "21-50", "withHistory" to "1", "matched" to "0"),
            AnalyticsEvent.AnkiImported(verses = 34, withHistory = 1, matched = 0).parameters,
        )
        assertEquals(
            AnalyticsEvent.PackOpened(AnalyticsEvent.ownPackLabel, PackSource.shelf),
            AnalyticsEvent.PackOpened("Romans", PackSource.shelf).redactingPacks { it == "Romans" },
        )
    }

    @Test
    fun testSearchNeverCarriesTheQuery() {
        val event = AnalyticsEvent.SearchResultOpened(3, false)
        assertEquals(mapOf("rank" to "2-5", "matchedOn" to "text"), event.parameters)
    }

    @Test
    fun searchPerformedCarriesOnlyTheRange() {
        val search = AnalyticsEvent.SearchPerformed(results = 7)
        assertEquals("Search.performed", search.name)
        assertEquals(mapOf("results" to "6-10"), search.parameters)
    }

    @Test
    fun reviewStartSeparatesKnownCardsAndEarlierReviews() {
        val review = StudySessionStart(
            kind = StudySessionKind.review,
            cards = 7,
            studyMode = "firstLetter",
            hardMode = false,
            newCards = 2,
            knownCards = 5,
            reviewedToday = 3,
        )
        assertEquals("2-5", review.parameters["new"])
        assertEquals("2-5", review.parameters["known"])
        assertEquals("2-5", review.parameters["reviewedToday"])
        val practice = review.copy(kind = StudySessionKind.practice)
        assertEquals(null, practice.parameters["known"])
        assertEquals(null, practice.parameters["reviewedToday"])
    }

    @Test
    fun onlyPlayInstallsOnRealDevicesAreLive() {
        val play = AnalyticsBuild.playStore
        assertEquals(true, AnalyticsBuild.isTest(isDebug = true, isEmulator = false, installer = play))
        assertEquals(true, AnalyticsBuild.isTest(isDebug = false, isEmulator = true, installer = play))
        assertEquals(true, AnalyticsBuild.isTest(isDebug = false, isEmulator = false, installer = null))
        assertEquals(
            true,
            AnalyticsBuild.isTest(isDebug = false, isEmulator = false, installer = "com.google.android.packageinstaller"),
        )
        assertEquals(false, AnalyticsBuild.isTest(isDebug = false, isEmulator = false, installer = play))
    }

    @Test
    fun activeTimerLeavesOutTimeAway() {
        val start = Date.fromTimeIntervalSince1970(1_000.0)
        val timer = ActiveTimer(now = start)
        timer.pause(now = start.addingTimeInterval(20.0))
        timer.pause(now = start.addingTimeInterval(25.0))
        assertEquals(20.0, timer.elapsed(now = start.addingTimeInterval(4_000.0)), 1e-9)
        timer.resume(now = start.addingTimeInterval(4_000.0))
        timer.resume(now = start.addingTimeInterval(4_005.0))
        assertEquals(30.0, timer.elapsed(now = start.addingTimeInterval(4_010.0)), 1e-9)
    }

    @Test
    fun closingAPackSaysHowManyCardsWereFlipped() {
        val event = AnalyticsEvent.PackClosed(PackCloseMethod.closeButton, 12.0, 3)
        assertEquals("2-5", event.parameters["flips"])
        assertEquals("0", AnalyticsEvent.PackClosed(PackCloseMethod.closeButton, 12.0, 0).parameters["flips"])
    }

    @Test
    fun practiceSaysWhichButtonOpenedIt() {
        val start = StudySessionStart(StudySessionKind.practice, 8, "firstLetter", false, pack = "TMS 60",
                                      entry = PracticeEntry.titleButton)
        assertEquals("titleButton", start.parameters["from"])
        assertNull(start.copy(entry = null).parameters["from"])
    }

    @Test
    fun typingMissesAreSentOnlyWhenCounted() {
        val end = StudySessionSummary(StudySessionKind.practice, false, 5, 1, 40.0, misses = 7)
        assertEquals("6-10", end.parameters["misses"])
        assertNull(end.copy(misses = null).parameters["misses"])
    }

    @Test
    fun leavingQuizSetupSaysWhatWasSelected() {
        val event = AnalyticsEvent.QuizSetupLeft(selected = 12, preselected = true)
        assertEquals("Quiz.setupLeft", event.name)
        assertEquals(mapOf("selected" to "11-20", "preselected" to "true"), event.parameters)
    }
}
