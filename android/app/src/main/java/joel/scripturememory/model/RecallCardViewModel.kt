package joel.scripturememory.model

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue

enum class SubmitField { title, verse }

open class RecallCardViewModel(verses: List<Verse>, initialIndex: Int = 0) {

    var verses: List<Verse> by mutableStateOf(verses)

    private var currentIndexState by mutableStateOf(initialIndex)

    var currentIndex: Int
        get() = currentIndexState
        set(value) {
            val oldValue = currentIndexState
            currentIndexState = value
            if (value != oldValue) syncActiveSection()
        }

    var activeSection: CardSection by mutableStateOf(CardSection.title)

    var titleRevealedCounts: Map<Int, Int> by mutableStateOf(emptyMap())
    var verseRevealedCounts: Map<Int, Int> by mutableStateOf(emptyMap())
    var submitResults: Map<Int, SubmitResult> by mutableStateOf(emptyMap())

    var inputText: String by mutableStateOf("")
    var misses = 0
        private set
    var titleInput: String by mutableStateOf("")
    var verseInput: String by mutableStateOf("")

    open fun progressDidChange() {}

    val currentVerse: Verse?
        get() = verses.getOrNull(currentIndex)

    val isCardComplete: Boolean
        get() {
            val verse = currentVerse ?: return false
            return when (studyMode) {
                StudyMode.submit -> submitResults[verse.id]?.isAllCorrect == true
                else -> (titleRevealedCounts[verse.id] ?: 0) >= verse.titleWords.size &&
                    (verseRevealedCounts[verse.id] ?: 0) >= verse.verseWords.size
            }
        }

    val isCardAnswered: Boolean
        get() {
            val verse = currentVerse ?: return false
            if (studyMode == StudyMode.submit) return submitResults[verse.id] != null
            return isCardComplete
        }

    val studyMode: StudyMode get() = StudyMode.saved()

    fun goForward() {
        if (currentIndex >= verses.size - 1) return
        currentIndex += 1
        progressDidChange()
    }

    fun goBackward() {
        if (currentIndex <= 0) return
        currentIndex -= 1
        progressDidChange()
    }

    fun clearInputs() {
        inputText = ""
        titleInput = ""
        verseInput = ""
    }

    fun revealedCount(verseId: Int, section: CardSection): Int =
        if (section == CardSection.title) {
            titleRevealedCounts[verseId] ?: 0
        } else {
            verseRevealedCounts[verseId] ?: 0
        }

    fun processFirstLetterInput(text: String): Boolean {
        val typed = text.graphemes().lastOrNull() ?: return false
        val verse = currentVerse ?: return false
        val words = sectionWords(activeSection, verse)
        val revealed = revealedCount(verse.id, activeSection)
        if (revealed >= words.size) return false
        val target = words[revealed]
        val expected = target.graphemes().firstOrNull(::isLetterOrNumberGrapheme)
        if (expected == null) {
            advance(verse, words, revealed)
            return true
        }
        if (typed.lowercasedByScalar().canonicallyEquals(expected.lowercasedByScalar())) {
            advance(verse, words, revealed)
            return true
        }
        misses += 1
        return false
    }

    fun processFullWordInput(text: String): Boolean {
        if (!text.endsWith(" ")) return false
        val verse = currentVerse ?: return false
        val typed = text.dropLast(1).trimmingWhitespaces()
        if (typed.isEmpty()) {
            inputText = ""
            return false
        }
        val words = sectionWords(activeSection, verse)
        val revealed = revealedCount(verse.id, activeSection)
        if (revealed >= words.size) return false
        if (DiffEngine.normalizedMatch(typed, words[revealed])) {
            advance(verse, words, revealed)
            inputText = ""
            return true
        }
        inputText = ""
        misses += 1
        return false
    }

    open fun handleSubmit(): SubmitResult? {
        val verse = currentVerse ?: return null
        val typedTitle = titleInput.trimmingWhitespacesAndNewlines().wordTokens
        val typedVerse = verseInput.trimmingWhitespacesAndNewlines().wordTokens
        if (typedTitle.isEmpty() && typedVerse.isEmpty()) return null

        val result = SubmitResult(
            titleDiffs = DiffEngine.buildDiffs(typedTitle, verse.titleWords),
            verseDiffs = DiffEngine.buildDiffs(typedVerse, verse.verseWords),
        )
        submitResults = submitResults + (verse.id to result)
        StreakStore.shared.recordToday()
        progressDidChange()
        titleInput = ""
        verseInput = ""
        return result
    }

    open fun retrySubmit() {
        val verse = currentVerse ?: return
        submitResults = submitResults - verse.id
        progressDidChange()
        titleInput = ""
        verseInput = ""
    }

    val hasSubmitInput: Boolean
        get() = titleInput.trimmingWhitespaces().isNotEmpty() ||
            verseInput.trimmingWhitespaces().isNotEmpty()

    fun applyDictation(transcript: String, field: SubmitField) {
        if (studyMode != StudyMode.submit) {
            processDictation(transcript)
            return
        }
        when (field) {
            SubmitField.title -> titleInput = transcript
            SubmitField.verse -> verseInput = transcript
        }
    }

    private var spokenWordsConsumed = 0

    fun resetDictation() {
        spokenWordsConsumed = 0
    }

    fun processDictation(transcript: String) {
        val spoken = HintFill.words(transcript)
        if (spoken.size <= spokenWordsConsumed) return
        for (word in spoken.drop(spokenWordsConsumed)) {
            val verse = currentVerse ?: break
            val words = sectionWords(activeSection, verse)
            val revealed = revealedCount(verse.id, activeSection)
            if (revealed >= words.size) break
            if (DiffEngine.normalizedMatch(word, words[revealed])) {
                advance(verse, words, revealed)
            }
        }
        spokenWordsConsumed = spoken.size
    }

    fun revealHint() {
        val verse = currentVerse ?: return
        val other = activeSection.other
        val hinted = when {
            revealedCount(verse.id, activeSection) < sectionWords(activeSection, verse).size ->
                activeSection
            revealedCount(verse.id, other) < sectionWords(other, verse).size -> other
            else -> return
        }
        setRevealed(revealedCount(verse.id, hinted) + 1, verse.id, hinted)
        progressDidChange()
        if (hinted == activeSection &&
            revealedCount(verse.id, hinted) >= sectionWords(hinted, verse).size
        ) {
            switchSectionIfNeeded(verse)
        }
    }

    fun fillNextHintWord(startingWithVerse: Boolean) {
        val verse = currentVerse ?: return
        val sections = if (startingWithVerse) {
            listOf(verse.verse to false, verse.title to true)
        } else {
            listOf(verse.title to true, verse.verse to false)
        }

        for ((target, isTitle) in sections) {
            val typed = if (isTitle) titleInput else verseInput
            val filled = HintFill.next(target, typed) ?: continue
            if (isTitle) titleInput = filled else verseInput = filled
            return
        }
    }

    fun syncActiveSection() {
        val verse = currentVerse ?: return
        val titleDone = (titleRevealedCounts[verse.id] ?: 0) >= verse.titleWords.size
        val target = if (titleDone) CardSection.verse else CardSection.title
        if (activeSection != target) activeSection = target
    }

    fun sectionWords(section: CardSection, verse: Verse): List<String> =
        if (section == CardSection.title) verse.titleWords else verse.verseWords

    private fun setRevealed(count: Int, verseId: Int, section: CardSection) {
        when (section) {
            CardSection.title -> titleRevealedCounts = titleRevealedCounts + (verseId to count)
            CardSection.verse -> verseRevealedCounts = verseRevealedCounts + (verseId to count)
        }
    }

    private fun advance(verse: Verse, sectionWords: List<String>, revealed: Int) {
        var newCount = revealed + 1
        while (newCount < sectionWords.size &&
            sectionWords[newCount].graphemes().none(::isLetterOrNumberGrapheme)
        ) {
            newCount += 1
        }
        setRevealed(newCount, verse.id, activeSection)
        progressDidChange()
        if (newCount >= sectionWords.size) {
            switchSectionIfNeeded(verse)
            if (isCardComplete) {
                StreakStore.shared.recordToday()
            }
        }
    }

    private fun switchSectionIfNeeded(verse: Verse) {
        val other = activeSection.other
        val otherWords = sectionWords(other, verse)
        val otherRevealed = revealedCount(verse.id, other)
        if (otherRevealed < otherWords.size) {
            activeSection = other
        }
    }
}
