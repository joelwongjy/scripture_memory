package joel.scripturememory.model

import kotlin.math.max
import kotlin.math.min
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class SRSMathTests {

    @Test
    fun testReportedBugScenario() {
        assertEquals(listOf(0, 2, 0, 0), SRSMath.dripBudget(2, listOf(0, 5, 5, 5)))
    }

    @Test
    fun testKnownCases() {
        assertEquals(listOf(0, 0), SRSMath.dripBudget(0, listOf(3, 3)))
        assertEquals(listOf(0), SRSMath.dripBudget(-5, listOf(3)))
        assertEquals(listOf(0, 3), SRSMath.dripBudget(5, listOf(-2, 3)))
        assertEquals(emptyList<Int>(), SRSMath.dripBudget(5, emptyList()))
        assertEquals(listOf(2, 3), SRSMath.dripBudget(10, listOf(2, 3)))
        assertEquals(listOf(2, 1), SRSMath.dripBudget(3, listOf(2, 5)))
    }

    @Test
    fun testProperties() {
        val rng = SplitMix64(0xCAFEBABEuL)
        repeat(20_000) {
            val budget = rng.nextInt(-3, 13)
            val cands = List(rng.nextInt(0, 9)) { rng.nextInt(-2, 10) }
            val res = SRSMath.dripBudget(budget, cands)
            val avail = cands.map { max(0, it) }
            val effBudget = max(0, budget)

            assertEquals(cands.size, res.size)
            res.zip(avail).forEach { (r, a) -> assertTrue(r in 0..a) }
            assertEquals(min(effBudget, avail.sum()), res.sum())
            var spent = 0
            for (i in res.indices) {
                if (res[i] < avail[i]) {
                    assertEquals(0, effBudget - spent - res[i])
                    assertTrue(res.drop(i + 1).all { it == 0 })
                    break
                }
                spent += res[i]
            }
        }
    }
}
