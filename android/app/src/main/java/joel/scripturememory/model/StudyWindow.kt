package joel.scripturememory.model

object StudyWindow {
    const val titleRoom = 320f

    fun dropsTitle(height: Float, topInset: Float): Boolean = height + topInset < titleRoom
}
