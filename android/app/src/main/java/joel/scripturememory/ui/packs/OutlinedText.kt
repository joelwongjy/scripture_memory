package joel.scripturememory.ui.packs

import androidx.compose.foundation.layout.Box
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.unit.Dp
import joel.scripturememory.ui.components.Text

@Composable
fun OutlinedText(
    text: String,
    style: TextStyle,
    stroke: Color,
    fill: Color,
    modifier: Modifier = Modifier,
    width: Dp,
) {
    val outline = with(LocalDensity.current) { width.toPx() } * 2
    Box(modifier) {
        Text(
            text,
            style = style.copy(drawStyle = Stroke(width = outline, miter = 2.4f, join = StrokeJoin.Miter)),
            color = stroke,
            maxLines = 1,
        )
        Text(text, style = style, color = fill, maxLines = 1)
    }
}
