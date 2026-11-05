package joel.scripturememory.model

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue

class UserPackStore(private val storage: ProgressStorage) {

    var userPacks: List<UserPack> by mutableStateOf(emptyList())
        private set

    private class Snapshot(val packs: List<Pack>, val revision: Int)

    init {
        publish(storage.decode<List<UserPack>>(storageKey).orEmpty())
    }

    private fun publish(packs: List<UserPack>) {
        userPacks = packs
        snapshot = Snapshot(packs.map { it.pack }, snapshot.revision + 1)
    }

    private fun commit(packs: List<UserPack>) {
        publish(packs)
        storage.encode(packs, storageKey)
    }

    fun pack(id: String): UserPack? = userPacks.firstOrNull { it.id == id }

    private val reservedNames: Set<String>
        get() = (packsNIV84.map { it.name } + packsNIV11.map { it.name } + FavoritesStore.packName).toSet()

    fun availableName(proposed: String, excluding: String? = null): String {
        val base = proposed.trimmingWhitespacesAndNewlines()
        val root = base.ifEmpty { UserPack.defaultName }
        val taken = (reservedNames + userPacks.filter { it.id != excluding }.map { it.name })
            .map { it.lowercase() }
            .toSet()
        if (root.lowercase() !in taken) return root
        var n = 2
        while ("$root $n".lowercase() in taken) n += 1
        return "$root $n"
    }

    fun createPack(name: String, color: String, verses: List<UserVerse> = emptyList()): UserPack {
        val pack = UserPack(UserVerse.newID(), availableName(name), color, verses)
        commit(userPacks + pack)
        return pack
    }

    fun updatePack(id: String, name: String, color: String) {
        val i = userPacks.indexOfFirst { it.id == id }
        if (i < 0) return
        val oldName = userPacks[i].name
        val newName = availableName(name, excluding = id)
        commit(userPacks.toMutableList().also { it[i] = it[i].copy(name = newName, color = color) })
        if (oldName != newName) {
            PackPreferencesStore.shared.renamePack(oldName, newName)
            SRSStore.shared.renamePack(oldName, newName)
            PackPositions.renamePack(oldName, newName)
        }
    }

    fun deletePack(id: String) {
        commit(userPacks.filter { it.id != id })
    }

    fun addVerse(verse: UserVerse, packID: String) {
        mutate(packID) { it.copy(verses = it.verses + verse) }
    }

    fun updateVerse(verse: UserVerse, packID: String) {
        mutate(packID) { pack ->
            val i = pack.verses.indexOfFirst { it.id == verse.id }
            if (i < 0) pack else pack.copy(verses = pack.verses.toMutableList().also { it[i] = verse })
        }
    }

    fun deleteVerses(ids: Set<String>, packID: String) {
        mutate(packID) { pack -> pack.copy(verses = pack.verses.filterNot { it.id in ids }) }
    }

    fun moveVerses(packID: String, source: Set<Int>, destination: Int) {
        mutate(packID) { pack ->
            val verses = pack.verses.toMutableList()
            val moving = source.sorted().map { verses[it] }
            for (i in source.sortedDescending()) verses.removeAt(i)
            val before = source.count { it < destination }
            verses.addAll((destination - before).coerceIn(0, verses.size), moving)
            pack.copy(verses = verses)
        }
    }

    fun addShared(draft: SharedVerseDraft) {
        val verse = UserVerse(UserVerse.newID(), draft.title, draft.text, draft.book, draft.reference, draft.version)
        val packs = userPacks.toMutableList()
        val chosen = draft.packID?.let { id -> packs.indexOfFirst { it.id == id } }?.takeIf { it >= 0 }
        val name = draft.newPackName ?: UserPack.defaultName
        val i = chosen ?: packs.indexOfFirst { it.name == name }
        if (i >= 0) {
            packs[i] = packs[i].copy(verses = packs[i].verses + verse)
        } else {
            packs += UserPack(UserVerse.newID(), availableName(name), UserPack.colors[0], listOf(verse))
        }
        commit(packs)
    }

    private fun mutate(packID: String, change: (UserPack) -> UserPack) {
        val i = userPacks.indexOfFirst { it.id == packID }
        if (i < 0) return
        commit(userPacks.toMutableList().also { it[i] = change(it[i]) })
    }

    companion object {
        lateinit var shared: UserPackStore
            internal set

        private const val storageKey = "userPacks.v1"

        private var snapshot: Snapshot by mutableStateOf(Snapshot(emptyList(), 0))

        val packs: List<Pack> get() = snapshot.packs

        val revision: Int get() = snapshot.revision
    }
}
