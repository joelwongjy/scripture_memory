package joel.scripturememory.ui.quiz

import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.foundation.gestures.waitForUpOrCancellation
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.Stable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.disabled
import androidx.compose.ui.semantics.onClick
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import joel.scripturememory.R
import joel.scripturememory.system.HapticEngine
import joel.scripturememory.ui.components.Icon
import joel.scripturememory.ui.components.Text
import joel.scripturememory.ui.components.TextButton
import joel.scripturememory.ui.study.CapsuleShape
import joel.scripturememory.ui.theme.AppTheme
import joel.scripturememory.ui.theme.AppType
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

private const val repeatStartMillis = 400L
private const val repeatMillis = 70L

@Stable
class QuizCountEntry {
    var draft by mutableStateOf("")
    var typing by mutableStateOf(false)
    val focus = FocusRequester()
}

private val countStyle = AppType.title1.copy(
    fontSize = 28.sp,
    fontWeight = FontWeight.Bold,
    textAlign = TextAlign.Center,
    fontFeatureSettings = "tnum",
)

@Composable
fun QuizCountPicker(
    count: Int,
    maximum: Int,
    onCountChange: (Int) -> Unit,
    entry: QuizCountEntry,
) {
    val colors = AppTheme.colors
    val focusManager = LocalFocusManager.current
    val upperBound = maxOf(1, maximum)
    val clampedCount = count.coerceIn(1, upperBound)

    fun set(n: Int) {
        val new = n.coerceIn(1, upperBound)
        if (new == clampedCount) return
        onCountChange(new)
        HapticEngine.light()
    }
    val commit by rememberUpdatedState<(Int) -> Unit>({ set(it) })

    LaunchedEffect(clampedCount, entry.typing) {
        if (!entry.typing) entry.draft = "$clampedCount"
    }

    Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
        StepButton(R.drawable.ic_minus, "Fewer verses", clampedCount > 1) { set(clampedCount - 1) }
        Spacer(Modifier.weight(1f))
        Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(2.dp)) {
            BasicTextField(
                value = entry.draft,
                onValueChange = { new -> entry.draft = new.filter(Char::isDigit).take(4) },
                modifier = Modifier
                    .width(96.dp)
                    .clip(CapsuleShape)
                    .background(colors.fill)
                    .padding(vertical = 2.dp)
                    .focusRequester(entry.focus)
                    .onFocusChanged { state ->
                        if (state.isFocused == entry.typing) return@onFocusChanged
                        entry.typing = state.isFocused
                        if (state.isFocused) {
                            entry.draft = ""
                        } else {
                            entry.draft.toIntOrNull()?.let(commit)
                        }
                    }
                    .semantics {
                        contentDescription = "Verses to quiz"
                        stateDescription = "$clampedCount of $maximum"
                    },
                textStyle = countStyle.copy(color = colors.label),
                singleLine = true,
                cursorBrush = SolidColor(colors.accent),
                keyboardOptions = KeyboardOptions(
                    keyboardType = KeyboardType.NumberPassword,
                    imeAction = ImeAction.Done,
                    autoCorrectEnabled = false,
                ),
                keyboardActions = KeyboardActions(onDone = { focusManager.clearFocus() }),
                decorationBox = { inner ->
                    Box(contentAlignment = Alignment.Center) {
                        if (entry.draft.isEmpty()) {
                            Text("$clampedCount", style = countStyle, color = colors.tertiaryLabel, maxLines = 1)
                        }
                        inner()
                    }
                },
            )
            Text(
                if (clampedCount == upperBound) "all verses" else "of $maximum verses",
                style = AppType.footnote,
                color = colors.secondaryLabel,
            )
        }
        Spacer(Modifier.weight(1f))
        StepButton(R.drawable.ic_plus, "More verses", clampedCount < upperBound) { set(clampedCount + 1) }
    }
}

@Composable
fun QuizCountKeyboardBar(maximum: Int, entry: QuizCountEntry) {
    val focusManager = LocalFocusManager.current
    if (!entry.typing) return
    Row(
        Modifier.fillMaxWidth().padding(top = 4.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        TextButton("All $maximum", style = AppType.callout) {
            entry.draft = "${maxOf(1, maximum)}"
            focusManager.clearFocus()
        }
        Spacer(Modifier.weight(1f))
        TextButton("Done", style = AppType.callout.copy(fontWeight = FontWeight.SemiBold)) {
            focusManager.clearFocus()
        }
    }
}

@Composable
private fun StepButton(icon: Int, label: String, enabled: Boolean, onStep: () -> Unit) {
    val colors = AppTheme.colors
    val scope = rememberCoroutineScope()
    val step by rememberUpdatedState(onStep)
    val canStep by rememberUpdatedState(enabled)
    Box(
        Modifier
            .size(48.dp)
            .alpha(if (enabled) 1f else 0.35f)
            .semantics {
                contentDescription = label
                role = Role.Button
                if (!enabled) disabled()
                onClick {
                    step()
                    true
                }
            }
            .pointerInput(Unit) {
                awaitEachGesture {
                    awaitFirstDown()
                    var repeated = false
                    val job = scope.launch {
                        delay(repeatStartMillis)
                        repeated = true
                        while (canStep) {
                            step()
                            delay(repeatMillis)
                        }
                    }
                    val up = waitForUpOrCancellation()
                    job.cancel()
                    if (up != null && !repeated && canStep) step()
                }
            }
            .clip(CircleShape)
            .background(colors.fill),
        contentAlignment = Alignment.Center,
    ) {
        Icon(icon, size = 20.dp, tint = colors.accent)
    }
}
