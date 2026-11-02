package joel.scripturememory.model

import android.content.Context
import android.content.SharedPreferences

class SharedPrefsStore(private val preferences: SharedPreferences) : KeyValueStore {

    constructor(context: Context) : this(
        context.getSharedPreferences(FILE_NAME, Context.MODE_PRIVATE),
    )

    override fun getString(key: String): String? = read(key) { preferences.getString(key, null) }

    override fun putString(key: String, value: String) {
        preferences.edit().putString(key, value).apply()
    }

    override fun getInt(key: String): Int? = read(key) { preferences.getInt(key, 0) }

    override fun putInt(key: String, value: Int) {
        preferences.edit().putInt(key, value).apply()
    }

    override fun getBool(key: String): Boolean? = read(key) { preferences.getBoolean(key, false) }

    override fun putBool(key: String, value: Boolean) {
        preferences.edit().putBoolean(key, value).apply()
    }

    override fun getLong(key: String): Long? = read(key) { preferences.getLong(key, 0L) }

    override fun putLong(key: String, value: Long) {
        preferences.edit().putLong(key, value).apply()
    }

    override fun getDouble(key: String): Double? =
        read(key) { Double.fromBits(preferences.getLong(key, 0L)) }

    override fun putDouble(key: String, value: Double) {
        preferences.edit().putLong(key, value.toRawBits()).apply()
    }

    override fun remove(key: String) {
        preferences.edit().remove(key).apply()
    }

    private inline fun <T> read(key: String, value: () -> T?): T? {
        if (!preferences.contains(key)) return null
        return try {
            value()
        } catch (_: ClassCastException) {
            null
        }
    }

    private companion object {
        const val FILE_NAME = "scripture_memory"
    }
}
