package joel.scripturememory.model

import java.io.File
import java.time.ZoneOffset
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.boolean
import kotlinx.serialization.json.double
import kotlinx.serialization.json.doubleOrNull
import kotlinx.serialization.json.int
import kotlinx.serialization.json.intOrNull
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.long
import kotlinx.serialization.json.longOrNull
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Test

class AnkiImportTests {

    private val vectors: JsonObject by lazy {
        Json.parseToJsonElement(Repo.vectors.resolve("anki_import.json").readText()).jsonObject
    }

    private fun JsonObject.cases(name: String): List<JsonObject> {
        val cases = getValue(name).jsonArray.map { it.jsonObject }
        assertTrue("$name is empty", cases.isNotEmpty())
        return cases
    }

    private fun JsonObject.s(key: String): String = getValue(key).jsonPrimitive.content
    private fun JsonObject.b(key: String): Boolean = getValue(key).jsonPrimitive.boolean
    private fun JsonObject.strings(key: String): List<String> = getValue(key).jsonArray.map { it.jsonPrimitive.content }
    private fun JsonObject.optionalDouble(key: String): Double? = get(key)?.takeIf { it != JsonNull }?.jsonPrimitive?.doubleOrNull
    private fun JsonObject.optionalInt(key: String): Int? = get(key)?.takeIf { it != JsonNull }?.jsonPrimitive?.intOrNull
    private fun JsonObject.optionalLong(key: String): Long? = get(key)?.takeIf { it != JsonNull }?.jsonPrimitive?.longOrNull

    private fun assertCard(actual: AnkiCardSchedule, expected: JsonObject, message: String) {
        assertEquals("$message kind", expected.s("kind"), actual.kind.rawValue)
        assertEquals("$message isSuspended", expected.b("isSuspended"), actual.isSuspended)
        assertEquals("$message intervalDays", expected.getValue("intervalDays").jsonPrimitive.double, actual.intervalDays, 1e-9)
        assertEquals("$message ease", expected.getValue("ease").jsonPrimitive.double, actual.ease, 1e-9)
        assertDate("$message due", expected.optionalDouble("due"), actual.due)
        assertEquals("$message reps", expected.getValue("reps").jsonPrimitive.int, actual.reps)
        assertEquals("$message lapses", expected.getValue("lapses").jsonPrimitive.int, actual.lapses)
        assertDate("$message lastReviewed", expected.optionalDouble("lastReviewed"), actual.lastReviewed)
    }

    private fun assertDate(message: String, expected: Double?, actual: Date?) {
        if (expected == null) {
            assertNull(message, actual)
        } else {
            assertEquals(message, expected, actual?.timeIntervalSince1970 ?: Double.NaN, 1e-6)
        }
    }

    private fun assertImport(actual: AnkiImport, expected: JsonObject, message: String) {
        assertEquals("$message deckNames", expected.strings("deckNames"), actual.deckNames)
        val notes = expected.getValue("notes").jsonArray.map { it.jsonObject }
        assertEquals("$message note count", notes.size, actual.notes.size)
        notes.zip(actual.notes).forEachIndexed { index, (want, note) ->
            val label = "$message note $index"
            assertEquals("$label deck", want.s("deck"), note.deck)
            assertEquals("$label noteType", want.s("noteType"), note.noteType)
            assertEquals("$label fieldNames", want.strings("fieldNames"), note.fieldNames)
            assertEquals("$label fields", want.strings("fields"), note.fields)
            assertEquals("$label tags", want.strings("tags"), note.tags)
            val cards = want.getValue("cards").jsonArray.map { it.jsonObject }
            assertEquals("$label card count", cards.size, note.cards.size)
            cards.zip(note.cards).forEachIndexed { cardIndex, (wantCard, card) ->
                assertCard(card, wantCard, "$label card $cardIndex")
            }
        }
    }

    private fun timing(json: JsonObject) = AnkiCollectionTiming(
        creation = json.getValue("creation").jsonPrimitive.long,
        creationMinutesWest = json.optionalInt("creationMinutesWest"),
        currentMinutesWest = json.getValue("currentMinutesWest").jsonPrimitive.int,
        rolloverHour = json.optionalInt("rolloverHour"),
    )

    @Test
    fun fieldCleaning() {
        for (case in vectors.cases("cleaning")) {
            assertEquals(case.s("input"), case.s("output"), AnkiFieldCleaner.clean(case.s("input"), case.b("html")))
        }
    }

    @Test
    fun htmlDetection() {
        for (case in vectors.cases("htmlDetection")) {
            assertEquals(case.s("input"), case.b("html"), AnkiFieldCleaner.containsHTML(case.s("input")))
        }
    }

    @Test
    fun textExportFixture() {
        val export = vectors.getValue("textExport").jsonObject
        val file = Repo.vectors.resolve(export.s("file"))
        assertImport(AnkiTextExport.parse(file.readText()), export.getValue("expected").jsonObject, export.s("file"))
        assertImport(AnkiImport.read(file, JdbcAnkiDatabase), export.getValue("expected").jsonObject, "read ${export.s("file")}")
    }

    @Test
    fun textCases() {
        for (case in vectors.cases("textCases")) {
            assertImport(AnkiTextExport.parse(case.s("input")), case.getValue("expected").jsonObject, case.s("name"))
        }
    }

    @Test
    fun textErrors() {
        for (case in vectors.cases("textErrors")) {
            try {
                AnkiTextExport.parse(case.s("input"))
                fail("${case.s("name")} did not throw")
            } catch (error: AnkiImportException) {
                assertEquals(case.s("name"), AnkiImportException.Empty, error)
            }
        }
    }

    @Test
    fun schedules() {
        for (case in vectors.cases("schedules")) {
            val row = case.getValue("row").jsonObject
            val cardRow = AnkiCardRow(
                type = row.getValue("type").jsonPrimitive.int,
                queue = row.getValue("queue").jsonPrimitive.int,
                due = row.getValue("due").jsonPrimitive.long,
                interval = row.getValue("interval").jsonPrimitive.long,
                factor = row.getValue("factor").jsonPrimitive.long,
                reps = row.getValue("reps").jsonPrimitive.int,
                lapses = row.getValue("lapses").jsonPrimitive.int,
                originalDue = row.getValue("originalDue").jsonPrimitive.long,
                originalDeckID = row.getValue("originalDeckID").jsonPrimitive.long,
                lastReviewMilliseconds = row.optionalLong("lastReviewMilliseconds"),
            )
            val schedule = AnkiCardSchedule(cardRow, timing(case.getValue("timing").jsonObject))
            assertCard(schedule, case.getValue("expected").jsonObject, case.s("name"))
        }
    }

    @Test
    fun timings() {
        for (case in vectors.cases("timings")) {
            val actual = AnkiCollectionTiming(
                creation = case.getValue("creation").jsonPrimitive.long,
                schedulerVersion = case.optionalInt("schedulerVersion"),
                rollover = case.optionalInt("rollover"),
                creationOffset = case.optionalInt("creationOffset"),
                deviceMinutesWest = case.getValue("deviceMinutesWest").jsonPrimitive.int,
            )
            assertEquals(case.s("name"), timing(case.getValue("expected").jsonObject), actual)
        }
    }

    @Test
    fun packages() {
        val minutesWest = vectors.getValue("timeZoneMinutesWest").jsonPrimitive.int
        val zone = ZoneOffset.ofTotalSeconds(-minutesWest * 60)
        val expected = vectors.getValue("package").jsonObject
        for (path in vectors.getValue("packages").jsonArray.map { it.jsonPrimitive.content }) {
            assertImport(AnkiImport.read(Repo.vectors.resolve(path), JdbcAnkiDatabase, zone), expected, path)
        }
    }

    @Test
    fun unreadableAndUnsupportedFiles() {
        val directory = createTempDir()
        try {
            val notZip = directory.resolve("broken.apkg").apply { writeText("not a zip") }
            val truncated = directory.resolve("truncated.apkg").apply {
                writeBytes(Repo.vectors.resolve("anki/legacy.apkg").readBytes().copyOf(700))
            }
            val noCollection = directory.resolve("media.apkg").apply {
                java.util.zip.ZipOutputStream(outputStream()).use { zip ->
                    zip.putNextEntry(java.util.zip.ZipEntry("media"))
                    zip.write("{}".toByteArray())
                    zip.closeEntry()
                }
            }
            val missing = directory.resolve("missing.apkg")
            for (file in listOf(notZip, truncated, missing)) {
                try {
                    AnkiImport.read(file, JdbcAnkiDatabase)
                    fail("${file.name} did not throw")
                } catch (error: AnkiImportException) {
                    assertEquals(file.name, AnkiImportException.Unreadable, error)
                }
            }
            try {
                AnkiImport.read(noCollection, JdbcAnkiDatabase)
                fail("media.apkg did not throw")
            } catch (error: AnkiImportException) {
                assertTrue(error is AnkiImportException.Unsupported)
            }
        } finally {
            directory.deleteRecursively()
        }
    }

    private fun createTempDir(): File =
        File(System.getProperty("java.io.tmpdir"), "anki-test-${System.nanoTime()}").apply { mkdirs() }
}
