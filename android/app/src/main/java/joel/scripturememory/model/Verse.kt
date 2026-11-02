package joel.scripturememory.model

import kotlinx.serialization.Serializable
import kotlinx.serialization.Transient

@Serializable
data class Pack(
    val name: String,
    val color: String,
    val accentText: String,
    val verses: List<Verse>,
) {
    val id: String get() = name
}

@Serializable
data class Verse(
    val id: Int,
    val title: String,
    val verse: String,
    val book: String,
    val reference: String,
    val subpack: String,
    val version: String? = null,
    val cardUid: String? = null,
    @Transient val packName: String = "",
) {
    val pinnedVersion: String?
        get() {
            val v = version?.trimmingWhitespaces()
            if (v.isNullOrEmpty()) return null
            return v.uppercase(java.util.Locale.ROOT)
        }

    val titleWords: List<String> get() = title.wordTokens

    val verseWords: List<String> get() = verse.wordTokens

    val srsKey: String get() = cardUid ?: legacyKey

    val legacyKey: String get() = SRSKey.make(packName, book, reference)
}
