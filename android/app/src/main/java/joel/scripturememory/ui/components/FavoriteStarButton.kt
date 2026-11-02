package joel.scripturememory.ui.components

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.animation.scaleOut
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import joel.scripturememory.R
import joel.scripturememory.model.AnalyticsEvent
import joel.scripturememory.model.FavoritesStore
import joel.scripturememory.model.Verse
import joel.scripturememory.model.VerseActionSource
import joel.scripturememory.system.Analytics
import joel.scripturememory.system.HapticEngine
import joel.scripturememory.ui.theme.AppMotion
import joel.scripturememory.ui.theme.AppTheme

@Composable
fun FavoriteStarButton(verse: Verse, modifier: Modifier = Modifier, alignment: Alignment = Alignment.Center) {
    val colors = AppTheme.colors
    val favorites = FavoritesStore.shared
    val isFavorite = favorites.isFavorite(verse)
    Box(
        modifier
            .size(44.dp)
            .semantics { contentDescription = if (isFavorite) "Remove from favourites" else "Add to favourites" }
            .pressable(pressedScale = 0.86f) {
                HapticEngine.light()
                Analytics.log(AnalyticsEvent.StarChanged(!isFavorite, VerseActionSource.card))
                favorites.toggle(verse)
            },
        contentAlignment = alignment,
    ) {
        AnimatedContent(
            targetState = isFavorite,
            transitionSpec = {
                (fadeIn(AppMotion.control()) + scaleIn(AppMotion.control(), initialScale = 0.7f))
                    .togetherWith(fadeOut(AppMotion.control()) + scaleOut(AppMotion.control(), targetScale = 0.7f))
            },
            label = "star",
        ) { favorite ->
            Icon(
                if (favorite) R.drawable.ic_star_fill else R.drawable.ic_star,
                size = 18.dp,
                tint = if (favorite) colors.yellow else colors.tertiaryLabel,
            )
        }
    }
}
