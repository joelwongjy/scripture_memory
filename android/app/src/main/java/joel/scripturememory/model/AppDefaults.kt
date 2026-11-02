package joel.scripturememory.model

import androidx.compose.runtime.MutableIntState
import androidx.compose.runtime.mutableIntStateOf
import java.util.concurrent.ConcurrentHashMap

class AppDefaults(private val store: KeyValueStore) : KeyValueStore {

    private val revisions = ConcurrentHashMap<String, MutableIntState>()

    private fun revision(key: String): MutableIntState =
        revisions.getOrPut(key) { mutableIntStateOf(0) }

    private fun observe(key: String) {
        revision(key).intValue
    }

    private fun bump(key: String) {
        revision(key).intValue += 1
    }

    override fun getString(key: String): String? {
        observe(key)
        return store.getString(key)
    }

    override fun putString(key: String, value: String) {
        store.putString(key, value)
        bump(key)
    }

    override fun getInt(key: String): Int? {
        observe(key)
        return store.getInt(key)
    }

    override fun putInt(key: String, value: Int) {
        store.putInt(key, value)
        bump(key)
    }

    override fun getBool(key: String): Boolean? {
        observe(key)
        return store.getBool(key)
    }

    override fun putBool(key: String, value: Boolean) {
        store.putBool(key, value)
        bump(key)
    }

    override fun getLong(key: String): Long? {
        observe(key)
        return store.getLong(key)
    }

    override fun putLong(key: String, value: Long) {
        store.putLong(key, value)
        bump(key)
    }

    override fun getDouble(key: String): Double? {
        observe(key)
        return store.getDouble(key)
    }

    override fun putDouble(key: String, value: Double) {
        store.putDouble(key, value)
        bump(key)
    }

    override fun remove(key: String) {
        store.remove(key)
        bump(key)
    }

    companion object {
        lateinit var standard: AppDefaults
            internal set
    }
}
