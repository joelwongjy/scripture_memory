package joel.scripturememory.ui.home

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.text.TextAutoSize
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.dp
import joel.scripturememory.R
import joel.scripturememory.model.CardAppearance
import joel.scripturememory.model.CardFooter
import joel.scripturememory.model.PackListLayout
import joel.scripturememory.model.Verse
import joel.scripturememory.model.VerseNumbering
import joel.scripturememory.ui.components.FittedVerseText
import joel.scripturememory.ui.components.Icon
import joel.scripturememory.ui.components.PaperShape
import joel.scripturememory.ui.components.Text
import joel.scripturememory.ui.theme.AppLayout
import joel.scripturememory.ui.theme.AppTheme
import joel.scripturememory.ui.theme.AppType
import joel.scripturememory.ui.theme.CardFont
import joel.scripturememory.ui.theme.CardFontStyle
import joel.scripturememory.ui.theme.LightColors
import joel.scripturememory.ui.theme.PouchInk
import joel.scripturememory.ui.theme.sizeInDp
import kotlin.math.min

@Composable
internal fun paperIsDark(): Boolean =
    AppTheme.isDark && CardAppearance.saved() == CardAppearance.matchSystem

@Composable
internal fun paperAccent(): Color = if (paperIsDark()) AppTheme.colors.accent else LightColors.accent

@Composable
internal fun HomeVerseCard(
    verse: Verse,
    isLearnt: Boolean,
    width: Dp,
    modifier: Modifier = Modifier,
) {
    val u = width.value / 100f
    val dark = paperIsDark()
    val density = LocalDensity.current
    fun size(amount: Float): TextUnit = with(density) { (amount * u).dp.toSp() }
    val footer = CardFooter.label(verse).split(" · ")
    val caption = PouchInk.caption(dark)
    val footerStyle = CardFont.style(CardFontStyle.PrintBody, size(2.9f))
    Column(
        modifier
            .size(width, width / AppLayout.cardAspect)
            .clip(PaperShape)
            .background(PouchInk.paper(dark))
            .border(0.5.dp, PouchInk.edgeLine(dark), PaperShape)
            .padding(start = (7 * u).dp, end = (7 * u).dp, top = (5.2f * u).dp, bottom = (3.6f * u).dp)
            .clearAndSetSemantics {},
    ) {
        if (verse.packName.startsWith("DEP ")) {
            PrintedHeading(verse, u, dark, ::size, Modifier.weight(1f))
        } else {
            Heading(verse, u, dark, ::size, Modifier.weight(1f))
        }
        Row(
            Modifier.fillMaxWidth().padding(top = (1.4f * u).dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy((1.6f * u).dp),
        ) {
            Row(Modifier.weight(1f), horizontalArrangement = Arrangement.spacedBy((1.6f * u).dp)) {
                Text(
                    footer.firstOrNull().orEmpty(),
                    style = if (verse.packName.startsWith("DEP ")) footerStyle.bold() else footerStyle,
                    color = caption,
                    maxLines = 1,
                )
                if (footer.size > 1) Text(footer[1], style = footerStyle, color = caption, maxLines = 1)
            }
            if (isLearnt) {
                val green = PouchInk.green(dark)
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Icon(R.drawable.ic_check, size = (3.2f * u).dp, tint = green)
                    Spacer(Modifier.width((0.8f * u).dp))
                    Text("Learnt", style = footerStyle.bold(), color = green, maxLines = 1)
                }
            }
            val accent = paperAccent()
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text("Read", style = footerStyle.copy(fontWeight = FontWeight.SemiBold), color = accent, maxLines = 1)
                Spacer(Modifier.width((0.7f * u).dp))
                Icon(R.drawable.ic_caret_right, size = (2.8f * u).dp, tint = accent)
            }
        }
    }
}

private fun TextStyle.bold() = copy(fontWeight = FontWeight.Bold)

@Composable
private fun Heading(verse: Verse, u: Float, dark: Boolean, size: (Float) -> TextUnit, verseModifier: Modifier) {
    val readable = AppType.caption.sizeInDp()
    val title = CardFont.style(CardFontStyle.Title, size(4.6f))
    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy((2 * u).dp)) {
        Text(
            verse.title,
            Modifier.weight(1f).alignByBaseline(),
            style = title,
            color = PouchInk.title(dark),
            maxLines = 2,
            autoSize = TextAutoSize.StepBased(size(3.7f), size(4.6f), size(0.1f)),
        )
        Text(
            verse.pinnedVersion ?: "NIV",
            Modifier.alignByBaseline(),
            style = CardFont.serif(size(3.4f)),
            color = PouchInk.caption(dark),
            maxLines = 1,
        )
    }
    Text(
        "${verse.book} ${verse.reference}",
        Modifier.padding(top = (1.4f * u).dp),
        style = CardFont.style(CardFontStyle.Body, size(4.6f)),
        color = PouchInk.body(dark),
        maxLines = 1,
    )
    FittedVerseText(
        verse.verse,
        lineSpacing = 0.8f * u,
        minSize = 2 * u,
        maxSize = PackListLayout.verseTextCeiling(100 * u, PackListLayout.verseTextShare, readable),
        modifier = verseModifier.fillMaxWidth().padding(top = (1.4f * u).dp),
        color = PouchInk.body(dark),
    )
}

@Composable
private fun PrintedHeading(verse: Verse, u: Float, dark: Boolean, size: (Float) -> TextUnit, verseModifier: Modifier) {
    val reference = "${verse.book} ${verse.reference}"
    val small = CardFont.style(CardFontStyle.PrintBody, size(3.2f))
    val density = LocalDensity.current
    val verseCeiling = PackListLayout.verseTextCeiling(100 * u, PackListLayout.printedVerseShare, AppType.caption.sizeInDp())
    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy((2 * u).dp)) {
        Text(
            VerseNumbering.numberedTitle(verse),
            Modifier.weight(1f).alignByBaseline(),
            style = CardFont.style(CardFontStyle.PrintTitle, size(4.4f)),
            color = PouchInk.body(dark),
            maxLines = 2,
            autoSize = TextAutoSize.StepBased(size(3.5f), size(4.4f), size(0.1f)),
        )
        VerseNumbering.printedNumber(verse)?.let { number ->
            Text("($number)", Modifier.alignByBaseline(), style = small, color = PouchInk.caption(dark), maxLines = 1)
        }
    }
    Row(
        Modifier.fillMaxWidth().padding(top = (1.2f * u).dp),
        horizontalArrangement = Arrangement.spacedBy((2 * u).dp),
    ) {
        Text(
            reference,
            Modifier.weight(1f).alignByBaseline(),
            style = CardFont.style(
                CardFontStyle.PrintBody,
                with(density) { min(verseCeiling, 4.4f * u).dp.toSp() },
            ),
            color = PouchInk.body(dark),
            maxLines = 1,
        )
        verse.pinnedVersion?.let { version ->
            Text("($version)", Modifier.alignByBaseline(), style = small, color = PouchInk.caption(dark), maxLines = 1)
        }
    }
    FittedVerseText(
        verse.verse,
        lineSpacing = 0.5f * u,
        minSize = 2 * u,
        maxSize = verseCeiling,
        modifier = verseModifier.fillMaxWidth().padding(top = (0.6f * u).dp),
        kind = CardFontStyle.PrintBody,
        closingLine = reference,
        color = PouchInk.body(dark),
    )
}
