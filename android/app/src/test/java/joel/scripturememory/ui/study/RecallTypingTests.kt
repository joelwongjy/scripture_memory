package joel.scripturememory.ui.study

import androidx.compose.ui.text.TextRange
import androidx.compose.ui.text.input.TextFieldValue
import org.junit.Assert.assertEquals
import org.junit.Test

class RecallTypingTests {

    private fun composing(text: String) =
        TextFieldValue(text, TextRange(text.length), TextRange(0, text.length))

    private fun committed(text: String) = TextFieldValue(text, TextRange(text.length))

    @Test
    fun firstLetterScoresEachKeyAndClears() {
        val gate = FirstLetterGate()
        val scored = mutableListOf<String>()
        val shown = gate.accept(committed("a"), scored::add)
        gate.frameApplied(shown)
        gate.frameApplied(gate.accept(committed("b"), scored::add))
        assertEquals(listOf("a", "b"), scored)
        assertEquals("", shown.text)
    }

    @Test
    fun firstLetterKeysArrivingBeforeTheFrameAreScoredOnce() {
        val gate = FirstLetterGate()
        val scored = mutableListOf<String>()
        gate.accept(committed("t"), scored::add)
        gate.accept(committed("th"), scored::add)
        val shown = gate.accept(committed("the"), scored::add)
        gate.frameApplied(shown)
        gate.accept(committed("x"), scored::add)
        assertEquals(listOf("t", "h", "e", "x"), scored)
    }

    @Test
    fun firstLetterKeepsTheBufferWhileTheImeComposes() {
        val gate = FirstLetterGate()
        val scored = mutableListOf<String>()
        var shown = gate.accept(composing("g"), scored::add)
        gate.frameApplied(shown)
        assertEquals("g", shown.text)
        shown = gate.accept(composing("go"), scored::add)
        gate.frameApplied(shown)
        shown = gate.accept(composing("god"), scored::add)
        gate.frameApplied(shown)
        assertEquals(listOf("g", "o", "d"), scored)
    }

    @Test
    fun firstLetterComposingFinishedThenClears() {
        val gate = FirstLetterGate()
        val scored = mutableListOf<String>()
        gate.frameApplied(gate.accept(composing("go"), scored::add))
        val shown = gate.accept(committed("go"), scored::add)
        gate.frameApplied(shown)
        assertEquals("", shown.text)
        assertEquals(listOf("g", "o"), scored)
    }

    @Test
    fun firstLetterComposingCorrectionAddsNothing() {
        val gate = FirstLetterGate()
        val scored = mutableListOf<String>()
        gate.frameApplied(gate.accept(composing("teh"), scored::add))
        gate.frameApplied(gate.accept(composing("the"), scored::add))
        assertEquals(listOf("t", "e", "h"), scored)
    }

    @Test
    fun fullWordComposingPassesThroughUntilASpace() {
        val gate = FullWordGate()
        val words = mutableListOf<String>()
        var shown = gate.accept(composing("lo"), words::add)
        assertEquals(composing("lo"), shown)
        gate.frameApplied()
        shown = gate.accept(committed("lord "), words::add)
        gate.frameApplied()
        assertEquals(listOf("lord "), words)
        assertEquals("", shown.text)
    }

    @Test
    fun fullWordKeepsTypingAfterASpaceBeforeTheFrame() {
        val gate = FullWordGate()
        val words = mutableListOf<String>()
        gate.accept(committed("for "), words::add)
        var shown = gate.accept(committed("for t"), words::add)
        assertEquals("t", shown.text)
        shown = gate.accept(committed("for th"), words::add)
        assertEquals("th", shown.text)
        gate.frameApplied()
        shown = gate.accept(committed("the "), words::add)
        assertEquals(listOf("for ", "the "), words)
        assertEquals("", shown.text)
    }

    @Test
    fun fullWordWholeBurstSplitsIntoWords() {
        val gate = FullWordGate()
        val words = mutableListOf<String>()
        val shown = gate.accept(committed("in the be"), words::add)
        assertEquals(listOf("in ", "the "), words)
        assertEquals("be", shown.text)
    }

    @Test
    fun fullWordLoneSpaceIsReported() {
        val gate = FullWordGate()
        val words = mutableListOf<String>()
        gate.accept(committed(" "), words::add)
        assertEquals(listOf(" "), words)
    }
}
