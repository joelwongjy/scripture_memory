package joel.scripturememory.ui.pouch

import joel.scripturememory.model.PackListLayout
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class ListGeometryTests {

    private fun geometry(count: Int, viewport: Int = 1000) = ListGeometry(
        sceneWidth = 400,
        cardWidth = 400,
        cardHeight = 240,
        spacing = 16,
        below = 0,
        viewport = viewport,
        count = count,
        layout = PackListLayout(400f, 16f),
        density = 1f,
    )

    @Test
    fun testScrubbingSpansTheWholeScroll() {
        val g = geometry(count = 60)
        val most = 60 * 256 + 16 - 1000
        assertEquals(0, g.scrollAt(0.0))
        assertEquals(most, g.scrollAt(1.0))
        assertEquals(most / 2, g.scrollAt(0.5))
    }

    @Test
    fun testScrubbingPastEitherEndStopsThere() {
        val g = geometry(count = 60)
        assertEquals(0, g.scrollAt(-0.5))
        assertEquals(g.scrollAt(1.0), g.scrollAt(2.0))
    }

    @Test
    fun testFractionReadsBackWhatScrubbingSet() {
        val g = geometry(count = 60)
        assertEquals(0.25, g.fraction(g.scrollAt(0.25))!!, 0.001)
    }

    @Test
    fun testAPackThatFitsHasNoFraction() {
        assertNull(geometry(count = 2).fraction(0))
    }

    @Test
    fun testTheTopOfTheListShowsTheFirstCard() {
        assertEquals(0, geometry(count = 60).cardShown(0f, fallback = 7))
    }

    @Test
    fun testAPackThatFitsKeepsTheCardItWasGiven() {
        assertEquals(1, geometry(count = 2).cardShown(0f, fallback = 1))
    }
}
