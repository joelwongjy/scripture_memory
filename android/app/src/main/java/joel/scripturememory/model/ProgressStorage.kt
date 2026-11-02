package joel.scripturememory.model

import kotlinx.serialization.KSerializer
import kotlinx.serialization.builtins.ListSerializer
import kotlinx.serialization.builtins.serializer
import kotlinx.serialization.json.Json
import kotlinx.serialization.serializer

val ProgressJson: Json = Json {
    ignoreUnknownKeys = true
    explicitNulls = false
    encodeDefaults = true
}

class ProgressStorage(private val local: KeyValueStore) {

    fun string(key: String): String? = local.getString(key)

    fun stringArray(key: String): List<String>? {
        val raw = local.getString(key) ?: return null
        return try {
            ProgressJson.decodeFromString(stringList, raw)
        } catch (_: Exception) {
            null
        }
    }

    fun <T> decode(serializer: KSerializer<T>, key: String): T? {
        val raw = local.getString(key) ?: return null
        return try {
            ProgressJson.decodeFromString(serializer, raw)
        } catch (_: Exception) {
            null
        }
    }

    inline fun <reified T> decode(key: String): T? = decode(serializer<T>(), key)

    fun set(value: String?, key: String) {
        if (value != null) local.putString(key, value) else local.remove(key)
    }

    fun set(value: List<String>?, key: String) {
        if (value != null) {
            local.putString(key, ProgressJson.encodeToString(stringList, value))
        } else {
            local.remove(key)
        }
    }

    fun <T> encode(serializer: KSerializer<T>, value: T, key: String) {
        val raw = try {
            ProgressJson.encodeToString(serializer, value)
        } catch (_: Exception) {
            return
        }
        local.putString(key, raw)
    }

    inline fun <reified T> encode(value: T, key: String) = encode(serializer<T>(), value, key)

    fun removeObject(key: String) {
        local.remove(key)
    }

    companion object {
        private val stringList = ListSerializer(String.serializer())

        lateinit var shared: ProgressStorage
            internal set
    }
}
