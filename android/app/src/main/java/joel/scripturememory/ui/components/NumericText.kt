package joel.scripturememory.ui.components

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.SizeTransform
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.layout.Row
import androidx.compose.runtime.Composable
import androidx.compose.runtime.key
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.unit.IntOffset
import joel.scripturememory.ui.theme.AppMotion
import joel.scripturememory.ui.theme.AppType
import joel.scripturememory.ui.theme.LocalContentColor

@Composable
fun NumericText(
    value: Int,
    modifier: Modifier = Modifier,
    style: TextStyle = AppType.body,
    color: Color = LocalContentColor.current,
) {
    val digits = value.toString()
    Row(
        modifier.clearAndSetSemantics { contentDescription = digits },
        verticalAlignment = Alignment.CenterVertically,
    ) {
        digits.forEachIndexed { index, digit ->
            key(digits.length - index) {
                AnimatedContent(
                    targetState = digit,
                    transitionSpec = {
                        val direction = if (targetState > initialState) 1 else -1
                        val offsetFraction = 0.45f
                        val move = AppMotion.content<IntOffset>()
                        val fade = AppMotion.content<Float>()
                        if (AppMotion.reduceMotion) {
                            fadeIn(fade) togetherWith fadeOut(fade)
                        } else {
                            (slideInVertically(move) { (it * offsetFraction * direction).toInt() } + fadeIn(fade))
                                .togetherWith(
                                    slideOutVertically(move) { -(it * offsetFraction * direction).toInt() } + fadeOut(fade),
                                )
                        } using SizeTransform(clip = false)
                    },
                    contentAlignment = Alignment.Center,
                    label = "numericDigit",
                ) { shown ->
                    Text(shown.toString(), style = style, color = color, maxLines = 1)
                }
            }
        }
    }
}
