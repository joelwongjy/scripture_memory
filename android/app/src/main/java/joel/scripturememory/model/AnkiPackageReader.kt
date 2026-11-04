package joel.scripturememory.model

import android.database.Cursor
import android.database.sqlite.SQLiteDatabase
import com.github.luben.zstd.ZstdInputStream
import java.io.Closeable
import java.io.File
import java.io.IOException
import java.io.RandomAccessFile
import java.nio.ByteBuffer
import java.nio.charset.CharacterCodingException
import java.nio.charset.CodingErrorAction
import java.time.Instant
import java.time.ZoneId
import java.util.zip.ZipFile
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.doubleOrNull
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject

interface AnkiDatabase : Closeable {
    fun rows(sql: String): List<List<Any?>>

    fun execute(sql: String)
}

fun interface AnkiDatabaseOpener {
    fun open(file: File): AnkiDatabase
}

object AndroidAnkiDatabase : AnkiDatabaseOpener {
    override fun open(file: File): AnkiDatabase {
        val database = SQLiteDatabase.openDatabase(
            file.path,
            null,
            SQLiteDatabase.OPEN_READWRITE or SQLiteDatabase.NO_LOCALIZED_COLLATORS,
        )
        return object : AnkiDatabase {
            override fun rows(sql: String): List<List<Any?>> =
                database.rawQuery(sql, null).use { cursor ->
                    val rows = mutableListOf<List<Any?>>()
                    while (cursor.moveToNext()) {
                        rows += (0 until cursor.columnCount).map { value(cursor, it) }
                    }
                    rows
                }

            override fun execute(sql: String) = database.execSQL(sql)

            override fun close() = database.close()
        }
    }

    private fun value(cursor: Cursor, column: Int): Any? = when (cursor.getType(column)) {
        Cursor.FIELD_TYPE_INTEGER -> cursor.getLong(column)
        Cursor.FIELD_TYPE_FLOAT -> cursor.getDouble(column)
        Cursor.FIELD_TYPE_STRING -> cursor.getString(column)
        Cursor.FIELD_TYPE_BLOB -> cursor.getBlob(column)
        else -> null
    }
}

fun AnkiImport.Companion.read(
    file: File,
    openDatabase: AnkiDatabaseOpener = AndroidAnkiDatabase,
    zone: ZoneId = ZoneId.systemDefault(),
): AnkiImport {
    if (!file.isFile) throw AnkiImportException.Unreadable
    return when (file.extension.lowercase()) {
        "apkg", "colpkg" -> AnkiPackageReader.read(file, openDatabase, zone)
        "txt", "tsv", "csv" -> AnkiPackageReader.readText(file)
        else -> if (AnkiPackageReader.isZip(file)) {
            AnkiPackageReader.read(file, openDatabase, zone)
        } else {
            AnkiPackageReader.readText(file)
        }
    }
}

object AnkiPackageReader {
    private val collectionNames = listOf("collection.anki21b", "collection.anki21", "collection.anki2")
    private val zipSignature = byteArrayOf(0x50, 0x4B, 0x03, 0x04)
    private val sqliteHeader = "SQLite format 3\u0000".toByteArray()

    fun isZip(file: File): Boolean = try {
        val bytes = ByteArray(zipSignature.size)
        file.inputStream().use { it.read(bytes) } == bytes.size && bytes.contentEquals(zipSignature)
    } catch (_: IOException) {
        false
    }

    fun readText(file: File): AnkiImport {
        val text = try {
            Charsets.UTF_8.newDecoder()
                .onMalformedInput(CodingErrorAction.REPORT)
                .onUnmappableCharacter(CodingErrorAction.REPORT)
                .decode(ByteBuffer.wrap(file.readBytes()))
                .toString()
        } catch (_: CharacterCodingException) {
            throw AnkiImportException.Unreadable
        } catch (_: IOException) {
            throw AnkiImportException.Unreadable
        }
        return AnkiTextExport.parse(text)
    }

    fun read(file: File, openDatabase: AnkiDatabaseOpener, zone: ZoneId): AnkiImport {
        val directory = File(System.getProperty("java.io.tmpdir"), "anki-${java.util.UUID.randomUUID()}")
        try {
            if (!directory.mkdirs()) throw AnkiImportException.Unreadable
            val database = directory.resolve("collection.sqlite")
            extractCollection(file, database)
            prepareHeader(database)
            return try {
                rewriteUnicase(database, openDatabase)
                openDatabase.open(database).use { AnkiCollectionReader(it, zone).read() }
            } catch (error: AnkiImportException) {
                throw error
            } catch (_: Exception) {
                throw AnkiImportException.Unreadable
            }
        } finally {
            directory.deleteRecursively()
        }
    }

    private fun extractCollection(file: File, destination: File) {
        try {
            ZipFile(file).use { zip ->
                val name = collectionNames.firstOrNull { zip.getEntry(it) != null }
                    ?: throw AnkiImportException.Unsupported("This package has no Anki collection in it.")
                zip.getInputStream(zip.getEntry(name)).use { raw ->
                    val input = if (name.endsWith("b")) ZstdInputStream(raw) else raw
                    input.use { stream -> destination.outputStream().use { stream.copyTo(it) } }
                }
            }
        } catch (error: AnkiImportException) {
            throw error
        } catch (_: IOException) {
            throw AnkiImportException.Unreadable
        }
    }

    private fun prepareHeader(database: File) {
        try {
            RandomAccessFile(database, "rw").use { access ->
                if (access.length() < 100) throw AnkiImportException.Unreadable
                val header = ByteArray(sqliteHeader.size)
                access.readFully(header)
                if (!header.contentEquals(sqliteHeader)) throw AnkiImportException.Unreadable
                for (offset in 18L..19L) {
                    access.seek(offset)
                    if (access.read() == 2) {
                        access.seek(offset)
                        access.write(1)
                    }
                }
            }
        } catch (_: IOException) {
            throw AnkiImportException.Unreadable
        }
    }

    private fun rewriteUnicase(database: File, openDatabase: AnkiDatabaseOpener) {
        openDatabase.open(database).use { connection ->
            val usesUnicase = connection.rows("select count(*) from sqlite_master where sql like '%collate unicase%'")
                .firstOrNull()?.firstOrNull().asLong() ?: 0
            if (usesUnicase == 0L) return
            connection.execute("PRAGMA writable_schema = ON")
            connection.execute(
                "UPDATE sqlite_master SET sql = replace(replace(sql, 'COLLATE unicase', 'COLLATE nocase'), " +
                    "'collate unicase', 'collate nocase') WHERE sql LIKE '%collate unicase%'",
            )
            connection.execute("PRAGMA writable_schema = OFF")
        }
    }
}

private fun Any?.asLong(): Long? = when (this) {
    is Number -> toLong()
    is String -> toLongOrNull()
    else -> null
}

private fun Any?.asText(): String? = when (this) {
    is String -> this
    is ByteArray -> decodeToString()
    is Long, is Int -> toString()
    else -> null
}

private fun Any?.asBytes(): ByteArray? = when (this) {
    is ByteArray -> this
    is String -> encodeToByteArray()
    else -> null
}

private class AnkiCollectionReader(private val database: AnkiDatabase, private val zone: ZoneId) {
    private class NoteType(val name: String, val fieldNames: List<String>)

    fun read(): AnkiImport {
        val isModern = database.rows("select name from sqlite_master where type = 'table' and name = 'notetypes'")
            .isNotEmpty()
        val config = if (isModern) modernConfig() else legacyConfig()
        val creation = database.rows("select crt from col").firstOrNull()?.firstOrNull().asLong()
            ?: throw AnkiImportException.Unreadable
        val timing = AnkiCollectionTiming(
            creation = creation,
            schedulerVersion = integer(config["schedVer"]),
            rollover = integer(config["rollover"]),
            creationOffset = integer(config["creationOffset"]),
            deviceMinutesWest = -zone.rules.getOffset(Instant.now()).totalSeconds / 60,
        )
        val noteTypes = if (isModern) modernNoteTypes() else legacyNoteTypes()
        val decks = if (isModern) modernDecks() else legacyDecks()

        val lastReviews = mutableMapOf<Long, Long>()
        for (row in database.rows("select cid, max(id) from revlog where ease > 0 group by cid")) {
            val card = row[0].asLong()
            val stamp = row[1].asLong()
            if (card != null && stamp != null) lastReviews[card] = stamp
        }

        val cardsByNote = mutableMapOf<Long, MutableList<Pair<Long, AnkiCardSchedule>>>()
        val cardRows = database.rows(
            "select nid, did, type, queue, due, ivl, factor, reps, lapses, odue, odid, id from cards order by nid, ord, id",
        )
        for (row in cardRows) {
            val values = row.map { it.asLong() ?: 0L }
            val cardRow = AnkiCardRow(
                type = values[2].toInt(),
                queue = values[3].toInt(),
                due = values[4],
                interval = values[5],
                factor = values[6],
                reps = values[7].toInt(),
                lapses = values[8].toInt(),
                originalDue = values[9],
                originalDeckID = values[10],
                lastReviewMilliseconds = lastReviews[values[11]],
            )
            val deck = if (values[10] != 0L) values[10] else values[1]
            cardsByNote.getOrPut(values[0]) { mutableListOf() } += deck to AnkiCardSchedule(cardRow, timing)
        }

        val notes = mutableListOf<AnkiNote>()
        for (row in database.rows("select id, mid, tags, flds from notes order by id")) {
            val id = row[0].asLong() ?: continue
            val typeID = row[1].asLong() ?: continue
            val noteType = noteTypes[typeID]
            val fieldNames = (noteType?.fieldNames ?: emptyList()).toMutableList()
            val fields = (row[3].asText() ?: "").split('\u001F').map { AnkiFieldCleaner.clean(it) }.toMutableList()
            while (fieldNames.size < fields.size) fieldNames += "Field ${fieldNames.size + 1}"
            while (fields.size < fieldNames.size) fields += ""
            val cards = cardsByNote[id] ?: emptyList()
            notes += AnkiNote(
                deck = cards.firstOrNull()?.let { decks[it.first] } ?: "",
                noteType = noteType?.name ?: "",
                fieldNames = fieldNames,
                fields = fields,
                tags = (row[2].asText() ?: "").splitOnWhitespace(),
                cards = cards.map { it.second },
            )
        }
        if (notes.isEmpty()) throw AnkiImportException.Empty
        return AnkiImport(notes)
    }

    private fun integer(value: JsonElement?): Int? {
        val primitive = value as? JsonPrimitive ?: return null
        if (primitive.isString || primitive.content == "true" || primitive.content == "false") return null
        return primitive.doubleOrNull?.toInt()
    }

    private fun parseObject(text: String?): JsonObject =
        text?.let { runCatching { Json.parseToJsonElement(it).jsonObject }.getOrNull() } ?: JsonObject(emptyMap())

    private fun legacyColumn(name: String): JsonObject =
        parseObject(database.rows("select $name from col").firstOrNull()?.firstOrNull().asText())

    private fun legacyConfig(): Map<String, JsonElement> = legacyColumn("conf")

    private fun modernConfig(): Map<String, JsonElement> {
        val config = mutableMapOf<String, JsonElement>()
        for (row in database.rows("select key, val from config")) {
            val key = row[0].asText() ?: continue
            val bytes = row[1].asBytes() ?: continue
            config[key] = runCatching { Json.parseToJsonElement(bytes.decodeToString()) }.getOrNull() ?: continue
        }
        return config
    }

    private fun legacyNoteTypes(): Map<Long, NoteType> {
        val types = mutableMapOf<Long, NoteType>()
        for ((key, value) in legacyColumn("models")) {
            val id = key.toLongOrNull() ?: continue
            val model = value as? JsonObject ?: continue
            val fields = runCatching { model["flds"]?.jsonArray }.getOrNull().orEmpty()
                .mapNotNull { it as? JsonObject }
                .sortedBy { integer(it["ord"]) ?: 0 }
                .map { (it["name"] as? JsonPrimitive)?.takeIf { name -> name.isString }?.content ?: "" }
            types[id] = NoteType(stringValue(model["name"]), fields)
        }
        return types
    }

    private fun stringValue(element: JsonElement?): String =
        (element as? JsonPrimitive)?.takeIf { it.isString }?.content ?: ""

    private fun modernNoteTypes(): Map<Long, NoteType> {
        val fieldNames = mutableMapOf<Long, MutableList<String>>()
        for (row in database.rows("select ntid, name from fields order by ntid, ord")) {
            val id = row[0].asLong() ?: continue
            fieldNames.getOrPut(id) { mutableListOf() } += row[1].asText() ?: ""
        }
        val types = mutableMapOf<Long, NoteType>()
        for (row in database.rows("select id, name from notetypes")) {
            val id = row[0].asLong() ?: continue
            types[id] = NoteType(row[1].asText() ?: "", fieldNames[id] ?: emptyList())
        }
        return types
    }

    private fun legacyDecks(): Map<Long, String> {
        val decks = mutableMapOf<Long, String>()
        for ((key, value) in legacyColumn("decks")) {
            val id = key.toLongOrNull() ?: continue
            val deck = value as? JsonObject ?: continue
            decks[id] = stringValue(deck["name"])
        }
        return decks
    }

    private fun modernDecks(): Map<Long, String> {
        val decks = mutableMapOf<Long, String>()
        for (row in database.rows("select id, name from decks")) {
            val id = row[0].asLong() ?: continue
            decks[id] = (row[1].asText() ?: "").replace("\u001F", "::")
        }
        return decks
    }
}
