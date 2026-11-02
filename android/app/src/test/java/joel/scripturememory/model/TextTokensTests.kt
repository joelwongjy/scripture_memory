package joel.scripturememory.model

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class TextTokensTests {

    @Test
    fun testSimpleSplit() {
        assertEquals(listOf("the", "quick", "fox"), "the quick fox".wordTokens)
    }

    @Test
    fun testCollapsesRuns() {
        assertEquals(listOf("the", "quick", "fox"), "the   quick  fox".wordTokens)
        assertEquals(listOf("hi", "there"), "  hi   there  ".wordTokens)
    }

    @Test
    fun testEmpty() {
        assertEquals(emptyList<String>(), "".wordTokens)
        assertEquals(emptyList<String>(), "     ".wordTokens)
    }

    @Test
    fun testDoubleDashSplits() {
        assertEquals(listOf("life", "death"), "life--death".wordTokens)
        assertEquals(listOf("a", "b"), "a -- b".wordTokens)
    }

    @Test
    fun testSingleHyphenKept() {
        assertEquals(listOf("God-breathed", "word"), "God-breathed word".wordTokens)
    }

    @Test
    fun testStripsEndQuotesKeepsInnerPunctuation() {
        assertEquals(listOf("Until"), "\"Until".wordTokens)
        assertEquals(listOf("Man"), "`Man".wordTokens)
        assertEquals(listOf("said,"), "said,\"".wordTokens)
    }

    @Test
    fun testKeepsMiddleApostrophe() {
        assertEquals(listOf("don't"), "don't".wordTokens)
        assertEquals(listOf("it's", "mine"), "it's mine".wordTokens)
    }

    @Test
    fun testCurlyAndGuillemetQuotes() {
        assertEquals(listOf("Man"), "‘Man".wordTokens)
        assertEquals(listOf("Word"), "“Word”".wordTokens)
        assertEquals(listOf("x"), "«x»".wordTokens)
    }

    @Test
    fun testTrimmingQuotationDelimitersOnEnds() {
        assertEquals("hello", "\"hello\"".trimmingQuotationDelimitersOnEnds())
        assertEquals("x", "'x'".trimmingQuotationDelimitersOnEnds())
        assertEquals("smart", "“smart”".trimmingQuotationDelimitersOnEnds())
        assertEquals("plain", "plain".trimmingQuotationDelimitersOnEnds())
        assertEquals("", "''".trimmingQuotationDelimitersOnEnds())
    }

    @Test
    fun testRealVerseFragment() {
        val s = "\"And this is the testimony: God has given us eternal life--and this life is in his Son.\""
        val tokens = s.wordTokens
        assertEquals("And", tokens.first())
        assertEquals("Son.", tokens.last())
        assertTrue("life" in tokens)
        assertTrue("and" in tokens)
        assertFalse("" in tokens)
    }
}
