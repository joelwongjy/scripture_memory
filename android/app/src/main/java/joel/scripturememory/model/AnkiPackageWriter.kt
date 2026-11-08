package joel.scripturememory.model

import java.io.ByteArrayOutputStream
import java.io.File
import java.security.MessageDigest
import java.time.Instant
import java.time.ZoneId
import java.util.zip.CRC32
import java.util.zip.ZipEntry
import java.util.zip.ZipOutputStream
import kotlin.math.floor
import kotlin.math.max
import kotlin.math.roundToLong
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive

data class AnkiExportCard(
    val id: String,
    val reference: String,
    val title: String,
    val text: String,
    val version: String?,
    val state: SRSCardState?,
    val isLearnt: Boolean,
)

data class AnkiExportDeck(val name: String, val cards: List<AnkiExportCard>)

object AnkiPackageWriter {
    const val rootDeck = AnkiVerseImport.exportRoot
    const val noteTypeName = "Scripture Memory"
    val fieldNames = listOf("Reference", "Title", "Verse", "Version")
    private const val noteTypeID = 1_731_000_000_000L
    private const val rolloverHour = 4

    data class CardRow(
        val type: Long,
        val queue: Long,
        val due: Long,
        val interval: Long,
        val factor: Long,
        val reps: Long,
        val lapses: Long,
        val left: Long,
    )

    fun write(
        decks: List<AnkiExportDeck>,
        directory: File,
        openDatabase: AnkiDatabaseOpener = AndroidAnkiDatabase,
        now: Date = Date.now(),
        zone: ZoneId = ZoneId.systemDefault(),
    ): ByteArray {
        val work = File(directory, "anki-export-${System.nanoTime()}").apply { mkdirs() }
        try {
            val file = File(work, "collection.anki2").apply { createNewFile() }
            openDatabase.open(file).use { writeCollection(decks, it, now, zone) }
            return archive(listOf("collection.anki2" to file.readBytes(), "media" to "{}".toByteArray()))
        } finally {
            work.deleteRecursively()
        }
    }

    fun creation(now: Date, zone: ZoneId): Long {
        val shifted = Instant.ofEpochSecond(floor(now.timeIntervalSince1970).toLong()).minusSeconds(rolloverHour * 3_600L)
        val day = shifted.atZone(zone).toLocalDate()
        return day.atStartOfDay(zone).plusHours(rolloverHour.toLong()).toEpochSecond()
    }

    fun schedule(card: AnkiExportCard, crt: Long, now: Date, position: Long): Pair<CardRow, Long> {
        fun day(date: Date): Long = floor((date.timeIntervalSince1970 - crt) / 86_400).toLong()
        val state = card.state
        if (state == null) {
            if (card.isLearnt) return CardRow(2, 2, day(now), 1, 2_500, 1, 0, 0) to position
            val next = position + 1
            return CardRow(0, 0, next, 0, 0, 0, 0, 0) to next
        }
        val factor = (state.ease * 1_000).roundToLong()
        val reps = state.reps.toLong()
        val lapses = state.lapses.toLong()
        val interval = max(1L, state.interval.roundToLong())
        val row = when (state.phase) {
            SRSPhase.review -> CardRow(2, 2, day(state.due), interval, factor, reps, lapses, 0)
            SRSPhase.learning -> {
                val due = floor(state.due.timeIntervalSince1970).toLong()
                if (state.interval > 0) CardRow(3, 1, due, interval, factor, reps, lapses, 1_001)
                else CardRow(1, 1, due, 0, factor, reps, lapses, 1_001)
            }
        }
        return row to position
    }

    fun html(text: String): String =
        text.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;").replace("\n", "<br>")

    fun checksum(field: String): Long {
        val digest = MessageDigest.getInstance("SHA-1").digest(field.toByteArray())
        return (0 until 4).fold(0L) { acc, i -> (acc shl 8) or (digest[i].toLong() and 0xFF) }
    }

    private fun writeCollection(decks: List<AnkiExportDeck>, database: AnkiDatabase, now: Date, zone: ZoneId) {
        val nowSeconds = floor(now.timeIntervalSince1970).toLong()
        val crt = creation(now, zone)
        val minutesWest = -zone.rules.getOffset(Instant.ofEpochSecond(nowSeconds)).totalSeconds / 60
        schema.forEach(database::execute)
        database.execute("begin")

        val deckJSON = linkedMapOf<String, JsonElement>(
            "1" to deck(1, "Default", nowSeconds),
            "${noteTypeID + 1}" to deck(noteTypeID + 1, rootDeck, nowSeconds),
        )
        var noteID = nowSeconds * 1_000
        var cardID = nowSeconds * 1_000
        val usedReviewIDs = HashSet<Long>()
        var position = 0L

        decks.forEachIndexed { index, exportDeck ->
            val deckID = noteTypeID + 2 + index
            deckJSON["$deckID"] = deck(deckID, "$rootDeck::${exportDeck.name}", nowSeconds)
            for (card in exportDeck.cards) {
                noteID += 1
                cardID += 1
                val fields = listOf(card.reference, card.title, card.text, card.version.orEmpty()).map(::html)
                database.execute(
                    "insert into notes values ($noteID, ${quote("sm-" + card.id)}, $noteTypeID, $nowSeconds, -1, " +
                        "' scripture-memory ', ${quote(fields.joinToString("\u001F"))}, ${quote(fields[0])}, " +
                        "${checksum(fields[0])}, 0, '')",
                )
                val (row, next) = schedule(card, crt, now, position)
                position = next
                database.execute(
                    "insert into cards values ($cardID, $noteID, $deckID, 0, $nowSeconds, -1, ${row.type}, ${row.queue}, " +
                        "${row.due}, ${row.interval}, ${row.factor}, ${row.reps}, ${row.lapses}, ${row.left}, 0, 0, 0, '')",
                )
                val reviewed = card.state?.lastReviewed ?: continue
                var reviewID = (reviewed.timeIntervalSince1970 * 1_000).toLong()
                while (!usedReviewIDs.add(reviewID)) reviewID += 1
                database.execute(
                    "insert into revlog values ($reviewID, $cardID, -1, 3, ${row.interval}, 0, ${row.factor}, 0, " +
                        "${if (row.type == 2L) 1 else 0})",
                )
            }
        }

        val config = JsonObject(
            sortedMapOf(
                "activeDecks" to JsonArray(listOf(JsonPrimitive(1))),
                "creationOffset" to JsonPrimitive(minutesWest),
                "curDeck" to JsonPrimitive(1),
                "nextPos" to JsonPrimitive(position + 1),
                "rollover" to JsonPrimitive(rolloverHour),
                "schedVer" to JsonPrimitive(2),
            ),
        )
        val models = JsonObject(mapOf("$noteTypeID" to noteType(nowSeconds)))
        database.execute(
            "insert into col values (1, $crt, ${nowSeconds * 1_000}, ${nowSeconds * 1_000}, 11, 0, 0, 0, " +
                "${quote(config.toString())}, ${quote(models.toString())}, ${quote(JsonObject(deckJSON).toString())}, '{}', '{}')",
        )
        database.execute("commit")
    }

    private fun quote(text: String) = "'" + text.replace("'", "''") + "'"

    private fun deck(id: Long, name: String, now: Long) = JsonObject(
        mapOf(
            "id" to JsonPrimitive(id), "name" to JsonPrimitive(name), "mod" to JsonPrimitive(now),
            "usn" to JsonPrimitive(-1), "lrnToday" to pair(), "revToday" to pair(), "newToday" to pair(),
            "timeToday" to pair(), "collapsed" to JsonPrimitive(false), "browserCollapsed" to JsonPrimitive(false),
            "desc" to JsonPrimitive(""), "dyn" to JsonPrimitive(0), "conf" to JsonPrimitive(1),
            "extendNew" to JsonPrimitive(0), "extendRev" to JsonPrimitive(0),
        ),
    )

    private fun pair() = JsonArray(listOf(JsonPrimitive(0), JsonPrimitive(0)))

    private fun noteType(now: Long) = JsonObject(
        mapOf(
            "id" to JsonPrimitive(noteTypeID), "name" to JsonPrimitive(noteTypeName), "type" to JsonPrimitive(0),
            "mod" to JsonPrimitive(now), "usn" to JsonPrimitive(-1), "sortf" to JsonPrimitive(0), "did" to JsonPrimitive(1),
            "tmpls" to JsonArray(
                listOf(
                    JsonObject(
                        mapOf(
                            "name" to JsonPrimitive("Card 1"), "ord" to JsonPrimitive(0),
                            "qfmt" to JsonPrimitive("<div class=title>{{Title}}</div><div class=reference>{{Reference}}</div>"),
                            "afmt" to JsonPrimitive("{{FrontSide}}<hr id=answer><div class=verse>{{Verse}}</div>"),
                            "bqfmt" to JsonPrimitive(""), "bafmt" to JsonPrimitive(""), "did" to JsonNull,
                        ),
                    ),
                ),
            ),
            "flds" to JsonArray(
                fieldNames.mapIndexed { index, name ->
                    JsonObject(
                        mapOf(
                            "name" to JsonPrimitive(name), "ord" to JsonPrimitive(index), "sticky" to JsonPrimitive(false),
                            "rtl" to JsonPrimitive(false), "font" to JsonPrimitive("Arial"), "size" to JsonPrimitive(20),
                        ),
                    )
                },
            ),
            "css" to JsonPrimitive(
                ".card { font-family: Georgia, serif; font-size: 22px; text-align: center; color: black; background: white; }\n" +
                    ".title { font-weight: bold; }\n.reference { margin-top: 8px; }\n.verse { text-align: left; line-height: 1.4; }",
            ),
            "latexPre" to JsonPrimitive(
                "\\documentclass[12pt]{article}\n\\special{papersize=3in,5in}\n\\usepackage[utf8]{inputenc}\n" +
                    "\\usepackage{amssymb,amsmath}\n\\pagestyle{empty}\n\\setlength{\\parindent}{0in}\n\\begin{document}\n",
            ),
            "latexPost" to JsonPrimitive("\\end{document}"), "latexsvg" to JsonPrimitive(false),
            "req" to JsonArray(listOf(JsonArray(listOf(JsonPrimitive(0), JsonPrimitive("any"), JsonArray(listOf(JsonPrimitive(0), JsonPrimitive(1))))))),
            "tags" to JsonArray(emptyList()), "vers" to JsonArray(emptyList()),
        ),
    )

    private fun archive(entries: List<Pair<String, ByteArray>>): ByteArray {
        val bytes = ByteArrayOutputStream()
        ZipOutputStream(bytes).use { zip ->
            for ((name, data) in entries) {
                val entry = ZipEntry(name).apply {
                    method = ZipEntry.STORED
                    size = data.size.toLong()
                    compressedSize = data.size.toLong()
                    crc = CRC32().apply { update(data) }.value
                }
                zip.putNextEntry(entry)
                zip.write(data)
                zip.closeEntry()
            }
        }
        return bytes.toByteArray()
    }

    private val schema = listOf(
        "create table col (id integer primary key, crt integer not null, mod integer not null, scm integer not null, ver integer not null, dty integer not null, usn integer not null, ls integer not null, conf text not null, models text not null, decks text not null, dconf text not null, tags text not null)",
        "create table notes (id integer primary key, guid text not null, mid integer not null, mod integer not null, usn integer not null, tags text not null, flds text not null, sfld integer not null, csum integer not null, flags integer not null, data text not null)",
        "create table cards (id integer primary key, nid integer not null, did integer not null, ord integer not null, mod integer not null, usn integer not null, type integer not null, queue integer not null, due integer not null, ivl integer not null, factor integer not null, reps integer not null, lapses integer not null, left integer not null, odue integer not null, odid integer not null, flags integer not null, data text not null)",
        "create table revlog (id integer primary key, cid integer not null, usn integer not null, ease integer not null, ivl integer not null, lastIvl integer not null, factor integer not null, time integer not null, type integer not null)",
        "create table graves (usn integer not null, oid integer not null, type integer not null)",
        "create index ix_notes_usn on notes (usn)",
        "create index ix_cards_usn on cards (usn)",
        "create index ix_revlog_usn on revlog (usn)",
        "create index ix_cards_nid on cards (nid)",
        "create index ix_cards_sched on cards (did, queue, due)",
        "create index ix_revlog_cid on revlog (cid)",
        "create index ix_notes_csum on notes (csum)",
    )
}
