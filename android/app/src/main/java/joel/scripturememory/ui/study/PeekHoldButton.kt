package joel.scripturememory.ui.study

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.animation.scaleOut
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.foundation.gestures.waitForUpOrCancellation
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.wrapContentSize
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.TransformOrigin
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.layout
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.onClick
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import joel.scripturememory.R
import joel.scripturememory.model.AppDefaults
import joel.scripturememory.system.HapticEngine
import joel.scripturememory.ui.components.Icon
import joel.scripturememory.ui.components.Text
import joel.scripturememory.ui.theme.AppMotion
import joel.scripturememory.ui.theme.AppTheme
import joel.scripturememory.ui.theme.AppType
import joel.scripturememory.ui.theme.StudyControlMetrics
import kotlinx.coroutines.delay

private const val peekHintSeenKey = "peekHintSeen"

@Composable
fun PeekHoldButton(isPeeking: Boolean, onPeekChange: (Boolean) -> Unit) {
    val colors = AppTheme.colors
    var showHint by remember { mutableStateOf(false) }

    fun dismissHint() {
        showHint = false
        AppDefaults.standard.putBool(peekHintSeenKey, true)
    }

    fun press(pressed: Boolean) {
        onPeekChange(pressed)
        if (pressed) {
            HapticEngine.light()
            dismissHint()
        }
    }

    LaunchedEffect(Unit) {
        if (AppDefaults.standard.getBool(peekHintSeenKey) == true) return@LaunchedEffect
        delay(700)
        if (AppDefaults.standard.getBool(peekHintSeenKey) == true) return@LaunchedEffect
        showHint = true
        delay(4000)
        dismissHint()
    }

    Box(contentAlignment = Alignment.TopCenter) {
        Box(
            Modifier
                .size(StudyControlMetrics.buttonSize)
                .semantics {
                    contentDescription = "Peek at answer"
                    role = Role.Button
                    onClick(label = "reveal the verse") {
                        press(!isPeeking)
                        true
                    }
                }
                .pointerInput(Unit) {
                    awaitEachGesture {
                        awaitFirstDown(requireUnconsumed = false)
                        press(true)
                        waitForUpOrCancellation()
                        press(false)
                    }
                }
                .clip(CircleShape)
                .systemGlass(CircleShape),
            contentAlignment = Alignment.Center,
        ) {
            AnimatedContent(
                targetState = isPeeking,
                transitionSpec = { fadeIn(AppMotion.control()).togetherWith(fadeOut(AppMotion.control())) },
                label = "peekIcon",
            ) { peeking ->
                Icon(
                    if (peeking) R.drawable.ic_eye_fill else R.drawable.ic_eye,
                    size = 21.dp,
                    tint = if (peeking) colors.accent else colors.secondaryLabel,
                )
            }
        }
        val hintLift = with(LocalDensity.current) { 34.dp.roundToPx() }
        AnimatedVisibility(
            visible = showHint,
            modifier = Modifier
                .layout { measurable, constraints ->
                    val placeable = measurable.measure(constraints.copy(minWidth = 0, maxWidth = Int.MAX_VALUE, minHeight = 0))
                    layout(0, 0) { placeable.place(-placeable.width / 2 + 0, -hintLift) }
                }
                .wrapContentSize(unbounded = true),
            enter = fadeIn(AppMotion.movement()) +
                scaleIn(AppMotion.movement(), initialScale = 0.9f, transformOrigin = TransformOrigin(0.5f, 1f)),
            exit = fadeOut(AppMotion.control()) +
                scaleOut(AppMotion.control(), targetScale = 0.9f, transformOrigin = TransformOrigin(0.5f, 1f)),
        ) {
            Text(
                "Hold to peek",
                Modifier
                    .clip(CapsuleShape)
                    .background(colors.accent)
                    .padding(horizontal = 10.dp, vertical = 5.dp),
                style = AppType.caption.copy(fontWeight = FontWeight.SemiBold),
                color = colors.onAccent,
                maxLines = 1,
            )
        }
    }
}
