package joel.scripturememory.model

import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL
import kotlinx.serialization.DeserializationStrategy
import kotlinx.serialization.Serializable
import kotlinx.serialization.builtins.ListSerializer

object SupabaseConfig {
    const val url = "https://jpyktgyajlvzjtpomvyz.supabase.co"
    const val anonKey = "sb_publishable_cZKhdNOAhfy9TZfqszZnig_ayAcWCF1"
}

interface CatalogClient {
    fun catalogVersion(): Int?
    fun fetchCatalog(version: Int): VerseCatalog.Document
}

class SupabaseCatalogClient private constructor(
    private val baseUrl: String,
    private val anonKey: String,
) : CatalogClient {

    override fun catalogVersion(): Int? {
        val rows = get(
            "catalog_meta",
            "select=version&limit=1",
            ListSerializer(VersionRow.serializer()),
        )
        return rows.firstOrNull()?.version
    }

    override fun fetchCatalog(version: Int): VerseCatalog.Document {
        val select = "edition,name,color,accent_text,sort_index," +
            "verses(verse_id,card_uid,sort_index,title,verse,book,reference,subpack,version)"
        val rows = get(
            "packs",
            "select=$select&order=sort_index.asc" + partialEditionFilter(),
            ListSerializer(PackRow.serializer()),
        )

        val editions = LinkedHashMap<String, MutableList<Pack>>()
        for (row in rows.sortedBy { it.sort_index }) {
            val allowed = VerseCatalog.partialEditions[row.edition]
            if (allowed != null && row.name !in allowed) continue
            val verses = row.verses
                .sortedBy { it.sort_index }
                .map {
                    Verse(
                        id = it.verse_id,
                        title = it.title,
                        verse = it.verse,
                        book = it.book,
                        reference = it.reference,
                        subpack = it.subpack,
                        version = it.version,
                        cardUid = it.card_uid,
                    )
                }
            editions.getOrPut(row.edition) { ArrayList() }
                .add(Pack(row.name, row.color, row.accent_text, verses))
        }
        return VerseCatalog.Document(VerseCatalog.currentSchema, version, editions)
    }

    @Serializable
    private data class VersionRow(val version: Int)

    @Serializable
    private data class PackRow(
        val edition: String,
        val name: String,
        val color: String,
        val accent_text: String,
        val sort_index: Int,
        val verses: List<VerseRow>,
    )

    @Serializable
    private data class VerseRow(
        val verse_id: Int,
        val card_uid: String? = null,
        val sort_index: Int,
        val title: String,
        val verse: String,
        val book: String,
        val reference: String,
        val subpack: String,
        val version: String? = null,
    )

    private fun <T> get(table: String, query: String, strategy: DeserializationStrategy<T>): T {
        val connection = URL("$baseUrl/rest/v1/$table?$query").openConnection() as HttpURLConnection
        try {
            connection.setRequestProperty("apikey", anonKey)
            connection.setRequestProperty("Authorization", "Bearer $anonKey")
            connection.connectTimeout = TIMEOUT_MILLIS
            connection.readTimeout = TIMEOUT_MILLIS
            if (connection.responseCode !in 200 until 300) {
                throw IOException("Bad server response ${connection.responseCode}")
            }
            val body = connection.inputStream.use { it.readBytes().decodeToString() }
            return ProgressJson.decodeFromString(strategy, body)
        } finally {
            connection.disconnect()
        }
    }

    companion object {
        private const val TIMEOUT_MILLIS = 20_000

        fun partialEditionFilter(): String =
            VerseCatalog.partialEditions.entries.sortedBy { it.key }.joinToString("") { (edition, names) ->
                val list = names.sorted().joinToString(",") { "\"$it\"" }
                val value = "(edition.neq.$edition,name.in.($list))"
                "&or=" + java.net.URLEncoder.encode(value, "UTF-8").replace("+", "%20")
            }

        fun create(
            url: String = SupabaseConfig.url,
            anonKey: String = SupabaseConfig.anonKey,
        ): SupabaseCatalogClient? {
            val trimmedUrl = url.trimmingWhitespacesAndNewlines()
            val trimmedKey = anonKey.trimmingWhitespacesAndNewlines()
            if (trimmedUrl.isEmpty() || trimmedKey.isEmpty()) return null
            return SupabaseCatalogClient(trimmedUrl.trimEnd('/'), trimmedKey)
        }
    }
}
