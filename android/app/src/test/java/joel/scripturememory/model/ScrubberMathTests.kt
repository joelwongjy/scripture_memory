package joel.scripturememory.model

import org.junit.Assert.assertEquals
import org.junit.Test

class ScrubberMathTests {

    @Test
    fun testFractionEndpoints() {
        assertEquals(0.0, ScrubberMath.fraction(0, 10), 1e-9)
        assertEquals(1.0, ScrubberMath.fraction(9, 10), 1e-9)
    }

    @Test
    fun testFractionDegenerateCounts() {
        assertEquals(0.0, ScrubberMath.fraction(0, 1), 0.0)
        assertEquals(0.0, ScrubberMath.fraction(4, 0), 0.0)
    }

    @Test
    fun testFractionClampsIndex() {
        assertEquals(0.0, ScrubberMath.fraction(-3, 10), 0.0)
        assertEquals(1.0, ScrubberMath.fraction(99, 10), 0.0)
    }

    @Test
    fun testIndexFromFraction() {
        assertEquals(0, ScrubberMath.index(0.0, 10))
        assertEquals(9, ScrubberMath.index(1.0, 10))
        assertEquals(5, ScrubberMath.index(0.5, 11))
        assertEquals(0, ScrubberMath.index(-1.0, 10))
        assertEquals(9, ScrubberMath.index(2.0, 10))
        assertEquals(0, ScrubberMath.index(0.4, 1))
    }

    @Test
    fun testTrackTravel() {
        assertEquals(44.0, ScrubberMath.trackTravel(100.0, 40.0, 8.0), 0.0)
        assertEquals(0.0, ScrubberMath.trackTravel(30.0, 40.0, 8.0), 0.0)
    }

    @Test
    fun testThumbYEndpoints() {
        val travel = 200.0
        val inset = 8.0
        assertEquals(inset, ScrubberMath.thumbY(0, 10, travel, inset), 1e-9)
        assertEquals(inset + travel, ScrubberMath.thumbY(9, 10, travel, inset), 1e-9)
    }

    @Test
    fun testIndexForDragFromIndexRoundTrips() {
        val inset = 8.0
        val travel = 200.0
        val count = 10
        for (i in 0 until count) {
            val y = ScrubberMath.thumbY(i, count, travel, inset)
            assertEquals(i, ScrubberMath.indexForDrag(y, 0.0, inset, travel, count))
        }
    }

    @Test
    fun testIndexForDragTranslationAndClamps() {
        val inset = 8.0
        val travel = 180.0
        val count = 10
        val startY = ScrubberMath.thumbY(0, count, travel, inset)
        assertEquals(2, ScrubberMath.indexForDrag(startY, 40.0, inset, travel, count))
        assertEquals(0, ScrubberMath.indexForDrag(startY, -999.0, inset, travel, count))
        assertEquals(9, ScrubberMath.indexForDrag(startY, 9999.0, inset, travel, count))
    }

    @Test
    fun testZeroTravelStaysAtZero() {
        assertEquals(0, ScrubberMath.indexForDrag(0.0, 50.0, 8.0, 0.0, 10))
    }

    @Test
    fun testThumbYFromFraction() {
        assertEquals(8.0, ScrubberMath.thumbY(0.0, 200.0, 8.0), 1e-9)
        assertEquals(208.0, ScrubberMath.thumbY(1.0, 200.0, 8.0), 1e-9)
        assertEquals(108.0, ScrubberMath.thumbY(0.5, 200.0, 8.0), 1e-9)
        assertEquals(8.0, ScrubberMath.thumbY(-1.0, 200.0, 8.0), 0.0)
        assertEquals(208.0, ScrubberMath.thumbY(2.0, 200.0, 8.0), 0.0)
    }

    @Test
    fun testFractionForDrag() {
        assertEquals(0.5, ScrubberMath.fractionForDrag(8.0, 100.0, 8.0, 200.0), 1e-9)
        assertEquals(0.0, ScrubberMath.fractionForDrag(8.0, -50.0, 8.0, 200.0), 0.0)
        assertEquals(1.0, ScrubberMath.fractionForDrag(8.0, 999.0, 8.0, 200.0), 0.0)
        assertEquals(0.0, ScrubberMath.fractionForDrag(8.0, 50.0, 8.0, 0.0), 0.0)
    }

    @Test
    fun testFractionReachesBothEnds() {
        val travel = 300.0
        val inset = 8.0
        assertEquals(inset, ScrubberMath.thumbY(0.0, travel, inset), 0.0)
        assertEquals(inset + travel, ScrubberMath.thumbY(1.0, travel, inset), 0.0)
        assertEquals(0, ScrubberMath.index(0.0, 60))
        assertEquals(59, ScrubberMath.index(1.0, 60))
    }

    @Test
    fun testFractionThumbYRoundTrip() {
        val rng = SplitMix64(0xF00DCAFEuL)
        repeat(5_000) {
            val f = rng.nextDouble()
            val travel = rng.nextInt(50, 401).toDouble()
            val inset = 8.0
            val y = ScrubberMath.thumbY(f, travel, inset)
            assertEquals(f, ScrubberMath.fractionForDrag(y, 0.0, inset, travel), 1e-9)
        }
    }

    @Test
    fun testRoundTripProperty() {
        val rng = SplitMix64(0x5C2BBEEFuL)
        repeat(10_000) {
            val count = rng.nextInt(1, 51)
            val idx = rng.nextInt(0, count)
            val travel = rng.nextInt(50, 401).toDouble()
            val inset = 8.0
            val y = ScrubberMath.thumbY(idx, count, travel, inset)
            assertEquals(idx, ScrubberMath.indexForDrag(y, 0.0, inset, travel, count))
        }
    }
}
