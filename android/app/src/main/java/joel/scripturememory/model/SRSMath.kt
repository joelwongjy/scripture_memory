package joel.scripturememory.model

import kotlin.math.max
import kotlin.math.min

object SRSMath {

    fun dripBudget(budget: Int, across: List<Int>): List<Int> {
        var remaining = max(0, budget)
        return across.map { raw ->
            val available = max(0, raw)
            val take = min(remaining, available)
            remaining -= take
            take
        }
    }
}
