package joel.scripturememory.ui.study

import androidx.compose.animation.core.Animatable
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.lerp
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.Constraints
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.em
import androidx.compose.ui.unit.sp
import joel.scripturememory.R
import joel.scripturememory.model.AppDefaults
import joel.scripturememory.model.CardSection
import joel.scripturememory.model.Verse
import joel.scripturememory.ui.components.FavoriteStarButton
import joel.scripturememory.ui.components.FittedVerseText
import joel.scripturememory.ui.components.Icon
import joel.scripturememory.ui.components.Text
import joel.scripturememory.ui.components.VerseFit
import joel.scripturememory.ui.components.pressable
import joel.scripturememory.ui.theme.AppMotion
import joel.scripturememory.ui.theme.AppTheme
import joel.scripturememory.ui.theme.AppType
import joel.scripturememory.ui.theme.CardFont
import joel.scripturememory.ui.theme.CardFontStyle
import kotlin.math.max

fun scaledTypeSize(base: Float, extra: Float, cardWidth: Float, narrow: Float = 322f, wide: Float = 398f): Float {
    val u = ((cardWidth - narrow) / (wide - narrow)).coerceIn(0f, 1f)
    return base + extra * u
}

private val completionMarkReserve = 14.dp
private val completionMarkSize = 10.dp
private const val footerlessReserve = 4f
private val verseMaskTightening = (-0.064).em

internal fun verseLineSpacing(wordCount: Int, cardWidth: Float): Float {
    val base = when {
        wordCount > 55 -> 2f
        wordCount > 45 -> 3f
        wordCount > 35 -> 4f
        else -> 6f
    }
    val bonus = if (cardWidth >= 382f) 1f else if (cardWidth >= 352f) 0.5f else 0f
    return base + bonus
}

internal fun masked(word: String): String =
    word.map { if (it.isLetter()) '_' else it }.joinToString("")

internal val pinnedVersionStyle = AppType.caption2.copy(fontSize = 10.sp, fontWeight = FontWeight.Bold)
private val cardLabelStyle = AppType.caption.copy(fontSize = 12.5.sp, fontWeight = FontWeight.Medium)
private val currentBadgeStyle = AppType.caption2.copy(fontSize = 9.sp, lineHeight = 11.sp, fontWeight = FontWeight.Bold)
private val markCompleteStyle = AppType.caption2.copy(fontWeight = FontWeight.Bold)

@Composable
fun FlashcardView(
    verse: Verse,
    cardLabel: String,
    isReviewMode: Boolean,
    titleRevealedCount: Int,
    verseRevealedCount: Int,
    activeSection: CardSection,
    modifier: Modifier = Modifier,
    onSectionTap: ((CardSection) -> Unit)? = null,
    showCardLabel: Boolean = true,
    isCurrentLearning: Boolean = false,
    onMarkComplete: (() -> Unit)? = null,
    showsFavoriteToggle: Boolean = false,
) {
    PaperAppearance {
        val hardMode = AppDefaults.standard.getBool("hardMode") ?: false
        Box(modifier.fillMaxSize().flashcardStyle()) {
            BoxWithConstraints(Modifier.fillMaxSize()) {
                val cardWidth = maxWidth
                val cardHeight = maxHeight
                val hasFooter = showCardLabel || isCurrentLearning || showsFavoriteToggle
                Column(Modifier.fillMaxSize()) {
                    if (isReviewMode) {
                        ReviewContent(
                            verse = verse,
                            cardWidth = cardWidth,
                            cardHeight = cardHeight,
                            hasFooter = hasFooter,
                            titleRevealedCount = titleRevealedCount,
                            verseRevealedCount = verseRevealedCount,
                            activeSection = activeSection,
                            hardMode = hardMode,
                            onSectionTap = onSectionTap,
                        )
                    } else {
                        ReadContent(verse, cardWidth)
                    }
                    if (hasFooter) Spacer(Modifier.height(16.dp))
                    CardFooterRow(
                        verse = verse,
                        cardLabel = cardLabel,
                        showCardLabel = showCardLabel,
                        showsFavoriteToggle = showsFavoriteToggle,
                        isCurrentLearning = isCurrentLearning,
                        onMarkComplete = onMarkComplete,
                    )
                }
            }
        }
    }
}

@Composable
internal fun CardFooterRow(
    verse: Verse,
    cardLabel: String,
    showCardLabel: Boolean,
    showsFavoriteToggle: Boolean,
    isCurrentLearning: Boolean,
    onMarkComplete: (() -> Unit)? = null,
    modifier: Modifier = Modifier,
) {
    val colors = AppTheme.colors
    Row(
        modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        Box(Modifier.weight(1f)) {
            if (showCardLabel) {
                Text(cardLabel, style = cardLabelStyle, color = colors.secondaryLabel, maxLines = 1)
            }
        }
        if (showsFavoriteToggle) FavoriteStarButton(verse)
        if (isCurrentLearning) {
            if (onMarkComplete != null) MarkCompletePill(onMarkComplete) else CurrentBadge()
        }
    }
}

@Composable
internal fun CurrentBadge() {
    val colors = AppTheme.colors
    Row(
        Modifier
            .semantics(mergeDescendants = true) { contentDescription = "Current verse" }
            .clip(CapsuleShape)
            .background(colors.accent)
            .padding(horizontal = 7.dp, vertical = 3.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(3.dp),
    ) {
        Icon(R.drawable.ic_bookmark_fill, size = 9.dp, tint = colors.onAccent)
        Text("Current", style = currentBadgeStyle, color = colors.onAccent, maxLines = 1)
    }
}

@Composable
private fun MarkCompletePill(onClick: () -> Unit) {
    val colors = AppTheme.colors
    Row(
        Modifier
            .semantics(mergeDescendants = true) { contentDescription = "Mark current verse as complete" }
            .pressable(onClick = onClick)
            .clip(CapsuleShape)
            .background(colors.green)
            .padding(horizontal = 10.dp, vertical = 5.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        Icon(R.drawable.ic_check_circle_fill, size = 12.dp, tint = colors.onAccent)
        Text("Complete", style = markCompleteStyle, color = colors.onAccent, maxLines = 1)
    }
}

@Composable
private fun VersionBadge(pinned: String) {
    val colors = AppTheme.colors
    Text(
        "($pinned)",
        Modifier
            .semantics { contentDescription = "King James Version" }
            .clip(CapsuleShape)
            .background(colors.fill)
            .padding(horizontal = 6.dp, vertical = 2.dp),
        style = pinnedVersionStyle,
        color = colors.secondaryLabel,
    )
}

@Composable
private fun ColumnScope.ReadContent(verse: Verse, cardWidth: Dp) {
    val colors = AppTheme.colors
    val density = LocalDensity.current
    val w = cardWidth.value
    val lineGap = verseLineSpacing(verse.verseWords.size, w)
    Column(Modifier.weight(1f).fillMaxWidth()) {
        val pinned = verse.pinnedVersion
        if (pinned != null) {
            VersionBadge(pinned)
            Spacer(Modifier.height(6.dp))
        }
        Text(
            verse.title,
            style = VerseFit.style(CardFontStyle.Title, scaledTypeSize(15f, 3.5f, w), 0f, density),
            color = colors.label,
        )
        Spacer(Modifier.height(8.dp))
        Text(
            "${verse.book} ${verse.reference}",
            style = VerseFit.style(CardFontStyle.Body, scaledTypeSize(14f, 3f, w), 0f, density),
            color = colors.label,
        )
        Spacer(Modifier.height(6.dp))
        FittedVerseText(
            text = verse.verse,
            lineSpacing = lineGap,
            minSize = 11f,
            maxSize = 15f,
            modifier = Modifier.weight(1f).fillMaxWidth(),
            color = colors.label,
        )
    }
}

@Composable
private fun ColumnScope.ReviewContent(
    verse: Verse,
    cardWidth: Dp,
    cardHeight: Dp,
    hasFooter: Boolean,
    titleRevealedCount: Int,
    verseRevealedCount: Int,
    activeSection: CardSection,
    hardMode: Boolean,
    onSectionTap: ((CardSection) -> Unit)?,
) {
    val colors = AppTheme.colors
    val density = LocalDensity.current
    val measurer = rememberTextMeasurer(cacheSize = 0)
    val w = cardWidth.value
    val refSize = scaledTypeSize(18f, 3.25f, w)
    val titleSize = scaledTypeSize(16f, 2.75f, w)
    val verseGap = verseLineSpacing(verse.verseWords.size, w)
    val reference = "${verse.book} ${verse.reference}"
    val growth = density.fontScale.coerceIn(1f, 1.3f)

    val verseSize = remember(verse.id, cardWidth, cardHeight, hasFooter, growth, density) {
        val refH = VerseFit.height(measurer, reference, cardWidth, refSize, CardFontStyle.Reference, 0f, density)
        val titleH = VerseFit.height(measurer, verse.title, cardWidth, titleSize, CardFontStyle.Title, 4f, density)
        val badgeH = if (verse.pinnedVersion != null) 22f else 0f
        val reserved = badgeH + refH + 12f + titleH + 8f + (if (hasFooter) 40f else footerlessReserve)
        val avail = max(48f, cardHeight.value - reserved).dp
        val fitWidth = cardWidth - completionMarkReserve
        val largest = scaledTypeSize(16f, 3f, w) * growth
        val widthPx = with(density) { fitWidth.roundToPx() }
        val hidden = buildAnnotatedString {
            verse.verseWords.forEachIndexed { i, word ->
                if (i > 0) append(" ")
                withStyle(SpanStyle(letterSpacing = verseMaskTightening)) { append(masked(word)) }
            }
        }
        var size = VerseFit.fontSize(
            measurer, verse.verse, fitWidth, avail, CardFontStyle.Body, verseGap, 10f, largest, density,
        )
        val room = with(density) { avail.roundToPx() }
        while (size > 10f) {
            val style = VerseFit.style(CardFontStyle.Body, size, verseGap, density)
            val height = measurer.measure(hidden, style, constraints = Constraints(maxWidth = widthPx)).size.height
            if (height <= room) break
            size -= 0.5f
        }
        size
    }

    Column(Modifier.weight(1f).fillMaxWidth()) {
        val pinned = verse.pinnedVersion
        if (pinned != null) {
            VersionBadge(pinned)
            Spacer(Modifier.height(6.dp))
        }
        Text(
            reference,
            style = VerseFit.style(CardFontStyle.Reference, refSize, 0f, density),
            color = colors.label,
        )
        Spacer(Modifier.height(12.dp))
        SectionView(
            section = CardSection.title,
            verseId = verse.id,
            words = verse.titleWords,
            revealed = titleRevealedCount,
            style = VerseFit.style(CardFontStyle.Title, titleSize, 4f, density),
            activeSection = activeSection,
            hardMode = hardMode,
            onSectionTap = onSectionTap,
        )
        Spacer(Modifier.height(8.dp))
        SectionView(
            section = CardSection.verse,
            verseId = verse.id,
            words = verse.verseWords,
            revealed = verseRevealedCount,
            style = VerseFit.style(CardFontStyle.Body, verseSize, verseGap, density),
            activeSection = activeSection,
            hardMode = hardMode,
            onSectionTap = onSectionTap,
            modifier = Modifier.weight(1f),
        )
    }
}

@Composable
private fun SectionView(
    section: CardSection,
    verseId: Int,
    words: List<String>,
    revealed: Int,
    style: TextStyle,
    activeSection: CardSection,
    hardMode: Boolean,
    onSectionTap: ((CardSection) -> Unit)?,
    modifier: Modifier = Modifier,
) {
    val colors = AppTheme.colors
    val isActive = activeSection == section
    val isComplete = revealed >= words.size && words.isNotEmpty()
    val progress = remember(verseId) { Animatable(revealed.toFloat()) }
    LaunchedEffect(verseId, revealed) { progress.animateTo(revealed.toFloat(), AppMotion.control()) }
    val tapSource = remember { MutableInteractionSource() }
    val accent = colors.accent
    val maskSpacing = if (section == CardSection.verse) verseMaskTightening else TextUnit.Unspecified

    Box(
        modifier
            .fillMaxWidth()
            .then(
                if (onSectionTap != null && !isComplete) {
                    Modifier.clickable(interactionSource = tapSource, indication = null) { onSectionTap(section) }
                } else {
                    Modifier
                },
            ),
    ) {
        Box(
            Modifier.drawBehind {
                if (isActive && !isComplete) {
                    drawRoundRect(
                        color = accent,
                        topLeft = Offset(-6.dp.toPx(), 0f),
                        size = Size(2.dp.toPx(), size.height),
                        cornerRadius = CornerRadius(0.5.dp.toPx()),
                    )
                }
            },
        ) {
            when {
                isComplete -> CompletedText(words.joinToString(" "), style)
                hardMode && revealed == 0 -> Text(
                    if (section == CardSection.title) "Title" else "Verse",
                    style = placeholderStyle(style),
                    color = colors.tertiaryLabel,
                )
                hardMode -> Text(
                    words.take(revealed).joinToString(" "),
                    style = style,
                    color = if (isActive) colors.label else colors.secondaryLabel,
                )
                isActive -> Text(
                    activeText(words, revealed, progress.value, colors.label, colors.accent, colors.tertiaryLabel, maskSpacing),
                    style = style,
                    color = colors.label,
                )
                else -> Text(
                    inactiveText(words, revealed, colors.secondaryLabel, colors.tertiaryLabel.copy(alpha = 0.6f), maskSpacing),
                    style = style,
                    color = colors.secondaryLabel,
                )
            }
        }
    }
}

@Composable
private fun CompletedText(text: String, style: TextStyle) {
    val colors = AppTheme.colors
    val density = LocalDensity.current
    var widest by remember(text) { mutableStateOf(0f) }
    Box {
        Text(
            text,
            Modifier.padding(end = completionMarkReserve),
            style = style,
            color = colors.label,
            onTextLayout = { layout ->
                widest = (0 until layout.lineCount).maxOfOrNull(layout::getLineRight) ?: 0f
            },
        )
        Icon(
            R.drawable.ic_check_circle_fill,
            Modifier.offset(x = with(density) { widest.toDp() } + 4.dp, y = 2.dp),
            size = completionMarkSize,
            tint = colors.green,
        )
    }
}

@Composable
private fun placeholderStyle(base: TextStyle): TextStyle {
    val density = LocalDensity.current
    return CardFont.style(CardFontStyle.Body, with(density) { 18.dp.toSp() }).merge(TextStyle(lineHeight = base.lineHeight))
}

private fun activeText(
    words: List<String>,
    revealed: Int,
    progress: Float,
    label: Color,
    accent: Color,
    tertiary: Color,
    maskSpacing: TextUnit,
): AnnotatedString = buildAnnotatedString {
    words.forEachIndexed { i, word ->
        val separator = if (i < words.size - 1) " " else ""
        val color = when {
            i < revealed -> lerp(accent, label, (progress - i).coerceIn(0f, 1f))
            i == revealed -> lerp(tertiary, accent, (progress - (i - 1)).coerceIn(0f, 1f))
            else -> tertiary
        }
        val spacing = if (i < revealed) TextUnit.Unspecified else maskSpacing
        withStyle(SpanStyle(color = color, letterSpacing = spacing)) {
            append(if (i < revealed) word else masked(word))
        }
        append(separator)
    }
}

private fun inactiveText(
    words: List<String>,
    revealed: Int,
    secondary: Color,
    quaternary: Color,
    maskSpacing: TextUnit,
): AnnotatedString = buildAnnotatedString {
    words.forEachIndexed { i, word ->
        val separator = if (i < words.size - 1) " " else ""
        val spacing = if (i < revealed) TextUnit.Unspecified else maskSpacing
        withStyle(SpanStyle(color = if (i < revealed) secondary else quaternary, letterSpacing = spacing)) {
            append(if (i < revealed) word else masked(word))
        }
        append(separator)
    }
}
