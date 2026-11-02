package joel.scripturememory.model

object IdentityMigration {

    private const val completionKey = "identity.cardUidMigration.v1"

    fun runIfNeeded(defaults: KeyValueStore = AppDefaults.standard) {
        if (defaults.getBool(completionKey) == true) return
        defaults.putBool(completionKey, true)
    }
}
