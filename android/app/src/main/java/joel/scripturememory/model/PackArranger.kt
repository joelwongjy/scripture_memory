package joel.scripturememory.model

import kotlin.math.max
import kotlin.math.min

object PackArranger {

    fun arrangedNames(order: List<String>, all: List<String>): List<String> {
        val allSet = all.toSet()
        val result = ArrayList<String>()
        val seen = HashSet<String>()
        for (name in order) {
            if (name in allSet && name !in seen) {
                result.add(name)
                seen.add(name)
            }
        }
        for (name in all) {
            if (name !in seen) {
                result.add(name)
                seen.add(name)
            }
        }
        return result
    }

    fun visibleNames(order: List<String>, hidden: Set<String>, all: List<String>): List<String> =
        arrangedNames(order, all).filter { it !in hidden }

    fun movedOrder(arranged: List<String>, source: Set<Int>, destination: Int): List<String> {
        val names = arranged.toMutableList()
        val sorted = source.sorted()
        val moving = sorted.map { names[it] }
        for (i in sorted.asReversed()) names.removeAt(i)
        val removedBefore = source.count { it < destination }
        val insertAt = min(max(destination - removedBefore, 0), names.size)
        names.addAll(insertAt, moving)
        return names
    }
}
