package joel.scripturememory.model

import java.io.File
import java.io.InputStream
import java.nio.file.Files
import java.nio.file.StandardCopyOption
import kotlin.coroutines.cancellation.CancellationException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.Serializable
import kotlinx.serialization.builtins.ListSerializer

object VerseCatalog {

    @Serializable
    data class Document(
        val schema: Int,
        val catalogVersion: Int,
        val editions: Map<String, List<Pack>>,
    )

    const val currentSchema = 2

    private const val cacheFilename = "verseCatalog.json"

    private var openAsset: ((String) -> InputStream)? = null
    private var cacheFile: File? = null
    private var client: CatalogClient? = null
    private var cachedDocumentLoaded = false
    private var cachedDocumentValue: Document? = null

    @Volatile
    private var downloadedVersion: Int? = null

    @Synchronized
    fun configure(
        openAsset: (String) -> InputStream,
        cacheDirectory: File?,
        client: CatalogClient? = SupabaseCatalogClient.create(),
    ) {
        this.openAsset = openAsset
        this.cacheFile = cacheDirectory?.resolve(cacheFilename)
        this.client = client
        cachedDocumentLoaded = false
        cachedDocumentValue = null
        downloadedVersion = null
    }

    fun packs(edition: String, bundledFile: String): List<Pack> {
        val cached = cachedDocument()?.editions?.get(edition)
        if (!cached.isNullOrEmpty()) return withPackNames(cached)
        return withPackNames(bundledPacks(bundledFile))
    }

    private fun withPackNames(packs: List<Pack>): List<Pack> = packs.map { pack ->
        pack.copy(verses = pack.verses.map { it.copy(packName = pack.name) })
    }

    private fun bundledPacks(filename: String): List<Pack> {
        val open = openAsset ?: error("VerseCatalog is not configured.")
        val text = try {
            open(filename).use { it.readBytes().decodeToString() }
        } catch (e: Exception) {
            throw IllegalStateException("Couldn't find $filename in assets.", e)
        }
        return try {
            ProgressJson.decodeFromString(ListSerializer(Pack.serializer()), text)
        } catch (e: Exception) {
            throw IllegalStateException("Couldn't parse $filename", e)
        }
    }

    @Synchronized
    private fun cachedDocument(): Document? {
        if (!cachedDocumentLoaded) {
            cachedDocumentValue = readCache()
            cachedDocumentLoaded = true
        }
        return cachedDocumentValue
    }

    private fun readCache(): Document? {
        val file = cacheFile ?: return null
        val text = try {
            file.readText()
        } catch (_: Exception) {
            return null
        }
        val document = try {
            ProgressJson.decodeFromString(Document.serializer(), text)
        } catch (_: Exception) {
            file.delete()
            return null
        }
        if (document.schema != currentSchema) {
            file.delete()
            return null
        }
        return document
    }

    val installedVersion: Int
        get() = downloadedVersion ?: cachedDocument()?.catalogVersion ?: 0

    suspend fun refreshIfNeeded() {
        val client = synchronized(this) { client } ?: return
        withContext(Dispatchers.IO) {
            try {
                val remoteVersion = client.catalogVersion() ?: return@withContext
                if (remoteVersion == installedVersion) return@withContext
                val document = client.fetchCatalog(remoteVersion)
                if (!isComplete(document)) return@withContext
                val file = cacheFile ?: return@withContext
                writeAtomically(file, ProgressJson.encodeToString(Document.serializer(), document))
                downloadedVersion = remoteVersion
            } catch (e: CancellationException) {
                throw e
            } catch (_: Exception) {
                return@withContext
            }
        }
    }

    private fun isComplete(document: Document): Boolean =
        document.editions.isNotEmpty() && document.editions.values.all { packs ->
            packs.isNotEmpty() && packs.all { pack ->
                pack.verses.isNotEmpty() && pack.verses.all { !it.cardUid.isNullOrEmpty() }
            }
        }

    private fun writeAtomically(file: File, text: String) {
        file.parentFile?.mkdirs()
        val temporary = File.createTempFile(file.name, ".tmp", file.parentFile)
        try {
            temporary.writeText(text)
            Files.move(
                temporary.toPath(),
                file.toPath(),
                StandardCopyOption.ATOMIC_MOVE,
                StandardCopyOption.REPLACE_EXISTING,
            )
        } finally {
            temporary.delete()
        }
    }
}
