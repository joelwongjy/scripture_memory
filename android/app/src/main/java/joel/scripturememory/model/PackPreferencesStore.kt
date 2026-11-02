package joel.scripturememory.model

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue

class PackPreferencesStore(private val storage: ProgressStorage) {

    var order: List<String> by mutableStateOf(storage.stringArray(orderKey).orEmpty())
        private set

    var hidden: Set<String> by mutableStateOf(storage.stringArray(hiddenKey).orEmpty().toSet())
        private set

    fun isHidden(name: String): Boolean = name in hidden

    fun visible(packs: List<Pack>): List<Pack> =
        reorder(packs, PackArranger.visibleNames(order, hidden, packs.map { it.name }))

    fun arranged(packs: List<Pack>): List<Pack> =
        reorder(packs, PackArranger.arrangedNames(order, packs.map { it.name }))

    fun setHidden(name: String, isHidden: Boolean) {
        hidden = if (isHidden) hidden + name else hidden - name
        storage.set(hidden.toList(), hiddenKey)
    }

    fun move(arranged: List<Pack>, source: Set<Int>, destination: Int) {
        order = PackArranger.movedOrder(arranged.map { it.name }, source, destination)
        storage.set(order, orderKey)
    }

    fun reset() {
        order = emptyList()
        hidden = emptySet()
        storage.removeObject(orderKey)
        storage.removeObject(hiddenKey)
    }

    val hasCustomization: Boolean get() = order.isNotEmpty() || hidden.isNotEmpty()

    private fun reorder(packs: List<Pack>, names: List<String>): List<Pack> {
        val byName = HashMap<String, Pack>()
        for (pack in packs) byName.putIfAbsent(pack.name, pack)
        return names.mapNotNull { byName[it] }
    }

    companion object {
        lateinit var shared: PackPreferencesStore
            internal set

        private const val orderKey = "packs.order.v1"
        private const val hiddenKey = "packs.hidden.v1"
    }
}
