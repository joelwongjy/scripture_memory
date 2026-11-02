package joel.scripturememory.model

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue

class FavoritesStore(private val storage: ProgressStorage) {

    var keys: Set<String> by mutableStateOf(storage.stringArray(storageKey).orEmpty().toSet())
        private set

    private var cachedVerses: Pair<Long, List<Verse>>? = null

    fun isFavorite(verse: Verse): Boolean = verse.srsKey.isNotEmpty() && verse.srsKey in keys

    fun toggle(verse: Verse) {
        if (verse.srsKey.isEmpty()) return
        keys = if (verse.srsKey in keys) keys - verse.srsKey else keys + verse.srsKey
        persist()
    }

    fun verses(packs: List<Pack>): List<Verse> {
        val current = keys
        if (current.isEmpty()) return emptyList()
        val token = Catalogue.fingerprint(packs) xor current.hashCode().toLong()
        cachedVerses?.let { if (it.first == token) return it.second }
        val matched = Catalogue.verses(packs).filter { it.srsKey in current }
        cachedVerses = token to matched
        return matched
    }

    fun pack(packs: List<Pack>): Pack? {
        val verses = verses(packs)
        if (verses.isEmpty()) return null
        return Pack(packName, "#E5A50A", "★", verses)
    }

    private fun persist() {
        cachedVerses = null
        storage.set(keys.toList(), storageKey)
    }

    companion object {
        lateinit var shared: FavoritesStore
            internal set

        const val packName = "Favourites"

        private const val storageKey = "favorites.verseKeys.v1"
    }
}
