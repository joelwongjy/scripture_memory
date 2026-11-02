package joel.scripturememory.model

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

class RecallCardViewModelTests {

    private val v1 = verse(1, title = "Man - the sinner", text = "For God so loved")
    private val v2 = verse(2, title = "Two", text = "\"Second\" verse")

    private fun model(vararg verses: Verse) = RecallCardViewModel(verses.toList().ifEmpty { listOf(v1, v2) })

    private fun setMode(mode: StudyMode) {
        AppDefaults.standard.putString(StudyMode.storageKey, mode.rawValue)
    }

    @Before
    fun setUp() {
        installModel()
    }

    @Test
    fun firstLetterAcceptsEitherCaseAndUsesOnlyTheLastCharacter() {
        val m = model()
        assertTrue(m.processFirstLetterInput("xm"))
        assertEquals(1, m.revealedCount(1, CardSection.title).coerceAtMost(1))
        assertFalse(m.processFirstLetterInput("z"))
        assertFalse(m.processFirstLetterInput(""))
    }

    @Test
    fun aStandaloneDashIsSkippedAndDoesNotSwallowTheNextKeystroke() {
        val m = model()
        m.processFirstLetterInput("m")
        assertEquals(2, m.revealedCount(1, CardSection.title))
        assertTrue(m.processFirstLetterInput("t"))
        assertEquals(3, m.revealedCount(1, CardSection.title))
    }

    @Test
    fun aQuotedWordMatchesOnItsFirstLetter() {
        val m = model(v2)
        m.titleRevealedCounts = mapOf(2 to 1)
        m.syncActiveSection()
        assertEquals(CardSection.verse, m.activeSection)
        assertTrue(m.processFirstLetterInput("s"))
    }

    @Test
    fun finishingTheTitleMovesToTheVerseAndFinishingBothRecordsTheDay() {
        val m = model()
        listOf("m", "t", "s").forEach { m.processFirstLetterInput(it) }
        assertEquals(CardSection.verse, m.activeSection)
        assertFalse(StreakStore.shared.isTodayDone)
        listOf("f", "g", "s", "l").forEach { m.processFirstLetterInput(it) }
        assertTrue(m.isCardComplete)
        assertTrue(m.isCardAnswered)
        assertTrue(StreakStore.shared.isTodayDone)
        assertFalse(m.processFirstLetterInput("x"))
    }

    @Test
    fun fullWordNeedsATrailingSpaceAndAlwaysClearsTheField() {
        val m = model()
        m.inputText = "Man"
        assertFalse(m.processFullWordInput("Man"))
        assertEquals("Man", m.inputText)

        assertTrue(m.processFullWordInput("man "))
        assertEquals("", m.inputText)

        m.inputText = "wrong "
        assertFalse(m.processFullWordInput("wrong "))
        assertEquals("", m.inputText)
    }

    @Test
    fun fullWordOfOnlySpacesClearsTheField() {
        val m = model()
        m.inputText = "   "
        assertFalse(m.processFullWordInput("   "))
        assertEquals("", m.inputText)
    }

    @Test
    fun submitScoresTrimsAndClearsTheInputs() {
        setMode(StudyMode.submit)
        val m = model()
        m.titleInput = "  Man the sinner\n"
        m.verseInput = "For God loved"
        val result = m.handleSubmit()!!
        assertTrue(result.titleDiffs.all { it.kind == DiffWord.Kind.correct })
        assertEquals(
            listOf("correct", "correct", "missing", "correct"),
            result.verseDiffs.map { it.kind.name },
        )
        assertEquals("", m.titleInput)
        assertEquals("", m.verseInput)
        assertTrue(m.isCardAnswered)
        assertFalse(m.isCardComplete)
        assertTrue(StreakStore.shared.isTodayDone)
    }

    @Test
    fun submitWithNothingTypedDoesNothing() {
        val m = model()
        m.titleInput = " \n"
        assertNull(m.handleSubmit())
        assertTrue(m.submitResults.isEmpty())
    }

    @Test
    fun retryForgetsTheAttempt() {
        val m = model()
        m.titleInput = "Man"
        m.handleSubmit()
        m.titleInput = "left over"
        m.retrySubmit()
        assertTrue(m.submitResults.isEmpty())
        assertEquals("", m.titleInput)
    }

    @Test
    fun hasSubmitInputIgnoresBlanks() {
        val m = model()
        assertFalse(m.hasSubmitInput)
        m.verseInput = "  "
        assertFalse(m.hasSubmitInput)
        m.verseInput = "a"
        assertTrue(m.hasSubmitInput)
    }

    @Test
    fun dictationMatchesWordByWordAcrossSections() {
        val m = model()
        m.processDictation("man the sinner for")
        assertEquals(4, m.revealedCount(1, CardSection.title))
        assertEquals(1, m.revealedCount(1, CardSection.verse))
        assertEquals(CardSection.verse, m.activeSection)
    }

    @Test
    fun aRevisedTranscriptNeverDoubleAdvances() {
        val m = model()
        m.processDictation("man")
        val after = m.revealedCount(1, CardSection.title)
        m.processDictation("man")
        m.processDictation("many")
        assertEquals(after, m.revealedCount(1, CardSection.title))
    }

    @Test
    fun aMisheardWordIsConsumedNotRetried() {
        val m = model()
        m.processDictation("banana")
        assertEquals(0, m.revealedCount(1, CardSection.title))
        m.processDictation("banana man")
        assertEquals(2, m.revealedCount(1, CardSection.title))
    }

    @Test
    fun resetDictationStartsAFreshTranscript() {
        val m = model()
        m.processDictation("banana")
        m.resetDictation()
        m.processDictation("man")
        assertEquals(2, m.revealedCount(1, CardSection.title))
    }

    @Test
    fun dictationInSubmitModeFillsTheChosenBox() {
        setMode(StudyMode.submit)
        val m = model()
        m.applyDictation("hello there", SubmitField.verse)
        assertEquals("hello there", m.verseInput)
        m.applyDictation("title", SubmitField.title)
        assertEquals("title", m.titleInput)
        assertEquals(0, m.revealedCount(1, CardSection.title))
    }

    @Test
    fun dictationInTypingModesReveals() {
        val m = model()
        m.applyDictation("man", SubmitField.verse)
        assertEquals("", m.verseInput)
        assertEquals(2, m.revealedCount(1, CardSection.title))
    }

    @Test
    fun hintRevealsTheActiveSectionThenFallsThrough() {
        val m = model()
        m.revealHint()
        assertEquals(1, m.revealedCount(1, CardSection.title))
        repeat(3) { m.revealHint() }
        assertEquals(4, m.revealedCount(1, CardSection.title))
        assertEquals(CardSection.verse, m.activeSection)
        repeat(4) { m.revealHint() }
        assertEquals(4, m.revealedCount(1, CardSection.verse))
        m.revealHint()
        assertEquals(4, m.revealedCount(1, CardSection.verse))
    }

    @Test
    fun hintDoesNotSkipPunctuationTheWayTypingDoes() {
        val m = model()
        repeat(2) { m.revealHint() }
        assertEquals(2, m.revealedCount(1, CardSection.title))
    }

    @Test
    fun entireVerseHintWalksTheCardFromEitherBox() {
        val m = model()
        repeat(4) { m.fillNextHintWord(startingWithVerse = false) }
        assertEquals("Man - the sinner", m.titleInput)
        assertEquals("", m.verseInput)
        m.fillNextHintWord(startingWithVerse = false)
        assertEquals("For", m.verseInput)

        val other = model()
        other.fillNextHintWord(startingWithVerse = true)
        assertEquals("For", other.verseInput)
        assertEquals("", other.titleInput)
    }

    @Test
    fun navigationStopsAtTheEndsAndRepointsTheHighlight() {
        val m = model()
        m.goBackward()
        assertEquals(0, m.currentIndex)
        m.titleRevealedCounts = mapOf(2 to 1)
        m.goForward()
        assertEquals(1, m.currentIndex)
        assertEquals(CardSection.verse, m.activeSection)
        m.goForward()
        assertEquals(1, m.currentIndex)
    }

    @Test
    fun anEmptyDeckIsHarmless() {
        val m = RecallCardViewModel(emptyList())
        assertNull(m.currentVerse)
        assertFalse(m.isCardComplete)
        assertFalse(m.isCardAnswered)
        assertFalse(m.processFirstLetterInput("a"))
        assertNull(m.handleSubmit())
        m.revealHint()
        m.processDictation("a b")
        m.goForward()
        m.goBackward()
    }

    @Test
    fun initialIndexDoesNotTriggerASectionSync() {
        val m = RecallCardViewModel(listOf(v1, v2), initialIndex = 1)
        assertEquals(1, m.currentIndex)
        assertEquals(CardSection.title, m.activeSection)
    }
}
