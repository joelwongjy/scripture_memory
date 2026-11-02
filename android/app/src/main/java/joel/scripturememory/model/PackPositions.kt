package joel.scripturememory.model

import kotlinx.serialization.builtins.MapSerializer
import kotlinx.serialization.builtins.serializer

object PackPositions {
    private const val key = "packPositions.v1"
    private val positionsSerializer = MapSerializer(String.serializer(), String.serializer())

    private fun all(defaults: KeyValueStore): Map<String, String>? {
        val raw = defaults.getString(key) ?: return null
        return try {
            ProgressJson.decodeFromString(positionsSerializer, raw)
        } catch (_: Exception) {
            null
        }
    }

    fun save(verse: Verse, packName: String, defaults: KeyValueStore = AppDefaults.standard) {
        val updated = all(defaults).orEmpty() + (packName to verse.srsKey)
        defaults.putString(key, ProgressJson.encodeToString(positionsSerializer, updated))
    }

    fun startIndex(
        pack: Pack,
        currentKey: String?,
        defaults: KeyValueStore = AppDefaults.standard,
    ): Int {
        val saved = all(defaults)?.get(pack.name)
        for (target in listOfNotNull(saved, currentKey)) {
            val i = pack.verses.indexOfFirst { it.srsKey == target }
            if (i >= 0) return i
        }
        return 0
    }
}
