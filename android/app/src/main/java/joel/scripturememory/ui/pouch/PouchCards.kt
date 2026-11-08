package joel.scripturememory.ui.pouch

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.TextAutoSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.dropShadow
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.layout.FirstBaseline
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.PlatformTextStyle
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.dp
import joel.scripturememory.R
import joel.scripturememory.model.AppDefaults
import joel.scripturememory.model.CardFooter
import joel.scripturememory.model.PackListLayout
import joel.scripturememory.model.Verse
import joel.scripturememory.model.VerseNumbering
import joel.scripturememory.ui.components.FittedVerseText
import joel.scripturememory.ui.components.Icon
import joel.scripturememory.ui.components.Text
import joel.scripturememory.ui.packs.ShadowRadiusScale
import joel.scripturememory.ui.theme.AppLayout
import joel.scripturememory.ui.theme.AppTheme
import joel.scripturememory.ui.theme.AppType
import joel.scripturememory.ui.theme.CardFont
import joel.scripturememory.ui.theme.CardFontStyle
import joel.scripturememory.ui.theme.InterText
import joel.scripturememory.ui.theme.LightColors
import joel.scripturememory.ui.theme.LocalAppColors
import joel.scripturememory.ui.theme.LocalContentColor
import joel.scripturememory.ui.theme.PouchInk
import joel.scripturememory.ui.theme.sizeInDp
import kotlin.math.max
import kotlin.math.min

private const val cardAppearanceKey = "cardAppearance.v1"
private const val matchSystemAppearance = "matchSystem"

private val paperCorner = RoundedCornerShape(2.dp)
private const val shadowWarmup = 0.002f

internal fun Modifier.listCardShadow(amount: () -> Float = { 1f }): Modifier =
    dropShadow(paperCorner) {
        radius = 10.dp.toPx() * ShadowRadiusScale
        color = Color.Black
        alpha = 0.08f * max(amount(), shadowWarmup)
        offset = Offset(0f, 4.dp.toPx())
    }

@Composable
internal fun PaperAppearance(content: @Composable () -> Unit) {
    if (AppDefaults.standard.getString(cardAppearanceKey) == matchSystemAppearance) {
        content()
    } else {
        CompositionLocalProvider(
            LocalAppColors provides LightColors,
            LocalContentColor provides LightColors.label,
            content = content,
        )
    }
}

@Composable
internal fun PaperFace(modifier: Modifier = Modifier, tint: Color = PouchInk.paper(AppTheme.isDark)) {
    val edge = PouchInk.edgeLine(AppTheme.isDark)
    Canvas(modifier) {
        val density = this.density
        drawRoundRect(tint, cornerRadius = CornerRadius(2f * density))
        val line = 0.5f * density
        drawRoundRect(
            edge,
            Offset(line / 2, line / 2),
            Size(size.width - line, size.height - line),
            CornerRadius(1.75f * density),
            style = Stroke(line),
        )
    }
}

@Composable
internal fun PouchVerseCard(
    verse: Verse,
    isLearnt: Boolean,
    width: Dp,
    modifier: Modifier = Modifier,
    accessory: @Composable RowScope.() -> Unit = {},
) {
    val dark = AppTheme.isDark
    val density = LocalDensity.current
    val u = width.value / 100f
    fun sp(value: Float): TextUnit = with(density) { (value * u).dp.toSp() }
    val readable = AppType.caption.sizeInDp()
    fun ceiling(share: Float) = PackListLayout.verseTextCeiling(width.value, share, readable)
    val footer = CardFooter.label(verse).split(" · ")
    val caption = PouchInk.caption(dark)
    val isPrintedDEP = verse.packName.startsWith("DEP ")

    Box(modifier.size(width, width / AppLayout.cardAspect)) {
        PaperFace(Modifier.matchParentSize())
        Column(
            Modifier
                .matchParentSize()
                .padding(start = (7 * u).dp, end = (7 * u).dp, top = (5.2f * u).dp, bottom = (3.6f * u).dp),
        ) {
            val body = PouchInk.body(dark)
            val reference = "${verse.book} ${verse.reference}"
            if (isPrintedDEP) {
                Row(Modifier.fillMaxWidth()) {
                    val title = VerseNumbering.numberedTitle(verse)
                    Text(
                        title,
                        Modifier.weight(1f).alignBy(FirstBaseline),
                        style = CardFont.style(CardFontStyle.PrintTitle, sp(4.4f)),
                        color = body,
                        maxLines = 2,
                        autoSize = TextAutoSize.StepBased(sp(3.52f), sp(4.4f), sp(0.1f)),
                    )
                    Spacer(Modifier.size((2 * u).dp, 0.dp))
                    VerseNumbering.printedNumber(verse)?.let { number ->
                        Text(
                            "($number)",
                            Modifier.alignBy(FirstBaseline),
                            style = CardFont.style(CardFontStyle.PrintBody, sp(3.2f)),
                            color = caption,
                        )
                    }
                }
                Row(Modifier.fillMaxWidth().padding(top = (1.2f * u).dp)) {
                    Text(
                        reference,
                        Modifier.weight(1f).alignBy(FirstBaseline),
                        style = CardFont.style(
                            CardFontStyle.PrintBody,
                            with(density) { min(ceiling(PackListLayout.printedVerseShare), 4.4f * u).dp.toSp() },
                        ),
                        color = body,
                    )
                    verse.pinnedVersion?.let { version ->
                        Text(
                            "($version)",
                            Modifier.alignBy(FirstBaseline),
                            style = CardFont.style(CardFontStyle.PrintBody, sp(3.2f)),
                            color = caption,
                        )
                    }
                }
                FittedVerseText(
                    verse.verse,
                    lineSpacing = 0.5f * u,
                    minSize = 2 * u,
                    maxSize = ceiling(PackListLayout.printedVerseShare),
                    modifier = Modifier.weight(1f).fillMaxWidth().padding(top = (0.6f * u).dp),
                    kind = CardFontStyle.PrintBody,
                    closingLine = reference,
                    color = body,
                )
            } else {
                Row(Modifier.fillMaxWidth()) {
                    Text(
                        verse.title.ifEmpty { reference },
                        Modifier.weight(1f).alignBy(FirstBaseline),
                        style = CardFont.style(CardFontStyle.Title, sp(4.6f)),
                        color = PouchInk.title(dark),
                        maxLines = 2,
                        autoSize = TextAutoSize.StepBased(sp(3.68f), sp(4.6f), sp(0.1f)),
                    )
                    Spacer(Modifier.size((2 * u).dp, 0.dp))
                    Text(
                        verse.pinnedVersion ?: "NIV",
                        Modifier.alignBy(FirstBaseline),
                        style = CardFont.serif(sp(3.4f)),
                        color = caption,
                    )
                }
                if (verse.title.isNotEmpty()) {
                    Text(
                        reference,
                        Modifier.padding(top = (1.4f * u).dp),
                        style = CardFont.style(CardFontStyle.Body, sp(4.6f)),
                        color = body,
                    )
                }
                FittedVerseText(
                    verse.verse,
                    lineSpacing = 0.8f * u,
                    minSize = 2 * u,
                    maxSize = ceiling(PackListLayout.verseTextShare),
                    modifier = Modifier.weight(1f).fillMaxWidth().padding(top = (1.4f * u).dp),
                    color = body,
                )
            }
            Row(
                Modifier.fillMaxWidth().padding(top = (1.4f * u).dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy((1.6f * u).dp),
            ) {
                val style = TextStyle(
                    fontFamily = InterText,
                    fontSize = sp(2.9f),
                    platformStyle = PlatformTextStyle(includeFontPadding = false),
                )
                Row(Modifier.weight(1f), horizontalArrangement = Arrangement.spacedBy((1.6f * u).dp)) {
                    Text(footer.first(), style = if (isPrintedDEP) style.copy(fontWeight = FontWeight.Bold) else style, color = caption, maxLines = 1)
                    if (footer.size > 1) {
                        Text(footer[1], Modifier.weight(1f, fill = false), style = style, color = caption, maxLines = 1)
                    }
                }
                if (isLearnt) {
                    val green = PouchInk.green(dark)
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy((1.1f * u).dp),
                    ) {
                        Icon(R.drawable.ic_check, size = (3f * u).dp, tint = green)
                        Text("Learnt", style = style.copy(fontWeight = FontWeight.Bold), color = green, maxLines = 1)
                    }
                }
                accessory()
            }
        }
    }
}

@Composable
internal fun PouchCardBack(verse: Verse, width: Dp) {
    val dark = AppTheme.isDark
    val density = LocalDensity.current
    val u = width.value / 100f
    fun sp(value: Float): TextUnit = with(density) { (value * u).dp.toSp() }
    val kind = if (verse.packName.startsWith("DEP ")) CardFontStyle.PrintBody else CardFontStyle.Body

    Box(Modifier.size(width, width / AppLayout.cardAspect)) {
        PaperFace(Modifier.matchParentSize())
        Column(
            Modifier.matchParentSize().padding(horizontal = (7 * u).dp),
            verticalArrangement = Arrangement.spacedBy((2.4f * u).dp, Alignment.CenterVertically),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Text(
                "${verse.book} ${verse.reference}",
                style = CardFont.style(kind, sp(6.4f)),
                color = PouchInk.body(dark),
                textAlign = TextAlign.Center,
            )
            Text(
                "Tap to reveal",
                style = TextStyle(
                    fontFamily = InterText,
                    fontSize = sp(3.2f),
                    fontWeight = FontWeight.Medium,
                    platformStyle = PlatformTextStyle(includeFontPadding = false),
                ),
                color = PouchInk.caption(dark),
            )
        }
    }
}

@Composable
internal fun PouchBackPageCard(packName: String, verseCount: Int, learntCount: Int, width: Dp) {
    val dark = AppTheme.isDark
    val density = LocalDensity.current
    val u = width.value / 100f
    fun sp(value: Float): TextUnit = with(density) { (value * u).dp.toSp() }
    val green = PouchInk.green(dark)
    Box(Modifier.size(width, width / AppLayout.cardAspect)) {
        PaperFace(Modifier.matchParentSize(), PouchInk.paperBack(dark))
        Column(
            Modifier
                .matchParentSize()
                .padding(horizontal = (7 * u).dp, vertical = (6.4f * u).dp),
        ) {
            Text("End of $packName", style = CardFont.style(CardFontStyle.Title, sp(5.4f)), color = green)
            Text(
                "You've turned every card in the pack. Turn them back to go over them again.",
                Modifier.padding(top = (2.4f * u).dp),
                style = CardFont.style(CardFontStyle.Body, sp(4.2f)),
                color = PouchInk.body(dark),
            )
            Spacer(Modifier.weight(1f))
            Row(horizontalArrangement = Arrangement.spacedBy((6 * u).dp)) {
                BackPageStat("$learntCount", "learnt", u, green)
                BackPageStat("${verseCount - learntCount}", "to go", u, green)
            }
        }
    }
}

@Composable
private fun BackPageStat(value: String, label: String, u: Float, green: Color) {
    val density = LocalDensity.current
    fun sp(size: Float): TextUnit = with(density) { (size * u).dp.toSp() }
    val base = TextStyle(fontFamily = InterText, platformStyle = PlatformTextStyle(includeFontPadding = false))
    Column {
        Text(value, style = base.copy(fontSize = sp(9f), fontWeight = FontWeight.SemiBold), color = green)
        Text(label, style = base.copy(fontSize = sp(3.2f)), color = PouchInk.caption(AppTheme.isDark))
    }
}
