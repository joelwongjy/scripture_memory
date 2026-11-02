package joel.scripturememory.model

import org.junit.Assert.assertEquals
import org.junit.Test

class PackArrangerTests {

    @Test
    fun testNoOrderKeepsNatural() {
        assertEquals(listOf("a", "b", "c"), PackArranger.arrangedNames(emptyList(), listOf("a", "b", "c")))
    }

    @Test
    fun testCustomOrderApplied() {
        assertEquals(
            listOf("c", "a", "b"),
            PackArranger.arrangedNames(listOf("c", "a", "b"), listOf("a", "b", "c")),
        )
    }

    @Test
    fun testNewPacksAppendedInNaturalOrder() {
        assertEquals(
            listOf("b", "a", "c", "d"),
            PackArranger.arrangedNames(listOf("b", "a"), listOf("a", "b", "c", "d")),
        )
    }

    @Test
    fun testStaleOrderNamesIgnored() {
        assertEquals(listOf("b", "a"), PackArranger.arrangedNames(listOf("x", "b", "a"), listOf("a", "b")))
    }

    @Test
    fun testDuplicatesInOrderDeduped() {
        assertEquals(
            listOf("a", "b", "c"),
            PackArranger.arrangedNames(listOf("a", "a", "b"), listOf("a", "b", "c")),
        )
    }

    @Test
    fun testVisibleRemovesHidden() {
        assertEquals(
            listOf("c", "b"),
            PackArranger.visibleNames(listOf("c", "a", "b"), setOf("a"), listOf("a", "b", "c")),
        )
    }

    @Test
    fun testVisibleAllHidden() {
        assertEquals(
            emptyList<String>(),
            PackArranger.visibleNames(emptyList(), setOf("a", "b"), listOf("a", "b")),
        )
    }

    @Test
    fun testMoveReordering() {
        assertEquals(listOf("b", "c", "a"), PackArranger.movedOrder(listOf("a", "b", "c"), setOf(0), 3))
    }

    @Test
    fun testMoveUp() {
        assertEquals(listOf("c", "a", "b"), PackArranger.movedOrder(listOf("a", "b", "c"), setOf(2), 0))
    }

    @Test
    fun testArrangedIsPermutationProperty() {
        val rng = SplitMix64(0xACEDF00DuL)
        val all = listOf("a", "b", "c", "d", "e", "f")
        repeat(3_000) {
            val order = List(rng.nextInt(0, 9)) { all.random(rng) }
            val arranged = PackArranger.arrangedNames(order, all)
            assertEquals(all.toSet(), arranged.toSet())
            assertEquals(all.size, arranged.size)
        }
    }
}
