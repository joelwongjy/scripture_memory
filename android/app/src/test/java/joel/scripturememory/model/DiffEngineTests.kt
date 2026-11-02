package joel.scripturememory.model

import joel.scripturememory.model.DiffWord.Kind
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class DiffEngineTests {

    private fun kinds(d: List<DiffWord>) = d.map { it.kind }
    private fun texts(d: List<DiffWord>) = d.map { it.text }

    @Test
    fun testAllCorrect() {
        val d = DiffEngine.buildDiffs(listOf("the", "quick", "fox"), listOf("the", "quick", "fox"))
        assertEquals(listOf(Kind.correct, Kind.correct, Kind.correct), kinds(d))
        assertEquals(listOf("the", "quick", "fox"), texts(d))
    }

    @Test
    fun testEmptyTypedIsAllMissing() {
        val d = DiffEngine.buildDiffs(emptyList(), listOf("a", "b"))
        assertEquals(listOf(Kind.missing, Kind.missing), kinds(d))
        assertEquals(listOf("a", "b"), texts(d))
    }

    @Test
    fun testEmptyTargetIsAllExtra() {
        val d = DiffEngine.buildDiffs(listOf("a", "b"), emptyList())
        assertEquals(listOf(Kind.extra, Kind.extra), kinds(d))
    }

    @Test
    fun testBothEmpty() {
        assertTrue(DiffEngine.buildDiffs(emptyList(), emptyList()).isEmpty())
    }

    @Test
    fun testMissingWordInMiddle() {
        val d = DiffEngine.buildDiffs(listOf("the", "fox"), listOf("the", "quick", "fox"))
        assertEquals(listOf(Kind.correct, Kind.missing, Kind.correct), kinds(d))
        assertEquals(listOf("the", "quick", "fox"), texts(d))
    }

    @Test
    fun testExtraWord() {
        val d = DiffEngine.buildDiffs(listOf("the", "big", "fox"), listOf("the", "fox"))
        assertEquals(listOf("big"), texts(d.filter { it.kind == Kind.extra }))
        assertEquals(listOf("the", "fox"), texts(d.filter { it.kind == Kind.correct }))
    }

    @Test
    fun testWrongWordCarriesCorrection() {
        val d = DiffEngine.buildDiffs(listOf("the", "quik", "fox"), listOf("the", "quick", "fox"))
        val wrong = d.filter { it.kind == Kind.wrong }
        assertEquals(listOf("quik"), wrong.map { it.text })
        assertEquals(listOf("quick"), wrong.map { it.correction })
    }

    @Test
    fun testCaseInsensitive() {
        assertTrue(DiffEngine.normalizedMatch("The", "the"))
        assertTrue(DiffEngine.normalizedMatch("GOD", "god"))
        assertFalse(DiffEngine.normalizedMatch("god", "lord"))
    }

    @Test
    fun testPunctuationIgnoredInMatch() {
        assertTrue(DiffEngine.normalizedMatch("Son.", "Son"))
        assertTrue(DiffEngine.normalizedMatch("life;", "life"))
        assertTrue(DiffEngine.normalizedMatch("\"Until", "Until"))
        assertTrue(DiffEngine.normalizedMatch("don't", "dont"))
    }

    @Test
    fun testNormalize() {
        assertEquals("god", DiffEngine.normalize("God,"))
        assertEquals("son", DiffEngine.normalize("Son!"))
        assertEquals("whoever", DiffEngine.normalize("“Whoever”"))
    }

    @Test
    fun testSubmitResultIsAllCorrect() {
        val ok = listOf(DiffWord("a", Kind.correct))
        val bad = listOf(DiffWord("b", Kind.missing))
        assertTrue(SubmitResult(ok, ok).isAllCorrect)
        assertFalse(SubmitResult(ok, bad).isAllCorrect)
        assertFalse(SubmitResult(bad, ok).isAllCorrect)
        assertFalse(SubmitResult(emptyList(), ok).isAllCorrect)
        assertFalse(SubmitResult(ok, emptyList()).isAllCorrect)
    }

    @Test
    fun testIdenticalIsAllCorrectProperty() {
        val rng = SplitMix64(0xD1FF0001uL)
        val vocab = listOf("the", "quick", "brown", "fox", "god", "son", "life", "word")
        repeat(5_000) {
            val target = List(rng.nextInt(0, 9)) { vocab.random(rng) }
            val d = DiffEngine.buildDiffs(target, target)
            assertEquals(target.size, d.size)
            assertTrue(d.all { it.kind == Kind.correct })
        }
    }

    @Test
    fun testTargetCoverageProperty() {
        val rng = SplitMix64(0xBEEF0002uL)
        val vocab = listOf("a", "b", "c", "d", "e")
        repeat(5_000) {
            val target = List(rng.nextInt(1, 7)) { vocab.random(rng) }
            val typed = List(rng.nextInt(0, 7)) { vocab.random(rng) }
            val d = DiffEngine.buildDiffs(typed, target)
            assertEquals(target.size, d.count { it.kind != Kind.extra })
            assertEquals(typed.size, d.count { it.kind != Kind.missing })
        }
    }

    @Test
    fun testStandalonePunctuationIsNotScored() {
        val target = listOf("Man", "-", "the", "sinner")
        val diffs = DiffEngine.buildDiffs(listOf("Man", "the", "sinner"), target)
        assertTrue(diffs.all { it.kind == Kind.correct })
        assertEquals(3, diffs.size)
    }

    @Test
    fun testTypingThePunctuationIsAlsoAccepted() {
        val words = listOf("Man", "-", "the", "sinner")
        assertTrue(DiffEngine.buildDiffs(words, words).all { it.kind == Kind.correct })
    }

    @Test
    fun testBritishSpellingAccepted() {
        val pairs = listOf(
            "saviour" to "savior",
            "honour" to "honor",
            "neighbour" to "neighbor",
            "realise" to "realize",
            "baptised" to "baptized",
            "defence" to "defense",
            "judgement" to "judgment",
            "fulfilled" to "fulfilled",
        )
        for ((british, american) in pairs) {
            assertTrue("$british should match $american", DiffEngine.normalizedMatch(british, american))
            assertTrue("$american should match $british", DiffEngine.normalizedMatch(american, british))
        }
    }

    @Test
    fun testSpellingEquivalenceDoesNotMergeUnrelatedWords() {
        assertFalse(DiffEngine.normalizedMatch("four", "for"))
        assertFalse(DiffEngine.normalizedMatch("hour", "hor"))
        assertFalse(DiffEngine.normalizedMatch("wise", "wize"))
        assertFalse(DiffEngine.normalizedMatch("praise", "praize"))
        assertFalse(DiffEngine.normalizedMatch("honour", "honesty"))
    }

    @Test
    fun testBritishSpellingInAFullDiff() {
        val diffs = DiffEngine.buildDiffs(
            listOf("our", "saviour", "showed", "favour"),
            listOf("our", "savior", "showed", "favor"),
        )
        assertTrue(diffs.all { it.kind == Kind.correct })
    }
}
