package joel.scripturememory.model

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class StudyWindowTests {

    @Test
    fun testLandscapeKeyboardDropsTheTitle() {
        assertTrue(StudyWindow.dropsTitle(154f, 82f))
    }

    @Test
    fun testPortraitKeyboardKeepsTheTitle() {
        assertFalse(StudyWindow.dropsTitle(308f, 82f))
    }

    @Test
    fun testDroppingTheTitleCannotChangeTheAnswer() {
        val barHeight = 58f
        var height = 100f
        while (height <= 500f) {
            assertEquals(
                StudyWindow.dropsTitle(height, 82f),
                StudyWindow.dropsTitle(height + barHeight, 82f - barHeight),
            )
            height += 7f
        }
    }
}
