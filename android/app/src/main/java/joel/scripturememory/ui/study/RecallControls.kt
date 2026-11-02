package joel.scripturememory.ui.study

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.SideEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextRange
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.TextFieldValue
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import joel.scripturememory.R
import joel.scripturememory.model.RecallCardViewModel
import joel.scripturememory.model.StudyMode
import joel.scripturememory.system.HapticEngine
import joel.scripturememory.ui.components.Icon
import joel.scripturememory.ui.components.Text
import joel.scripturememory.ui.components.pressable
import joel.scripturememory.ui.theme.AppMotion
import joel.scripturememory.ui.theme.AppTheme
import joel.scripturememory.ui.theme.AppType
import joel.scripturememory.ui.theme.StudyControlMetrics

@Composable
fun StudyControlTile(
    icon: Int,
    label: String,
    tint: Color = AppTheme.colors.label,
    onClick: () -> Unit,
) {
    Box(
        Modifier
            .size(StudyControlMetrics.buttonSize)
            .semantics { contentDescription = label }
            .pressable(pressedScale = 0.92f, onClick = onClick)
            .systemGlass(CircleShape),
        contentAlignment = Alignment.Center,
    ) {
        Icon(icon, size = 20.dp, tint = tint)
    }
}

@Composable
fun HintButton(onClick: () -> Unit) {
    StudyControlTile(R.drawable.ic_lightbulb, "Reveal next word") {
        onClick()
        HapticEngine.light()
    }
}

@Composable
fun DictationTile(isListening: Boolean, onClick: () -> Unit) {
    val colors = AppTheme.colors
    StudyControlTile(
        icon = if (isListening) R.drawable.ic_microphone_fill else R.drawable.ic_microphone,
        label = if (isListening) "Stop dictation" else "Dictate verse",
        tint = if (isListening) colors.red else colors.label,
        onClick = onClick,
    )
}

@Composable
fun RecallInputField(
    vm: RecallCardViewModel,
    studyMode: StudyMode,
    isListening: Boolean,
    focusRequester: FocusRequester,
    onFocusChange: (Boolean) -> Unit,
    onToggleSpeech: () -> Unit,
) {
    val colors = AppTheme.colors
    val scope = rememberCoroutineScope()
    val shake = remember { Animatable(0f) }
    val density = LocalDensity.current
    val firstLetter = remember { FirstLetterGate() }
    val fullWord = remember { FullWordGate() }
    var field by remember { mutableStateOf(TextFieldValue()) }
    var inputRevision by remember { mutableIntStateOf(0) }
    val hidesTyping = studyMode == StudyMode.firstLetter

    fun miss() {
        HapticEngine.error()
        scope.triggerShake(shake)
    }

    fun change(incoming: TextFieldValue) {
        inputRevision += 1
        if (studyMode == StudyMode.firstLetter) {
            field = firstLetter.accept(incoming) { grapheme ->
                if (vm.processFirstLetterInput(grapheme)) HapticEngine.light() else miss()
            }
        } else {
            field = fullWord.accept(incoming) { word ->
                if (vm.processFullWordInput(word)) HapticEngine.light() else miss()
            }
            vm.inputText = field.text
        }
    }

    LaunchedEffect(vm.inputText) {
        if (!hidesTyping && vm.inputText != field.text) {
            field = TextFieldValue(vm.inputText, TextRange(vm.inputText.length))
        }
    }

    Row(horizontalArrangement = Arrangement.spacedBy(StudyControlMetrics.rowSpacing)) {
        Row(
            Modifier
                .weight(1f)
                .height(StudyControlMetrics.buttonSize)
                .graphicsLayer { translationX = shake.value * density.density }
                .systemGlass(CapsuleShape)
                .padding(start = 12.dp, end = 18.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(6.dp),
        ) {
            Box(
                Modifier
                    .size(32.dp)
                    .semantics { contentDescription = if (isListening) "Stop dictation" else "Dictate verse" }
                    .pressable(pressedScale = 0.9f, onClick = onToggleSpeech),
                contentAlignment = Alignment.Center,
            ) {
                AnimatedContent(
                    targetState = isListening,
                    transitionSpec = { fadeIn(AppMotion.control()).togetherWith(fadeOut(AppMotion.control())) },
                    label = "mic",
                ) { listening ->
                    Icon(
                        if (listening) R.drawable.ic_microphone_fill else R.drawable.ic_microphone,
                        size = 20.dp,
                        tint = if (listening) colors.red else colors.secondaryLabel,
                    )
                }
            }
            StudyInputMethod(StudyInputKind.Recall) {
                inputRevision
                SideEffect {
                    firstLetter.frameApplied(field)
                    fullWord.frameApplied()
                }
                BasicTextField(
                    value = field,
                    onValueChange = ::change,
                    modifier = Modifier
                        .weight(1f)
                        .focusRequester(focusRequester)
                        .onFocusChanged { onFocusChange(it.isFocused) }
                        .semantics { contentDescription = studyMode.inputPlaceholder },
                    textStyle = AppType.body.copy(color = colors.label),
                    singleLine = true,
                    visualTransformation = if (hidesTyping) HiddenTyping else VisualTransformation.None,
                    cursorBrush = SolidColor(colors.accent),
                    keyboardOptions = KeyboardOptions(
                        capitalization = KeyboardCapitalization.None,
                        autoCorrectEnabled = false,
                        keyboardType = KeyboardType.Text,
                        imeAction = ImeAction.None,
                    ),
                    decorationBox = { inner ->
                        Box(contentAlignment = Alignment.CenterStart) {
                            if (hidesTyping || field.text.isEmpty()) {
                                Text(
                                    studyMode.inputPlaceholder,
                                    style = AppType.body,
                                    color = colors.tertiaryLabel,
                                    maxLines = 1,
                                    overflow = TextOverflow.Ellipsis,
                                )
                            }
                            inner()
                        }
                    },
                )
            }
        }
        HintButton { vm.revealHint() }
    }
}

@Composable
fun StudyActionLabel(
    modifier: Modifier = Modifier,
    foreground: Color = AppTheme.colors.label,
    background: Color = AppTheme.colors.panel,
    verticalPadding: androidx.compose.ui.unit.Dp = 12.dp,
    content: @Composable RowScope.(Color) -> Unit,
) {
    Row(
        modifier
            .fillMaxWidth()
            .heightIn(min = StudyControlMetrics.buttonSize - 4.dp)
            .clip(CapsuleShape)
            .background(background)
            .padding(vertical = verticalPadding, horizontal = 12.dp),
        horizontalArrangement = Arrangement.spacedBy(8.dp, Alignment.CenterHorizontally),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        content(foreground)
    }
}

private val studyActionStyle = AppType.headline.copy(fontWeight = FontWeight.SemiBold)

@Composable
fun StudyActionButton(
    title: String,
    modifier: Modifier = Modifier,
    icon: Int? = null,
    iconTint: Color? = null,
    foreground: Color = AppTheme.colors.label,
    background: Color = AppTheme.colors.panel,
    enabled: Boolean = true,
    disabledAlpha: Float = 1f,
    verticalPadding: androidx.compose.ui.unit.Dp = 12.dp,
    onClick: () -> Unit,
) {
    Box(
        modifier
            .alpha(if (enabled) 1f else disabledAlpha)
            .pressable(enabled = enabled, onClick = onClick),
    ) {
        StudyActionLabel(foreground = foreground, background = background, verticalPadding = verticalPadding) { tint ->
            if (icon != null) Icon(icon, size = 18.dp, tint = iconTint ?: tint)
            Text(title, style = studyActionStyle, color = tint, maxLines = 1)
        }
    }
}

@Composable
fun TryAgainButton(modifier: Modifier = Modifier, onClick: () -> Unit) {
    StudyActionButton("Try Again", modifier, icon = R.drawable.ic_arrow_counter_clockwise, onClick = onClick)
}

@Composable
fun MarkCompleteButton(modifier: Modifier = Modifier, onClick: () -> Unit) {
    val colors = AppTheme.colors
    Box(modifier.semantics { contentDescription = "Mark current verse as complete" }) {
        StudyActionButton(
            "Complete",
            icon = R.drawable.ic_check_circle_fill,
            foreground = colors.onAccent,
            background = colors.green,
            onClick = onClick,
        )
    }
}

@Composable
fun SubmitAnswerRow(
    isListening: Boolean,
    canSubmit: Boolean,
    onToggleSpeech: () -> Unit,
    onHint: () -> Unit,
    onSubmit: () -> Unit,
) {
    val colors = AppTheme.colors
    Row(
        horizontalArrangement = Arrangement.spacedBy(StudyControlMetrics.rowSpacing),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        DictationTile(isListening, onToggleSpeech)
        HintButton(onHint)
        StudyActionButton(
            "Submit",
            Modifier.weight(1f),
            foreground = colors.onAccent,
            background = if (canSubmit) colors.accent else colors.tertiaryLabel,
            enabled = canSubmit,
            onClick = onSubmit,
        )
    }
}
