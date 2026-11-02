package joel.scripturememory.model

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import kotlin.math.max
import kotlin.math.min
import kotlinx.serialization.Serializable

@Serializable
private data class SessionProgress(
    val currentIndex: Int,
    val mistakeCounts: Map<String, Int>,
    val titleRevealedCounts: Map<String, Int>,
    val verseRevealedCounts: Map<String, Int>,
    val completedVerseIds: List<String>,
    val submitResultsSnapshot: Map<String, SubmitResultPersistence.StoredResult>? = null,
)

class TestSessionViewModel(
    verses: List<Verse>,
    val kind: SessionKind,
) : RecallCardViewModel(verses) {

    var mistakeCounts: Map<Int, Int> by mutableStateOf(emptyMap())
        private set

    var completedVerseIds: Set<Int> by mutableStateOf(emptySet())
        private set

    var sessionGrades: Map<Int, SRSGrade> by mutableStateOf(emptyMap())
    var preGradeStates: Map<Int, SRSCardState> by mutableStateOf(emptyMap())
    var unscheduledAtStart: Map<Int, Boolean> = emptyMap()
    var gradedOrder: List<Int> by mutableStateOf(emptyList())
    var autoLearntIds: Set<Int> = emptySet()
    var peekedVerseIds: Set<Int> by mutableStateOf(emptySet())

    val isSessionComplete: Boolean
        get() {
            if (verses.isEmpty()) return false
            return verses.all { verse ->
                when (studyMode) {
                    StudyMode.submit -> submitResults[verse.id]?.isAllCorrect == true
                    else -> (titleRevealedCounts[verse.id] ?: 0) >= verse.titleWords.size &&
                        (verseRevealedCounts[verse.id] ?: 0) >= verse.verseWords.size
                }
            }
        }

    fun mistakes(verseId: Int): Int = min(mistakeCounts[verseId] ?: 0, maxMistakesPerVerse)

    val sessionScore: Int get() = -verses.sumOf { mistakes(it.id) }
    val perfectCount: Int get() = verses.count { mistakes(it.id) == 0 && isComplete(it) }
    val completedCount: Int get() = verses.count { isComplete(it) }

    override fun progressDidChange() {
        saveProgress()
    }

    fun cardLabel(verse: Verse): String = CardFooter.label(verse)

    fun recordMistake() {
        if (studyMode != StudyMode.submit) return
        val verse = currentVerse ?: return
        val current = mistakeCounts[verse.id] ?: 0
        if (current >= maxMistakesPerVerse) return
        mistakeCounts = mistakeCounts + (verse.id to current + 1)
        saveProgress()
    }

    override fun handleSubmit(): SubmitResult? {
        val verse = currentVerse ?: return null
        val result = super.handleSubmit() ?: return null

        val totalMistakes = result.titleDiffs.count { it.kind != DiffWord.Kind.correct } +
            result.verseDiffs.count { it.kind != DiffWord.Kind.correct }
        repeat(totalMistakes) { recordMistake() }

        if (result.isAllCorrect) completedVerseIds = completedVerseIds + verse.id
        saveProgress()
        return result
    }

    override fun retrySubmit() {
        val verse = currentVerse ?: return
        super.retrySubmit()
        mistakeCounts = mistakeCounts - verse.id
        completedVerseIds = completedVerseIds - verse.id
        saveProgress()
    }

    fun resetAllProgress() {
        currentIndex = 0
        activeSection = CardSection.title
        mistakeCounts = emptyMap()
        titleRevealedCounts = emptyMap()
        verseRevealedCounts = emptyMap()
        submitResults = emptyMap()
        completedVerseIds = emptySet()
        clearInputs()
        saveProgress()
    }

    private val progressKey: String? get() = progressKey(kind)

    fun saveProgress() {
        val key = progressKey ?: return
        val snapshot = if (submitResults.isEmpty()) {
            null
        } else {
            SubmitResultPersistence.encodeToMap(submitResults)
        }
        val sp = SessionProgress(
            currentIndex = currentIndex,
            mistakeCounts = toStringKeys(mistakeCounts),
            titleRevealedCounts = toStringKeys(titleRevealedCounts),
            verseRevealedCounts = toStringKeys(verseRevealedCounts),
            completedVerseIds = completedVerseIds.map { it.toString() },
            submitResultsSnapshot = snapshot,
        )
        val raw = try {
            ProgressJson.encodeToString(SessionProgress.serializer(), sp)
        } catch (_: Exception) {
            return
        }
        AppDefaults.standard.putString(key, raw)
    }

    private fun restoreProgress() {
        val key = progressKey ?: return
        val raw = AppDefaults.standard.getString(key) ?: return
        val sp = try {
            ProgressJson.decodeFromString(SessionProgress.serializer(), raw)
        } catch (_: Exception) {
            return
        }
        currentIndex = min(sp.currentIndex, max(0, verses.size - 1))
        mistakeCounts = toIntKeys(sp.mistakeCounts)
        titleRevealedCounts = toIntKeys(sp.titleRevealedCounts)
        verseRevealedCounts = toIntKeys(sp.verseRevealedCounts)
        completedVerseIds = sp.completedVerseIds.mapNotNull { it.toIntOrNull() }.toSet()

        val validIds = verses.map { it.id }.toSet()
        val restored = SubmitResultPersistence
            .decodeFromMap(sp.submitResultsSnapshot, validIds)
            .toMutableMap()

        for (verseId in completedVerseIds) {
            if (verseId in restored) continue
            val verse = verses.firstOrNull { it.id == verseId } ?: continue
            restored[verseId] = SubmitResult(
                titleDiffs = verse.titleWords.map { DiffWord(it, DiffWord.Kind.correct) },
                verseDiffs = verse.verseWords.map { DiffWord(it, DiffWord.Kind.correct) },
            )
        }
        submitResults = restored

        val firstIncomplete = verses.indices.firstOrNull { !isComplete(verses[it]) }
        if (firstIncomplete != null) currentIndex = firstIncomplete
        syncActiveSection()
    }

    private fun isComplete(verse: Verse): Boolean = when (studyMode) {
        StudyMode.submit -> submitResults[verse.id] != null
        else -> (titleRevealedCounts[verse.id] ?: 0) >= verse.titleWords.size &&
            (verseRevealedCounts[verse.id] ?: 0) >= verse.verseWords.size
    }

    private fun toStringKeys(d: Map<Int, Int>): Map<String, Int> =
        d.entries.associate { (k, v) -> k.toString() to v }

    private fun toIntKeys(d: Map<String, Int>): Map<Int, Int> = buildMap {
        for ((k, v) in d) k.toIntOrNull()?.let { put(it, v) }
    }

    init {
        restoreProgress()
    }

    companion object {
        private const val maxMistakesPerVerse = 5

        private fun progressKey(kind: SessionKind): String? = when (kind) {
            SessionKind.srs -> "srsSessionProgress"
            SessionKind.custom -> "currentSessionProgress"
            SessionKind.pack -> null
        }

        fun clearPersistedProgress(kind: SessionKind) {
            val key = progressKey(kind) ?: return
            AppDefaults.standard.remove(key)
        }

        fun savedCompletedCount(kind: SessionKind, verses: List<Verse>): Int {
            val key = progressKey(kind) ?: return 0
            if (AppDefaults.standard.getString(key) == null) return 0
            val saved = TestSessionViewModel(verses, kind)
            return verses.count(saved::isComplete)
        }
    }
}
