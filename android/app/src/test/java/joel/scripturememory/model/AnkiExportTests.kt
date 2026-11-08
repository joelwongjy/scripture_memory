package joel.scripturememory.model

import java.time.ZoneId
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class AnkiExportTests {

    private val zone = ZoneId.of("Asia/Singapore")
    private val now = Date.fromTimeIntervalSince1970(1_794_100_000.0)

    private fun state(phase: SRSPhase, interval: Double, dueInDays: Double, reps: Int, lapses: Int) = SRSCardState(
        key = "k", phase = phase, interval = interval, ease = 2.35, reps = reps, lapses = lapses, learningStep = 0,
        due = now.addingTimeInterval(dueInDays * 86_400), lastReviewed = now.addingTimeInterval(-3 * 86_400.0),
    )

    @Test
    fun exportReadsBackWithItsSchedules() {
        val decks = listOf(
            AnkiExportDeck(
                "DEP 2: Quiet Time",
                listOf(
                    AnkiExportCard("c1", "1 Corinthians 1:9", "God wants to fellowship with us",
                        "God, who has called you into fellowship with his Son Jesus Christ our Lord, is faithful.", null,
                        state(SRSPhase.review, 12.0, 5.0, 6, 1), true),
                    AnkiExportCard("c2", "Hebrews 12:2", "Looking on the Lord", "Let us fix our eyes on Jesus.", null, null, true),
                ),
            ),
            AnkiExportDeck(
                "Mine & <Friends>",
                listOf(
                    AnkiExportCard("u1", "Romans 8:28", "", "And we know that in all things God works for the good.", "ESV",
                        state(SRSPhase.learning, 4.0, -1.0, 3, 1), true),
                    AnkiExportCard("u2", "John 3:16", "God's love", "For God so loved the world.", "NIV", null, false),
                ),
            ),
        )
        val directory = kotlin.io.path.createTempDirectory("anki-export").toFile()
        try {
            val file = directory.resolve("out.apkg").apply {
                writeBytes(AnkiPackageWriter.write(decks, directory, JdbcAnkiDatabase, now, zone))
            }
            val back = AnkiImport.read(file, JdbcAnkiDatabase, zone)
            assertEquals(listOf("Scripture Memory::DEP 2: Quiet Time", "Scripture Memory::Mine & <Friends>"), back.deckNames)
            val plan = AnkiVerseImport.plan(back)
            val verses = plan.decks.flatMap { it.verses }.associateBy { it.reference.display }
            assertEquals(listOf("DEP 2: Quiet Time", "Mine & <Friends>"), plan.decks.map { it.name })

            val review = verses.getValue("1 Corinthians 1:9").schedule!!
            assertEquals(AnkiCardSchedule.Kind.Review, review.kind)
            assertEquals(12.0, review.intervalDays, 0.0)
            assertEquals(2.35, review.ease, 1e-9)
            assertEquals(6, review.reps)
            assertEquals(1, review.lapses)
            assertEquals(now.addingTimeInterval(-3 * 86_400.0).timeIntervalSince1970, review.lastReviewed!!.timeIntervalSince1970, 0.001)
            assertEquals(now.addingTimeInterval(5 * 86_400.0).localDate(zone), review.due!!.localDate(zone))

            val learnt = verses.getValue("Hebrews 12:2").schedule!!
            assertEquals(AnkiCardSchedule.Kind.Review, learnt.kind)
            assertEquals(1.0, learnt.intervalDays, 0.0)

            val relearning = verses.getValue("Romans 8:28")
            assertEquals(AnkiCardSchedule.Kind.Relearning, relearning.schedule!!.kind)
            assertEquals(4.0, relearning.schedule!!.intervalDays, 0.0)
            assertEquals("ESV", relearning.version)

            val fresh = verses.getValue("John 3:16")
            assertEquals(AnkiCardSchedule.Kind.New, fresh.schedule!!.kind)
            assertEquals("God's love", fresh.title)
            assertNull(fresh.schedule!!.due)
        } finally {
            directory.deleteRecursively()
        }
    }

    @Test
    fun ownPacksStayOwnButBuiltInPacksMatch() {
        val keys = mapOf(
            AnkiVerseImport.referenceKey("Romans", "8:28") to "rom828",
            AnkiVerseImport.referenceKey("Hebrews", "12:2") to "heb122",
        )
        val decks = listOf(
            AnkiExportDeck("DEP 2: Quiet Time", listOf(AnkiExportCard("heb122", "Hebrews 12:2", "", "Let us fix our eyes on Jesus.", null, null, true))),
            AnkiExportDeck("Mine", listOf(AnkiExportCard("u1", "Romans 8:28", "", "And we know that in all things God works for the good.", "ESV", null, true))),
        )
        val directory = kotlin.io.path.createTempDirectory("anki-export").toFile()
        try {
            val file = directory.resolve("out.apkg").apply {
                writeBytes(AnkiPackageWriter.write(decks, directory, JdbcAnkiDatabase, now, zone))
            }
            val plan = AnkiVerseImport.plan(AnkiImport.read(file, JdbcAnkiDatabase, zone), keys, setOf("DEP 2: Quiet Time"))
            assertEquals(listOf("heb122"), plan.matches.map { it.cardUid })
            assertEquals(listOf("Mine"), plan.decks.map { it.name })
            assertEquals("Romans 8:28", plan.decks.single().verses.single().reference.display)
        } finally {
            directory.deleteRecursively()
        }
    }

    @Test
    fun creationIsTheLastFourAmRollover() {
        val crt = AnkiPackageWriter.creation(Date.fromTimeIntervalSince1970(1_794_100_000.0), zone)
        val local = java.time.Instant.ofEpochSecond(crt).atZone(zone)
        assertEquals(4, local.hour)
        assertEquals(0, local.minute)
    }
}
