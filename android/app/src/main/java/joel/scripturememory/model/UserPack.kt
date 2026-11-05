package joel.scripturememory.model

import java.util.Locale
import java.util.UUID
import kotlinx.serialization.Serializable

@Serializable
data class UserVerse(
    val id: String,
    val title: String,
    val text: String,
    val book: String,
    val reference: String,
    val version: String? = null,
) {
    val numericID: Int
        get() {
            var hash = 0xcbf29ce484222325uL
            for (byte in id.toByteArray(Charsets.UTF_8)) {
                hash = hash xor byte.toUByte().toULong()
                hash *= 0x100000001b3uL
            }
            return 1_000_000 + (hash % 1_000_000_000uL).toInt()
        }

    companion object {
        fun newID(): String =
            "u" + UUID.randomUUID().toString().replace("-", "").take(15).lowercase(Locale.ROOT)
    }
}

@Serializable
data class UserPack(
    val id: String,
    val name: String,
    val color: String,
    val verses: List<UserVerse>,
) {
    val pack: Pack
        get() = Pack(
            name = name,
            color = color,
            accentText = "",
            verses = verses.map { v ->
                Verse(
                    id = v.numericID,
                    title = v.title,
                    verse = v.text,
                    book = v.book,
                    reference = v.reference,
                    subpack = "",
                    version = v.version?.takeUnless { it.uppercase(Locale.ROOT) == "NIV" },
                    cardUid = v.id,
                    packName = name,
                )
            },
            userPackID = id,
        )

    companion object {
        const val defaultName = "OYO"
        const val subtitle = "On Your Own"

        val colors: List<String> = listOf(
            "#C8252C",
            "#0F8A4B",
            "#1F5FA8",
            "#E08A1E",
            "#5E3A87",
            "#3C3C43",
        )
    }
}
