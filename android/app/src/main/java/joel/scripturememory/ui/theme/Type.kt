package joel.scripturememory.ui.theme

import androidx.compose.runtime.Immutable
import androidx.compose.ui.text.PlatformTextStyle
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontVariation
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.LineHeightStyle
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.em
import androidx.compose.ui.unit.sp
import joel.scripturememory.R

private fun inter(weight: Int, opticalSize: Float, italic: Boolean = false) = Font(
    resId = if (italic) R.font.inter_italic else R.font.inter,
    weight = FontWeight(weight),
    style = if (italic) FontStyle.Italic else FontStyle.Normal,
    variationSettings = FontVariation.Settings(
        FontVariation.weight(weight),
        FontVariation.Setting("opsz", opticalSize),
    ),
)

private val weights = listOf(400, 500, 600, 700, 800, 900)

val InterText = FontFamily(weights.map { inter(it, 14f) } + weights.map { inter(it, 14f, italic = true) })
val InterDisplay = FontFamily(weights.map { inter(it, 32f) } + weights.map { inter(it, 32f, italic = true) })

val SerifFamily = FontFamily(
    Font(R.font.tinos, FontWeight.Normal),
    Font(R.font.tinos_italic, FontWeight.Normal, FontStyle.Italic),
    Font(R.font.tinos_bold, FontWeight.Bold),
    Font(R.font.tinos_bold_italic, FontWeight.Bold, FontStyle.Italic),
)

val CardBodyFamily = FontFamily(Font(R.font.belleza, FontWeight.Normal))
val CardTitleFamily = FontFamily(
    Font(R.font.quattrocento_sans, FontWeight.Normal),
    Font(R.font.quattrocento_sans_bold, FontWeight.Bold),
)

private val trimmed = LineHeightStyle(LineHeightStyle.Alignment.Center, LineHeightStyle.Trim.None)

private fun style(
    size: TextUnit,
    weight: FontWeight,
    line: TextUnit,
    tracking: Float = -0.006f,
    family: FontFamily = InterText,
) = TextStyle(
    fontFamily = family,
    fontSize = size,
    fontWeight = weight,
    lineHeight = line,
    letterSpacing = tracking.em,
    lineHeightStyle = trimmed,
    platformStyle = PlatformTextStyle(includeFontPadding = false),
)

@Immutable
object AppType {
    val largeTitle = style(32.sp, FontWeight.Bold, 38.sp, -0.022f, InterDisplay)
    val title1 = style(26.sp, FontWeight.Bold, 32.sp, -0.02f, InterDisplay)
    val title2 = style(21.sp, FontWeight.Bold, 27.sp, -0.016f, InterDisplay)
    val title3 = style(19.sp, FontWeight.SemiBold, 25.sp, -0.012f, InterDisplay)
    val headline = style(16.sp, FontWeight.SemiBold, 22.sp, -0.009f)
    val body = style(16.sp, FontWeight.Normal, 22.sp, -0.008f)
    val callout = style(15.sp, FontWeight.Normal, 21.sp, -0.006f)
    val subheadline = style(14.sp, FontWeight.Normal, 19.sp, -0.004f)
    val footnote = style(13.sp, FontWeight.Normal, 18.sp, 0f)
    val caption = style(12.sp, FontWeight.Normal, 16.sp, 0.002f)
    val caption2 = style(11.sp, FontWeight.Medium, 14.sp, 0.006f)
}

enum class CardFontStyle { Title, Reference, Body, PrintTitle, PrintBody }

object CardFont {
    fun style(kind: CardFontStyle, size: TextUnit): TextStyle = when (kind) {
        CardFontStyle.Title -> base(CardTitleFamily, FontWeight.Bold, size)
        CardFontStyle.Reference -> base(CardTitleFamily, FontWeight.Bold, size)
        CardFontStyle.Body -> base(CardBodyFamily, FontWeight.Normal, size)
        CardFontStyle.PrintTitle -> base(InterText, FontWeight.Medium, size)
        CardFontStyle.PrintBody -> base(InterText, FontWeight.Normal, size)
    }

    fun serif(size: TextUnit): TextStyle = base(SerifFamily, FontWeight.Normal, size)

    private fun base(family: FontFamily, weight: FontWeight, size: TextUnit) = TextStyle(
        fontFamily = family,
        fontWeight = weight,
        fontSize = size,
        platformStyle = PlatformTextStyle(includeFontPadding = false),
    )
}
