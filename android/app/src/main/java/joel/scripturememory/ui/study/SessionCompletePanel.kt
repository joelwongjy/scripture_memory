package joel.scripturememory.ui.study

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.spring
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import joel.scripturememory.R
import joel.scripturememory.model.StudyMode
import joel.scripturememory.model.TestSessionViewModel
import joel.scripturememory.ui.components.Icon
import joel.scripturememory.ui.components.Text
import joel.scripturememory.ui.theme.AppMotion
import joel.scripturememory.ui.theme.AppTheme
import joel.scripturememory.ui.theme.AppType

@Composable
fun rememberSymbolBounce(): Animatable<Float, *> {
    val scale = remember { Animatable(if (AppMotion.reduceMotion) 1f else 0.6f) }
    LaunchedEffect(Unit) {
        if (!AppMotion.reduceMotion) {
            scale.animateTo(1f, spring(dampingRatio = 0.45f, stiffness = Spring.StiffnessLow))
        }
    }
    return scale
}

@Composable
fun SessionCompletePanel(vm: TestSessionViewModel, studyMode: StudyMode, compact: Boolean, onDone: () -> Unit) {
    val colors = AppTheme.colors
    val bounce = rememberSymbolBounce()
    val mistakes = -vm.sessionScore
    val perfect = vm.sessionScore == 0

    @Composable
    fun Seal(size: Dp) {
        Icon(
            if (perfect) R.drawable.ic_seal_check_fill else R.drawable.ic_check_circle_fill,
            Modifier.graphicsLayer {
                scaleX = bounce.value
                scaleY = bounce.value
            },
            size = size,
            tint = if (perfect) colors.green else colors.accent,
        )
    }

    @Composable
    fun Title() {
        Text("Session Complete", style = AppType.title3.copy(fontWeight = FontWeight.Bold), color = colors.label, maxLines = 1)
    }

    @Composable
    fun Score() {
        if (studyMode == StudyMode.submit) {
            Text(
                when (mistakes) {
                    0 -> "No mistakes"
                    1 -> "1 mistake"
                    else -> "$mistakes mistakes"
                },
                style = AppType.body.copy(fontWeight = FontWeight.SemiBold),
                color = if (mistakes == 0) colors.green else colors.red,
                maxLines = 1,
            )
            Text(
                "${vm.perfectCount} of ${vm.verses.size} perfect",
                style = AppType.subheadline,
                color = colors.secondaryLabel,
                maxLines = 1,
            )
        } else {
            Text(
                "${vm.verses.size} verses reviewed",
                style = AppType.subheadline,
                color = colors.secondaryLabel,
                maxLines = 1,
            )
        }
    }

    @Composable
    fun Actions(modifier: Modifier) {
        Row(modifier, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            StudyActionButton("Try Again", Modifier.weight(1f), onClick = { vm.resetAllProgress() })
            StudyActionButton(
                "Done",
                Modifier.weight(1f),
                foreground = colors.onAccent,
                background = colors.accent,
                onClick = onDone,
            )
        }
    }

    if (compact) {
        Row(
            Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Seal(32.dp)
            Column(Modifier.weight(1f)) {
                Title()
                Score()
            }
            Actions(Modifier.weight(1f))
        }
    } else {
        Column(
            Modifier.fillMaxWidth(),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            Seal(44.dp)
            Title()
            Score()
            Actions(Modifier)
        }
    }
}
