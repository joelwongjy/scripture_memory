package joel.scripturememory.model

data class SharedVerseDraft(
    val packID: String?,
    val newPackName: String?,
    val title: String,
    val text: String,
    val book: String,
    val reference: String,
    val version: String?,
)

object SharedVerseDefaults {

    private const val lastPackKey = "share.lastPack.v1"
    private const val lastTranslationKey = "share.lastTranslation.v1"

    var lastPackID: String?
        get() = AppDefaults.standard.getString(lastPackKey)
        set(value) {
            if (value != null) AppDefaults.standard.putString(lastPackKey, value)
        }

    var lastTranslation: String?
        get() = AppDefaults.standard.getString(lastTranslationKey)
        set(value) {
            if (value != null) AppDefaults.standard.putString(lastTranslationKey, value)
        }
}
