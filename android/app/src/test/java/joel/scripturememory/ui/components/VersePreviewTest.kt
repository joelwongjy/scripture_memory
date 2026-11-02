package joel.scripturememory.ui.components

import androidx.compose.ui.graphics.Color
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class VersePreviewTest {

    private fun bolded(text: String, query: String?): List<String> {
        val preview = versePreview(text, query, Color.Black)
        return preview.spanStyles.map { preview.text.substring(it.start, it.end) }
    }

    @Test
    fun noQueryLeavesTextPlain() {
        assertEquals(emptyList<String>(), bolded("Be still", null))
        assertEquals(emptyList<String>(), bolded("Be still", "   "))
    }

    @Test
    fun noMatchLeavesTextPlain() {
        val preview = versePreview("Be still and know", "peace", Color.Black)
        assertEquals("Be still and know", preview.text)
        assertTrue(preview.spanStyles.isEmpty())
    }

    @Test
    fun everyMatchIsBoldedCaseInsensitivelyKeepingTheTextsOwnCase() {
        assertEquals(listOf("Peace", "peace"), bolded("Peace I leave, my peace I give", "peace"))
    }

    @Test
    fun aMatchInsideAWordBoldsOnlyTheMatch() {
        assertEquals(listOf("peace"), bolded("may live peaceful lives", "peace"))
    }

    @Test
    fun diacriticsAreIgnoredAndTheOriginalLettersKept() {
        assertEquals(listOf("café"), bolded("a café here", "cafe"))
        assertEquals(listOf("cafe"), bolded("a cafe here", "café"))
    }

    @Test
    fun queryIsTrimmed() {
        assertEquals(listOf("peace"), bolded("the peace of God", "  peace "))
    }

    @Test
    fun aMatchFiftyCharactersInKeepsTheWholeVerse() {
        val text = "x".repeat(49) + " peace"
        assertEquals(50, text.indexOf("peace"))
        assertEquals(text, versePreview(text, "peace", Color.Black).text)
    }

    @Test
    fun aMatchFiftyOneCharactersInIsElided() {
        val text = "x".repeat(50) + " peace"
        assertEquals(51, text.indexOf("peace"))
        assertTrue(versePreview(text, "peace", Color.Black).text.startsWith("\u2026"))
    }

    @Test
    fun aLateMatchStartsOnAWordBoundaryAfterAnEllipsis() {
        val text = "Do not be anxious about anything, but in everything, by prayer and petition, " +
            "with thanksgiving, present your requests to God. And the peace of God"
        val preview = versePreview(text, "peace", Color.Black)
        assertTrue(preview.text.startsWith("…"))
        assertTrue(text.contains(preview.text.drop(1)))
        val shown = preview.text.drop(1)
        val startsAt = text.indexOf(shown)
        assertTrue(text[startsAt - 1].isWhitespace())
        assertEquals(listOf("peace"), preview.spanStyles.map { preview.text.substring(it.start, it.end) })
    }
}
