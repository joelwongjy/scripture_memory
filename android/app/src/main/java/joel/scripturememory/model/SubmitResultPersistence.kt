package joel.scripturememory.model

import kotlinx.serialization.Serializable

object SubmitResultPersistence {

    @Serializable
    data class StoredResult(
        val titleDiffs: List<StoredWord>,
        val verseDiffs: List<StoredWord>,
    )

    @Serializable
    data class StoredWord(
        val text: String,
        val kind: String,
        val correction: String? = null,
    )

    fun encodeToMap(dict: Map<Int, SubmitResult>): Map<String, StoredResult> =
        dict.entries.associate { (id, r) ->
            id.toString() to StoredResult(
                titleDiffs = r.titleDiffs.map(::wordToStored),
                verseDiffs = r.verseDiffs.map(::wordToStored),
            )
        }

    fun decodeFromMap(
        map: Map<String, StoredResult>?,
        validVerseIds: Set<Int>,
    ): Map<Int, SubmitResult> {
        if (map.isNullOrEmpty()) return emptyMap()
        val out = HashMap<Int, SubmitResult>()
        for ((key, stored) in map) {
            val id = key.toIntOrNull() ?: continue
            if (id !in validVerseIds) continue
            out[id] = submitResult(stored) ?: continue
        }
        return out
    }

    private fun wordToStored(w: DiffWord): StoredWord {
        val k = when (w.kind) {
            DiffWord.Kind.correct -> "c"
            DiffWord.Kind.wrong -> "w"
            DiffWord.Kind.missing -> "m"
            DiffWord.Kind.extra -> "e"
        }
        return StoredWord(w.text, k, w.correction)
    }

    private fun word(s: StoredWord): DiffWord? {
        val kind = when (s.kind) {
            "c" -> DiffWord.Kind.correct
            "w" -> DiffWord.Kind.wrong
            "m" -> DiffWord.Kind.missing
            "e" -> DiffWord.Kind.extra
            else -> return null
        }
        return DiffWord(s.text, kind, s.correction)
    }

    private fun submitResult(stored: StoredResult): SubmitResult? {
        val title = stored.titleDiffs.mapNotNull(::word)
        val verse = stored.verseDiffs.mapNotNull(::word)
        if (title.size != stored.titleDiffs.size || verse.size != stored.verseDiffs.size) return null
        return SubmitResult(title, verse)
    }
}
