package joel.scripturememory.model

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import kotlinx.coroutines.channels.BufferOverflow
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.asSharedFlow

class LearningStore(private val storage: ProgressStorage) {

    data class CurrentVerse(val verse: Verse, val index: Int)

    data class DisplayedVerse(val verse: Verse, val isPinned: Boolean)

    private class CachedCurrent(val token: Int, val keys: Set<String>, val verse: Verse?)

    var learntKeys: Set<String> by mutableStateOf(storage.stringArray(storageKey).orEmpty().toSet())
        private set

    var pinnedKey: String? by mutableStateOf(storage.string(pinStorageKey))
        private set

    private val featuredVerseChanges = MutableSharedFlow<Unit>(
        extraBufferCapacity = 1,
        onBufferOverflow = BufferOverflow.DROP_OLDEST,
    )

    val featuredVerseDidChange: SharedFlow<Unit> = featuredVerseChanges.asSharedFlow()

    private var cachedCurrent: CachedCurrent? = null

    fun isLearnt(verse: Verse): Boolean = verse.srsKey in learntKeys

    fun current(ordered: List<Verse>): CurrentVerse? {
        val i = ordered.indexOfFirst { it.srsKey !in learntKeys }
        if (i < 0) return null
        return CurrentVerse(ordered[i], i)
    }

    val visibleOrdered: List<Verse>
        get() {
            val version = BibleVersion.saved()
            return Catalogue.verses(PackPreferencesStore.shared.visible(version.packs))
        }

    private val currentInputToken: Int
        get() {
            val packs = PackPreferencesStore.shared
            var h = (AppDefaults.standard.getString(BibleVersion.storageKey) ?: "").hashCode()
            h = 31 * h + packs.order.hashCode()
            h = 31 * h + packs.hidden.hashCode()
            return h
        }

    val currentVerse: Verse?
        get() {
            val token = currentInputToken
            val keys = learntKeys
            cachedCurrent?.let { if (it.token == token && it.keys === keys) return it.verse }
            val verse = current(visibleOrdered)?.verse
            cachedCurrent = CachedCurrent(token, keys, verse)
            return verse
        }

    val currentKey: String? get() = currentVerse?.srsKey

    fun isCurrent(verse: Verse): Boolean {
        if (verse.srsKey.isEmpty()) return false
        val key = currentKey ?: return false
        return key == verse.srsKey
    }

    fun displayed(ordered: List<Verse>): DisplayedVerse? {
        val key = pinnedKey
        if (key != null) {
            val v = ordered.firstOrNull { it.srsKey == key }
            if (v != null) return DisplayedVerse(v, true)
        }
        return current(ordered)?.let { DisplayedVerse(it.verse, false) }
    }

    fun pin(verse: Verse) {
        if (verse.srsKey.isEmpty()) return
        pinnedKey = verse.srsKey
        storage.set(verse.srsKey, pinStorageKey)
        featuredVerseChanges.tryEmit(Unit)
    }

    fun unpin() {
        if (pinnedKey == null) return
        pinnedKey = null
        storage.removeObject(pinStorageKey)
        featuredVerseChanges.tryEmit(Unit)
    }

    fun markLearnt(verse: Verse) {
        if (verse.srsKey.isEmpty() || verse.srsKey in learntKeys) return
        learntKeys = learntKeys + verse.srsKey
        persist()
        SRSStore.shared.scheduleLearnt(verse)
        StreakStore.shared.recordToday()
    }

    fun unmarkLearnt(verse: Verse) {
        if (verse.srsKey !in learntKeys) return
        learntKeys = learntKeys - verse.srsKey
        persist()
        SRSStore.shared.unscheduleLearnt(verse)
    }

    fun setProgress(startingAt: Verse, ordered: List<Verse>) {
        val i = ordered.indexOfFirst { it.srsKey == startingAt.srsKey }
        if (i < 0) return
        learntKeys = ordered.take(i).map { it.srsKey }.toSet()
        persist()
    }

    private fun persist() {
        storage.set(learntKeys.toList(), storageKey)
    }

    companion object {
        lateinit var shared: LearningStore
            internal set

        private const val storageKey = "learning.learntKeys.v1"
        private const val pinStorageKey = "learning.pinnedKey.v1"
    }
}
