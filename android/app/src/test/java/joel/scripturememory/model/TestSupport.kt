package joel.scripturememory.model

import java.io.File
import java.io.InputStream
import java.time.DayOfWeek
import java.time.ZoneId
import java.time.ZoneOffset
import java.util.Locale
import kotlin.random.Random

class SplitMix64(seed: ULong) : Random() {
    private var state = seed

    private fun next(): ULong {
        state += 0x9E3779B97F4A7C15uL
        var z = state
        z = (z xor (z shr 30)) * 0xBF58476D1CE4E5B9uL
        z = (z xor (z shr 27)) * 0x94D049BB133111EBuL
        return z xor (z shr 31)
    }

    override fun nextBits(bitCount: Int): Int =
        if (bitCount == 0) 0 else (next() shr (64 - bitCount)).toInt()
}

class InMemoryStore : KeyValueStore {
    val values = HashMap<String, Any>()

    override fun getString(key: String): String? = values[key] as? String
    override fun putString(key: String, value: String) { values[key] = value }
    override fun getInt(key: String): Int? = values[key] as? Int
    override fun putInt(key: String, value: Int) { values[key] = value }
    override fun getBool(key: String): Boolean? = values[key] as? Boolean
    override fun putBool(key: String, value: Boolean) { values[key] = value }
    override fun getLong(key: String): Long? = values[key] as? Long
    override fun putLong(key: String, value: Long) { values[key] = value }
    override fun getDouble(key: String): Double? = values[key] as? Double
    override fun putDouble(key: String, value: Double) { values[key] = value }
    override fun remove(key: String) { values.remove(key) }
}

class TestClock(
    var date: Date,
    override var zone: ZoneId = ZoneOffset.UTC,
    override var locale: Locale = Locale.US,
    override var firstDayOfWeek: DayOfWeek = DayOfWeek.SUNDAY,
) : AppClock {
    override fun now(): Date = date

    fun advance(seconds: Double) {
        date = date.addingTimeInterval(seconds)
    }
}

object Repo {
    val root: File by lazy {
        var dir: File? = File("").absoluteFile
        while (dir != null && !dir.resolve("shared/test-vectors").isDirectory) dir = dir.parentFile
        checkNotNull(dir) { "shared/test-vectors not found above the test working directory" }
    }

    val vectors: File get() = root.resolve("shared/test-vectors")

    fun openAsset(name: String): InputStream =
        root.resolve("scripture memory/Resources/$name").inputStream()
}

fun installModel(
    clock: AppClock = TestClock(Date.fromTimeIntervalSince1970(1_800_000_000.0)),
    store: KeyValueStore = InMemoryStore(),
    cacheDirectory: File? = null,
    catalogClient: CatalogClient? = null,
) {
    AppClock.current = clock
    ScriptureModel.initialize(store, Repo::openAsset, cacheDirectory, catalogClient)
}

fun verse(
    id: Int,
    packName: String = "Pack",
    title: String = "Title $id",
    text: String = "Verse $id",
    subpack: String = "",
) = Verse(
    id = id,
    title = title,
    verse = text,
    book = "Book",
    reference = "1:$id",
    subpack = subpack,
    cardUid = "uid-$id",
    packName = packName,
)

fun pack(name: String, vararg ids: Int) =
    Pack(name, "#000000", "", ids.map { verse(it, packName = name) })
