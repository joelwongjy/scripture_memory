package joel.scripturememory.model

import com.sun.net.httpserver.HttpServer
import java.io.File
import java.io.IOException
import java.net.InetSocketAddress
import java.nio.file.Files
import kotlinx.coroutines.test.runTest
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

private fun editions(title: String = "Remote"): Map<String, List<Pack>> = mapOf(
    "NIV84" to listOf(
        Pack("Remote Pack", "#111111", "R", listOf(verse(1, packName = "", title = title))),
    ),
)

class VerseCatalogTests {

    private class FakeClient(
        var version: Int? = 7,
        var document: VerseCatalog.Document? = null,
        var failure: Exception? = null,
    ) : CatalogClient {
        var fetches = 0

        override fun catalogVersion(): Int? {
            failure?.let { throw it }
            return version
        }

        override fun fetchCatalog(version: Int): VerseCatalog.Document {
            fetches += 1
            return document ?: VerseCatalog.Document(VerseCatalog.currentSchema, version, editions())
        }
    }

    private lateinit var directory: File
    private val cache get() = directory.resolve("verseCatalog.json")

    @Before
    fun setUp() {
        directory = Files.createTempDirectory("catalog").toFile()
    }

    @After
    fun tearDown() {
        directory.deleteRecursively()
        installModel()
    }

    private fun configure(client: CatalogClient? = null) {
        VerseCatalog.configure(Repo::openAsset, directory, client)
    }

    private fun writeCache(schema: Int = VerseCatalog.currentSchema, version: Int = 3) {
        val document = VerseCatalog.Document(schema, version, editions())
        cache.writeText(ProgressJson.encodeToString(VerseCatalog.Document.serializer(), document))
    }

    private fun bundled() = VerseCatalog.packs("NIV84", "verseData.json")

    @Test
    fun bundledJsonIsTheFloor() {
        configure()
        val packs = bundled()
        assertEquals(15, packs.size)
        assertEquals(487, packs.sumOf { it.verses.size })
        assertEquals(0, VerseCatalog.installedVersion)
    }

    @Test
    fun packNamesAreBackFilled() {
        configure()
        for (pack in bundled()) assertTrue(pack.verses.all { it.packName == pack.name })
    }

    @Test
    fun everyBundledVerseHasAPermanentId() {
        configure()
        val verses = bundled().flatMap { it.verses }
        assertTrue(verses.all { !it.cardUid.isNullOrEmpty() })
        assertEquals(verses.size, verses.map { it.srsKey }.toSet().size)
    }

    @Test
    fun validCacheShadowsTheBundle() {
        writeCache()
        configure()
        assertEquals(listOf("Remote Pack"), bundled().map { it.name })
        assertEquals("Remote Pack", bundled()[0].verses[0].packName)
        assertEquals(3, VerseCatalog.installedVersion)
    }

    @Test
    fun cacheMissingTheEditionFallsBackToTheBundle() {
        writeCache()
        configure()
        assertEquals(15, VerseCatalog.packs("NIV11", "verseDataNIV11.json").size)
    }

    @Test
    fun corruptCacheIsDiscardedNotCrashedOn() {
        cache.writeText("{truncated")
        configure()
        assertEquals(15, bundled().size)
        assertFalse(cache.exists())
    }

    @Test
    fun cacheWithoutASchemaIsDiscarded() {
        cache.writeText("""{"catalogVersion":3,"editions":{}}""")
        configure()
        assertEquals(15, bundled().size)
        assertFalse(cache.exists())
    }

    @Test
    fun cacheFromAnotherSchemaIsDiscarded() {
        writeCache(schema = 1)
        configure()
        assertEquals(15, bundled().size)
        assertFalse(cache.exists())
        assertEquals(0, VerseCatalog.installedVersion)
    }

    @Test
    fun refreshOnlyWritesTheCacheAndTheSessionKeepsItsCatalog() = runTest {
        configure(FakeClient(version = 7))
        assertEquals(15, bundled().size)

        VerseCatalog.refreshIfNeeded()

        assertTrue(cache.exists())
        assertEquals(7, VerseCatalog.installedVersion)
        assertEquals(15, bundled().size)

        configure()
        assertEquals(listOf("Remote Pack"), bundled().map { it.name })
        assertEquals(7, VerseCatalog.installedVersion)
    }

    @Test
    fun refreshDoesNotDownloadTwice() = runTest {
        val client = FakeClient(version = 7)
        configure(client)
        VerseCatalog.refreshIfNeeded()
        VerseCatalog.refreshIfNeeded()
        assertEquals(1, client.fetches)
    }

    @Test
    fun aVersionMovingBackwardsStillUpdates() = runTest {
        writeCache(version = 9)
        val client = FakeClient(version = 1)
        configure(client)
        VerseCatalog.refreshIfNeeded()
        assertEquals(1, client.fetches)
        assertEquals(1, VerseCatalog.installedVersion)
    }

    @Test
    fun missingRemoteVersionDoesNothing() = runTest {
        val client = FakeClient(version = null)
        configure(client)
        VerseCatalog.refreshIfNeeded()
        assertEquals(0, client.fetches)
        assertFalse(cache.exists())
    }

    @Test
    fun incompleteCatalogsAreRejected() = runTest {
        val empty = Pack("Empty", "#", "", emptyList())
        val anonymous = Pack("Anon", "#", "", listOf(verse(1).copy(cardUid = null)))
        val blank = Pack("Blank", "#", "", listOf(verse(1).copy(cardUid = "")))
        val rejected = listOf(
            emptyMap(),
            mapOf("NIV84" to emptyList()),
            mapOf("NIV84" to listOf(empty)),
            mapOf("NIV84" to listOf(anonymous)),
            mapOf("NIV84" to listOf(blank)),
            editions() + ("NIV11" to emptyList()),
        )
        for (document in rejected) {
            val client = FakeClient(
                version = 7,
                document = VerseCatalog.Document(VerseCatalog.currentSchema, 7, document),
            )
            configure(client)
            VerseCatalog.refreshIfNeeded()
            assertFalse(cache.exists())
            assertEquals(0, VerseCatalog.installedVersion)
        }
    }

    @Test
    fun failuresAreSilentAndKeepWhatWeHave() = runTest {
        writeCache(version = 3)
        val before = cache.readText()
        configure(FakeClient(failure = IOException("offline")))
        VerseCatalog.refreshIfNeeded()
        assertEquals(before, cache.readText())
        assertEquals(3, VerseCatalog.installedVersion)
    }

    @Test
    fun noClientMeansNoRemoteCatalog() = runTest {
        configure(null)
        VerseCatalog.refreshIfNeeded()
        assertEquals(0, VerseCatalog.installedVersion)
    }

    @Test
    fun blankConfigurationMeansNoClient() {
        assertNull(SupabaseCatalogClient.create("", "key"))
        assertNull(SupabaseCatalogClient.create("https://x", "  \n"))
        assertNotNull(SupabaseCatalogClient.create())
    }

    @Test
    fun anUnreachableServerDoesNotThrow() = runTest {
        configure(SupabaseCatalogClient.create("http://127.0.0.1:1", "key"))
        VerseCatalog.refreshIfNeeded()
        assertEquals(0, VerseCatalog.installedVersion)
        assertFalse(cache.exists())
    }

    private fun serve(respond: (path: String, query: String) -> Pair<Int, String>): HttpServer {
        val server = HttpServer.create(InetSocketAddress("127.0.0.1", 0), 0)
        server.createContext("/") { exchange ->
            val (status, body) = respond(exchange.requestURI.path, exchange.requestURI.rawQuery.orEmpty())
            val bytes = body.encodeToByteArray()
            exchange.sendResponseHeaders(status, bytes.size.toLong())
            exchange.responseBody.use { it.write(bytes) }
        }
        server.start()
        return server
    }

    private fun client(server: HttpServer) =
        SupabaseCatalogClient.create("http://127.0.0.1:${server.address.port}/", "secret-key")!!

    @Test
    fun clientSendsTheSameRequestsAsIos() {
        val seen = ArrayList<Pair<String, String>>()
        val headers = ArrayList<String?>()
        val server = HttpServer.create(InetSocketAddress("127.0.0.1", 0), 0)
        server.createContext("/") { exchange ->
            seen.add(exchange.requestURI.path to exchange.requestURI.rawQuery)
            headers.add(exchange.requestHeaders.getFirst("apikey"))
            headers.add(exchange.requestHeaders.getFirst("Authorization"))
            val body = if (exchange.requestURI.path.endsWith("catalog_meta")) "[{\"version\":12}]" else "[]"
            val bytes = body.encodeToByteArray()
            exchange.sendResponseHeaders(200, bytes.size.toLong())
            exchange.responseBody.use { it.write(bytes) }
        }
        server.start()
        try {
            val client = client(server)
            assertEquals(12, client.catalogVersion())
            client.fetchCatalog(12)
        } finally {
            server.stop(0)
        }
        assertEquals("/rest/v1/catalog_meta" to "select=version&limit=1", seen[0])
        assertEquals("/rest/v1/packs", seen[1].first)
        assertTrue(seen[1].second.startsWith("select=edition,name,color,accent_text,sort_index,verses("))
        assertTrue(seen[1].second.endsWith("&order=sort_index.asc"))
        assertEquals(listOf("secret-key", "Bearer secret-key"), headers.take(2))
    }

    @Test
    fun clientSortsPacksAndVersesAndGroupsByEdition() {
        val rows = """
            [{"edition":"NIV84","name":"B","color":"#2","accent_text":"b","sort_index":2,"verses":[
                {"verse_id":3,"card_uid":"c","sort_index":1,"title":"t","verse":"v","book":"b","reference":"r","subpack":""}]},
             {"edition":"NIV84","name":"A","color":"#1","accent_text":"a","sort_index":1,"verses":[
                {"verse_id":2,"card_uid":"b","sort_index":2,"title":"t","verse":"v","book":"b","reference":"r","subpack":"S","version":"KJV"},
                {"verse_id":1,"card_uid":"a","sort_index":1,"title":"t","verse":"v","book":"b","reference":"r","subpack":"S","extra":true}]},
             {"edition":"NIV11","name":"A","color":"#1","accent_text":"a","sort_index":1,"verses":[]}]
        """.trimIndent()
        val server = serve { _, _ -> 200 to rows }
        val document = try {
            client(server).fetchCatalog(5)
        } finally {
            server.stop(0)
        }
        assertEquals(VerseCatalog.currentSchema, document.schema)
        assertEquals(5, document.catalogVersion)
        assertEquals(listOf("A", "B"), document.editions.getValue("NIV84").map { it.name })
        assertEquals(listOf(1, 2), document.editions.getValue("NIV84")[0].verses.map { it.id })
        assertEquals("KJV", document.editions.getValue("NIV84")[0].verses[1].version)
        assertEquals("a", document.editions.getValue("NIV84")[0].accentText)
    }

    @Test
    fun aServerErrorIsAFailureNotAnEmptyCatalog() = runTest {
        val server = serve { _, _ -> 503 to "[]" }
        try {
            configure(client(server))
            VerseCatalog.refreshIfNeeded()
        } finally {
            server.stop(0)
        }
        assertEquals(0, VerseCatalog.installedVersion)
        assertFalse(cache.exists())
    }

    @Test
    fun endToEndRefreshOverHttpWritesAReadableCache() = runTest {
        val packRows = """
            [{"edition":"NIV84","name":"Remote","color":"#1","accent_text":"a","sort_index":1,"verses":[
                {"verse_id":1,"card_uid":"uid-1","sort_index":1,"title":"t","verse":"v","book":"b","reference":"r","subpack":""}]}]
        """.trimIndent()
        val server = serve { path, _ ->
            200 to if (path.endsWith("catalog_meta")) "[{\"version\":4}]" else packRows
        }
        try {
            configure(client(server))
            VerseCatalog.refreshIfNeeded()
        } finally {
            server.stop(0)
        }
        assertEquals(4, VerseCatalog.installedVersion)
        configure()
        assertEquals(listOf("Remote"), bundled().map { it.name })
        assertNotEquals(0, VerseCatalog.installedVersion)
    }
}
