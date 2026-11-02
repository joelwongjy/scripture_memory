package joel.scripturememory.model

interface KeyValueStore {
    fun getString(key: String): String?
    fun putString(key: String, value: String)
    fun getInt(key: String): Int?
    fun putInt(key: String, value: Int)
    fun getBool(key: String): Boolean?
    fun putBool(key: String, value: Boolean)
    fun getLong(key: String): Long?
    fun putLong(key: String, value: Long)
    fun getDouble(key: String): Double?
    fun putDouble(key: String, value: Double)
    fun remove(key: String)
}
