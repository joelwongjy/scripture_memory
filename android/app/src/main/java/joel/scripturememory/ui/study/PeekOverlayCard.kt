package joel.scripturememory.ui.study

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import joel.scripturememory.model.Verse
import joel.scripturememory.ui.components.FittedVerseText
import joel.scripturememory.ui.components.Text
import joel.scripturememory.ui.components.VerseFit
import joel.scripturememory.ui.theme.AppTheme
import joel.scripturememory.ui.theme.AppType
import joel.scripturememory.ui.theme.CardFontStyle

@Composable
fun PeekOverlayCard(
    verse: Verse,
    cardLabel: String,
    width: Dp,
    height: Dp,
    showCardLabel: Boolean = true,
) {
    PaperAppearance {
        val secondary = AppTheme.colors.secondaryLabel
        val density = LocalDensity.current
        Box(Modifier.size(width, height).flashcardStyle()) {
            BoxWithConstraints(Modifier.fillMaxSize()) {
                val w = maxWidth.value
                Column(Modifier.fillMaxSize()) {
                    val pinned = verse.pinnedVersion
                    if (pinned != null) {
                        Text("($pinned)", style = pinnedVersionStyle, color = secondary)
                        Spacer(Modifier.height(6.dp))
                    }
                    Text(
                        "${verse.book} ${verse.reference}",
                        style = VerseFit.style(CardFontStyle.Reference, scaledTypeSize(18f, 3.25f, w), 0f, density),
                        color = secondary,
                    )
                    Spacer(Modifier.height(12.dp))
                    Text(
                        verse.title,
                        style = VerseFit.style(CardFontStyle.Title, scaledTypeSize(16f, 2.75f, w), 4f, density),
                        color = secondary,
                    )
                    Spacer(Modifier.height(8.dp))
                    FittedVerseText(
                        text = verse.verse,
                        lineSpacing = 5f,
                        minSize = 10f,
                        maxSize = scaledTypeSize(16f, 3f, w),
                        modifier = Modifier.weight(1f).fillMaxWidth(),
                        color = secondary,
                    )
                    if (showCardLabel) {
                        Spacer(Modifier.height(16.dp))
                        Text(
                            cardLabel,
                            Modifier.alpha(0.5f),
                            style = AppType.caption.copy(fontWeight = FontWeight.Medium),
                            color = secondary,
                            maxLines = 1,
                        )
                    }
                }
            }
        }
    }
}
