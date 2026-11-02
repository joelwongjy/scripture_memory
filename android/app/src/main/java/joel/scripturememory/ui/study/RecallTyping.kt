package joel.scripturememory.ui.study

import androidx.compose.ui.text.TextRange
import androidx.compose.ui.text.input.TextFieldValue
import joel.scripturememory.model.graphemes
import kotlin.math.min

class FirstLetterGate {
    private var scored = 0

    fun accept(incoming: TextFieldValue, onGrapheme: (String) -> Unit): TextFieldValue {
        val fresh = incoming.text.substring(min(scored, incoming.text.length))
        scored = incoming.text.length
        fresh.graphemes().forEach(onGrapheme)
        return if (incoming.composition == null) TextFieldValue() else incoming
    }

    fun frameApplied(shown: TextFieldValue) {
        scored = shown.text.length
    }
}

class FullWordGate {
    private var scored = 0

    fun accept(incoming: TextFieldValue, onWord: (String) -> Unit): TextFieldValue {
        var rest = incoming.text.substring(min(scored, incoming.text.length))
        var finished = false
        while (true) {
            val end = rest.indexOfFirst(Char::isWhitespace)
            if (end < 0) break
            val word = rest.substring(0, end)
            scored += end + 1
            rest = rest.substring(end + 1)
            finished = true
            onWord("$word ")
        }
        if (!finished && scored == 0) return incoming
        return TextFieldValue(rest, TextRange(rest.length))
    }

    fun frameApplied() {
        scored = 0
    }
}
