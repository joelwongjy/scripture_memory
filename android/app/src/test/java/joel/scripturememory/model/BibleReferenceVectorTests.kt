package joel.scripturememory.model

import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.contentOrNull
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class BibleReferenceVectorTests {

    private val vectors: JsonObject by lazy {
        Json.parseToJsonElement(Repo.vectors.resolve("bible_reference.json").readText()).jsonObject
    }

    private fun JsonObject.cases(name: String): List<JsonObject> {
        val cases = getValue(name).jsonArray.map { it.jsonObject }
        assertTrue("$name is empty", cases.isNotEmpty())
        return cases
    }

    private fun JsonObject.optional(key: String): String? = (get(key) as? JsonPrimitive)?.contentOrNull

    @Test
    fun testVectors() {
        for (case in vectors.cases("references")) {
            val input = case.getValue("input").jsonPrimitive.content
            val reference = BibleReference.parse(input)
            assertEquals("$input display", case.optional("display"), reference?.display)
            assertEquals("$input usfm", case.optional("usfm"), reference?.usfm)
        }
        for (case in vectors.cases("pastes")) {
            val input = case.getValue("input").jsonPrimitive.content
            val pasted = PastedVerse.parse(input)
            assertEquals("$input reference", case.optional("reference"), pasted.reference?.display)
            assertEquals("$input version", case.optional("version"), pasted.version)
            assertEquals("$input text", case.getValue("text").jsonPrimitive.content, pasted.text)
        }
    }

    @Test
    fun testSingleChapterBookTakesTheNumberAsVerse() {
        assertEquals("Jude 1:3", BibleReference.parse("Jude 3")?.display)
    }

    @Test
    fun testAnkiPlanMatchesBundledVersesAndKeepsTheRest() {
        val review = AnkiCardSchedule(
            kind = AnkiCardSchedule.Kind.Review,
            isSuspended = false,
            intervalDays = 37.0,
            ease = 2.35,
            due = Date.fromTimeIntervalSince1970(1_800_000_000.0),
            reps = 6,
            lapses = 1,
            lastReviewed = Date.fromTimeIntervalSince1970(1_796_800_000.0),
        )
        val notes = listOf(
            AnkiNote(
                "Verses::OYO", "Basic", listOf("Front", "Back"),
                listOf("John 3:16", "For God so loved the world that he gave his one and only Son"),
                emptyList(), listOf(review),
            ),
            AnkiNote(
                "Verses::OYO", "Basic", listOf("Front", "Back"),
                listOf("Micah 6:8", "He has shown all you people what is good."),
                emptyList(), emptyList(),
            ),
            AnkiNote(
                "Verses::OYO", "Basic", listOf("Front", "Back"),
                listOf("What is grace?", "Undeserved favour"), emptyList(), emptyList(),
            ),
        )
        val key = AnkiVerseImport.referenceKey("John", "3:16")
        val plan = AnkiVerseImport.plan(AnkiImport(notes), bundledKeys = mapOf(key to "uid-john"))
        assertEquals(listOf("uid-john"), plan.matches.map { it.cardUid })
        assertEquals(listOf("OYO"), plan.decks.map { it.name })
        assertEquals(listOf("Micah 6:8"), plan.decks.firstOrNull()?.verses?.map { it.reference.display })
        assertEquals(1, plan.skipped.size)
        val state = AnkiVerseImport.state(review, "k", Date.now())
        assertEquals(SRSPhase.review, state?.phase)
        assertEquals(37.0, state?.interval ?: 0.0, 0.0)
        assertEquals(2.35, state?.ease ?: 0.0, 0.0)
    }

    @Test
    fun testAnkiPlanReadsVersionFieldsAndReferencesWithVersions() {
        val notes = listOf(
            AnkiNote(
                "Verses", "Bible Verse", listOf("Reference", "Text", "Version", "Notes"),
                listOf("Psalm 23:1", "The LORD is my shepherd, I lack nothing.", "NIV", "Shepherd"),
                emptyList(), emptyList(),
            ),
            AnkiNote(
                "Verses", "Basic (and reversed card)", listOf("Front", "Back"),
                listOf("I can do all this through him who gives me strength.", "Phil 4:13 (ESV)"),
                emptyList(), emptyList(),
            ),
        )
        val verses = AnkiVerseImport.plan(AnkiImport(notes)).decks.flatMap { it.verses }
        assertEquals(listOf("Psalm 23:1", "Philippians 4:13"), verses.map { it.reference.display })
        assertEquals(listOf("NIV", "ESV"), verses.map { it.version })
        assertEquals(listOf("Shepherd", ""), verses.map { it.title })
        assertEquals("I can do all this through him who gives me strength.", verses.lastOrNull()?.text)
    }
}
