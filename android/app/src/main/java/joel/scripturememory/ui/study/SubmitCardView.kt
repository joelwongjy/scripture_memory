package joel.scripturememory.ui.study

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.text.TextAutoSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.TextRange
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.input.TextFieldValue
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.em
import androidx.compose.ui.unit.sp
import joel.scripturememory.model.DiffWord
import joel.scripturememory.model.SubmitField
import joel.scripturememory.model.SubmitResult
import joel.scripturememory.model.Verse
import joel.scripturememory.ui.components.Divider
import joel.scripturememory.ui.components.Text
import joel.scripturememory.ui.components.VerseFit
import joel.scripturememory.ui.theme.AppColors
import joel.scripturememory.ui.theme.AppTheme
import joel.scripturememory.ui.theme.CardFont
import joel.scripturememory.ui.theme.CardFontStyle

class SubmitFocus {
    val title = FocusRequester()
    val verse = FocusRequester()
}

@Composable
fun SubmitCardView(
    verse: Verse,
    cardLabel: String,
    titleText: String,
    onTitleChange: (String) -> Unit,
    verseText: String,
    onVerseChange: (String) -> Unit,
    result: SubmitResult?,
    focus: SubmitFocus,
    interactive: Boolean,
    onFocusChange: (SubmitField, Boolean) -> Unit,
    modifier: Modifier = Modifier,
    isCurrentLearning: Boolean = false,
    showCardLabel: Boolean = true,
    showsFavoriteToggle: Boolean = false,
) {
    PaperAppearance {
        val density = LocalDensity.current
        Box(modifier.fillMaxSize().flashcardStyle()) {
            Column(Modifier.fillMaxSize()) {
                Text(
                    "${verse.book} ${verse.reference}",
                    style = VerseFit.style(CardFontStyle.Reference, 18f, 0f, density),
                    color = AppTheme.colors.label,
                    maxLines = 1,
                )
                Spacer(Modifier.height(10.dp))
                Box(Modifier.weight(1f).fillMaxWidth()) {
                    if (result != null) {
                        DiffView(result)
                    } else {
                        InputView(titleText, onTitleChange, verseText, onVerseChange, focus, interactive, onFocusChange)
                    }
                }
                CardFooterRow(
                    verse = verse,
                    cardLabel = cardLabel,
                    showCardLabel = showCardLabel,
                    showsFavoriteToggle = showsFavoriteToggle,
                    isCurrentLearning = isCurrentLearning,
                    modifier = Modifier.padding(top = 6.dp),
                )
            }
        }
    }
}

@Composable
private fun BoxScope.InputView(
    titleText: String,
    onTitleChange: (String) -> Unit,
    verseText: String,
    onVerseChange: (String) -> Unit,
    focus: SubmitFocus,
    interactive: Boolean,
    onFocusChange: (SubmitField, Boolean) -> Unit,
) {
    val colors = AppTheme.colors
    Column(Modifier.matchParentSize()) {
        StudyInputMethod(StudyInputKind.Prose) {
            SubmitTextField(
                text = titleText,
                onTextChange = onTitleChange,
                placeholder = "Title",
                style = CardFont.style(CardFontStyle.Title, 16.sp).copy(color = colors.label),
                placeholderColor = colors.tertiaryLabel,
                singleLine = true,
                interactive = interactive,
                imeAction = ImeAction.Next,
                onImeAction = {
                    runCatching { focus.verse.requestFocus() }
                },
                modifier = Modifier
                    .fillMaxWidth()
                    .then(if (interactive) Modifier.focusRequester(focus.title) else Modifier)
                    .onFocusChanged { onFocusChange(SubmitField.title, it.isFocused) },
            )
            Divider(Modifier.padding(vertical = 6.dp))
            SubmitTextField(
                text = verseText,
                onTextChange = onVerseChange,
                placeholder = "Verse",
                style = CardFont.style(CardFontStyle.Body, 15.sp).copy(color = colors.label, lineHeight = 22.sp),
                placeholderColor = colors.secondaryLabel.copy(alpha = 0.45f),
                singleLine = false,
                interactive = interactive,
                imeAction = ImeAction.Default,
                onImeAction = {},
                modifier = Modifier
                    .weight(1f)
                    .fillMaxWidth()
                    .then(if (interactive) Modifier.focusRequester(focus.verse) else Modifier)
                    .onFocusChanged { onFocusChange(SubmitField.verse, it.isFocused) },
            )
        }
    }
}

@Composable
private fun SubmitTextField(
    text: String,
    onTextChange: (String) -> Unit,
    placeholder: String,
    style: TextStyle,
    placeholderColor: Color,
    singleLine: Boolean,
    interactive: Boolean,
    imeAction: ImeAction,
    onImeAction: () -> Unit,
    modifier: Modifier,
) {
    val colors = AppTheme.colors
    var stored by remember { mutableStateOf(TextFieldValue(text, TextRange(text.length))) }
    val value = if (stored.text == text) stored else TextFieldValue(text, TextRange(text.length))
    BasicTextField(
        value = value,
        onValueChange = {
            stored = it
            onTextChange(it.text)
        },
        modifier = modifier,
        enabled = interactive,
        singleLine = singleLine,
        textStyle = style,
        cursorBrush = SolidColor(colors.accent),
        keyboardOptions = KeyboardOptions(
            capitalization = KeyboardCapitalization.None,
            autoCorrectEnabled = false,
            imeAction = imeAction,
        ),
        keyboardActions = KeyboardActions(onNext = { onImeAction() }),
        decorationBox = { inner ->
            Box(contentAlignment = if (singleLine) Alignment.CenterStart else Alignment.TopStart) {
                if (text.isEmpty()) Text(placeholder, style = style, color = placeholderColor, maxLines = 1)
                inner()
            }
        },
    )
}

@Composable
private fun DiffView(result: SubmitResult) {
    val colors = AppTheme.colors
    Column(Modifier.fillMaxSize()) {
        Text(
            diffLine(result.titleDiffs, colors),
            style = CardFont.style(CardFontStyle.Title, 16.sp).copy(lineHeight = 1.3.em),
            color = colors.label,
        )
        Spacer(Modifier.height(8.dp))
        Text(
            diffLine(result.verseDiffs, colors),
            Modifier.weight(1f).fillMaxWidth(),
            style = CardFont.style(CardFontStyle.Body, 15.sp).copy(lineHeight = 1.3.em),
            color = colors.label,
            autoSize = TextAutoSize.StepBased(minFontSize = 9.sp, maxFontSize = 15.sp, stepSize = 0.25.sp),
        )
    }
}

private fun diffLine(diffs: List<DiffWord>, colors: AppColors): AnnotatedString {
    val groups = mutableListOf<MutableList<DiffWord>>()
    for (word in diffs) {
        val last = groups.lastOrNull()
        if (last != null && last.first().kind == word.kind) last.add(word) else groups.add(mutableListOf(word))
    }
    val faintRed = SpanStyle(color = colors.red.copy(alpha = 0.5f), textDecoration = TextDecoration.LineThrough)
    return buildAnnotatedString {
        groups.forEachIndexed { index, group ->
            val separator = if (index < groups.size - 1) " " else ""
            val joined = group.joinToString(" ") { it.text }
            when (group.first().kind) {
                DiffWord.Kind.correct -> withStyle(SpanStyle(color = colors.green)) { append(joined + separator) }
                DiffWord.Kind.wrong -> {
                    val corrections = group.mapNotNull { it.correction }.joinToString(" ")
                    withStyle(faintRed) { append("$joined ") }
                    if (corrections.isNotEmpty()) {
                        withStyle(SpanStyle(color = colors.red)) { append(corrections + separator) }
                    }
                }
                DiffWord.Kind.missing -> withStyle(SpanStyle(color = colors.secondaryLabel.copy(alpha = 0.5f))) {
                    append(joined + separator)
                }
                DiffWord.Kind.extra -> withStyle(faintRed) { append(joined + separator) }
            }
        }
    }
}
