package joel.scripturememory.model

object StudyWindow {
    const val shortHeight = 320f

    fun dropsTitle(height: Float, topInset: Float): Boolean = height + topInset < shortHeight
}
