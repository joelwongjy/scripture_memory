package joel.scripturememory.model

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class PackListLayoutTests {

    @Test
    fun testPhonesKeepOneFullWidthColumn() {
        val layout = PackListLayout(408f, 16f)
        assertEquals(1, layout.columns)
        assertEquals(408f, layout.cardWidth)
        assertEquals(0f, layout.centerOffset(5))
    }

    @Test
    fun testWiderWindowsSplitIntoColumnsThatFillTheWidth() {
        val duoOpen = PackListLayout(637f, 16f)
        assertEquals(2, duoOpen.columns)
        assertEquals(310.5f, duoOpen.cardWidth)

        val tablet = PackListLayout(1000f, 16f)
        assertEquals(3, tablet.columns)
        assertEquals(1000f, tablet.columns * tablet.cardWidth + 2 * tablet.spacing, 0.001f)
    }

    @Test
    fun testColumnBoundaries() {
        assertEquals(1, PackListLayout.columns(539f))
        assertEquals(2, PackListLayout.columns(540f))
        assertEquals(2, PackListLayout.columns(959f))
        assertEquals(3, PackListLayout.columns(960f))
    }

    @Test
    fun testRowsAndColumnsOfCards() {
        val layout = PackListLayout(637f, 16f)
        assertEquals(2, layout.row(5))
        assertEquals(1, layout.column(5))
        assertEquals(4, layout.firstCard(2))
        assertEquals(3, layout.rows(5))
        assertEquals(3, layout.rows(6))
    }

    @Test
    fun testOffsetsReachCardsBeforeTheFirst() {
        val layout = PackListLayout(637f, 16f)
        assertEquals(-1, layout.row(-1))
        assertEquals(1, layout.column(-1))
        assertEquals(-1, layout.row(-2))
        assertEquals(0, layout.column(-2))
        assertEquals(-2, layout.row(-3))
    }

    @Test
    fun testOffsetBetweenCardsFollowsTheGrid() {
        val layout = PackListLayout(637f, 16f)
        assertEquals(1 to 0, layout.offset(2, 1))
        assertEquals(-1 to 1, layout.offset(3, 1))
        assertEquals(1 to -1, layout.offset(2, -1))
    }

    @Test
    fun testOneColumnOffsetsMatchTheOldStraightList() {
        val layout = PackListLayout(408f, 16f)
        for (distance in -3..3) {
            assertEquals(0 to distance, layout.offset(4, distance))
        }
    }

    @Test
    fun testThePouchHoldsCardsTheSizeOfTheColumns() {
        val duoOpen = PackListLayout(637f, 16f)
        assertEquals(duoOpen.cardWidth, duoOpen.pouchWidthLimit!! * PackListLayout.pouchCardShare, 0.001f)
        assertNull(PackListLayout(408f, 16f).pouchWidthLimit)
    }

    @Test
    fun testALiftedCardGrowsOutOfAColumnWithoutFillingTheScreen() {
        assertEquals(425f, PackListLayout.liftedWidth(310f, 425f, 669f, 860f, 5f / 3f, 16f))
    }

    @Test
    fun testALiftedCardKeepsThePhoneWidth() {
        assertEquals(450f, PackListLayout.liftedWidth(450f, 425f, 482f, 800f, 5f / 3f, 16f))
    }

    @Test
    fun testALiftedCardFitsAShortWindow() {
        assertEquals(168 * 5f / 3f, PackListLayout.liftedWidth(269f, 425f, 576f, 200f, 5f / 3f, 16f), 0.001f)
    }

    @Test
    fun testAFocalCardFollowsTheSystemTextSize() {
        assertEquals(400f, PackListLayout.focalCardWidth(16f), 0.001f)
        assertEquals(500f, PackListLayout.focalCardWidth(20f), 0.001f)
    }

    @Test
    fun testVerseTextNeverStartsBelowTheReadableSize() {
        assertEquals(12f, PackListLayout.verseTextCeiling(269f, 0.038f, 12f))
        assertEquals(15.276f, PackListLayout.verseTextCeiling(402f, 0.038f, 12f), 0.001f)
    }

    @Test
    fun testHomeSitsSideBySideOnlyWhenWiderThanTall() {
        assertTrue(PackListLayout.homeIsSideBySide(590f, 466f))
        assertFalse(PackListLayout.homeIsSideBySide(637f, 951f))
        assertFalse(PackListLayout.homeIsSideBySide(350f, 300f))
    }

    @Test
    fun testACardFollowsTheFingerAtFirstThenResists() {
        assertEquals(0f, PackListLayout.cardPull(0f))
        assertEquals(5.3f, PackListLayout.cardPull(10f), 0.1f)
        assertTrue(
            PackListLayout.cardPull(400f) - PackListLayout.cardPull(200f) <
                PackListLayout.cardPull(200f) - PackListLayout.cardPull(0f),
        )
        assertTrue(PackListLayout.cardPull(10_000f) < PackListLayout.cardPullLimit)
    }

    @Test
    fun testACardResistsTheSameBothWays() {
        assertEquals(-PackListLayout.cardPull(90f), PackListLayout.cardPull(-90f))
    }

    @Test
    fun testOneColumnCountsOneCard() {
        assertEquals("Card 7 of 26", PackListLayout.positionLabel(6, 26, 1))
    }

    @Test
    fun testColumnsCountTheWholeRow() {
        assertEquals("Cards 7–8 of 26", PackListLayout.positionLabel(6, 26, 2))
        assertEquals("Cards 7–8 of 26", PackListLayout.positionLabel(7, 26, 2))
    }

    @Test
    fun testALastRowWithOneCardCountsOneCard() {
        assertEquals("Card 25 of 25", PackListLayout.positionLabel(24, 25, 2))
    }

    @Test
    fun testATitleThatFitsStaysCentred() {
        assertEquals(130f to 100f, PackListLayout.titleSpan(360f, 44f, 100f, 100f, 8f))
    }

    @Test
    fun testAWideTitleMovesAwayFromTheWiderButton() {
        assertEquals(102f to 150f, PackListLayout.titleSpan(360f, 44f, 100f, 150f, 8f))
    }

    @Test
    fun testATitleTooWideForTheBarFillsTheRoomBetweenButtons() {
        assertEquals(52f to 200f, PackListLayout.titleSpan(360f, 44f, 100f, 300f, 8f))
    }

    @Test
    fun testCardCentresSitEitherSideOfTheMiddle() {
        val layout = PackListLayout(637f, 16f)
        assertEquals(-163.25f, layout.centerOffset(0))
        assertEquals(163.25f, layout.centerOffset(1))
    }
}
