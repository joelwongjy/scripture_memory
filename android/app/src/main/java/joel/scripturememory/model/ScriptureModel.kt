package joel.scripturememory.model

import java.io.File
import java.io.InputStream

object ScriptureModel {

    fun initialize(
        store: KeyValueStore,
        openAsset: (String) -> InputStream,
        cacheDirectory: File?,
        catalogClient: CatalogClient? = SupabaseCatalogClient.create(),
    ) {
        val defaults = AppDefaults(store)
        AppDefaults.standard = defaults
        ProgressStorage.shared = ProgressStorage(defaults)
        VerseCatalog.configure(openAsset, cacheDirectory, catalogClient)

        IdentityMigration.runIfNeeded(defaults)
        NewCardCap.migrateIfNeeded(defaults)

        UserPackStore.shared = UserPackStore(ProgressStorage.shared)
        PackPreferencesStore.shared = PackPreferencesStore(ProgressStorage.shared)
        SRSStore.shared = SRSStore(ProgressStorage.shared)
        StreakStore.shared = StreakStore(ProgressStorage.shared)
        LearningStore.shared = LearningStore(ProgressStorage.shared)
        FavoritesStore.shared = FavoritesStore(ProgressStorage.shared)
    }
}
