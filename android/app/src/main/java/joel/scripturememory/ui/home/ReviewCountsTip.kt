package joel.scripturememory.ui.home

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.dp
import joel.scripturememory.R
import joel.scripturememory.model.AppDefaults
import joel.scripturememory.ui.components.Icon
import joel.scripturememory.ui.components.Text
import joel.scripturememory.ui.components.groupedPanel
import joel.scripturememory.ui.components.pressable
import joel.scripturememory.ui.theme.AppLayout
import joel.scripturememory.ui.theme.AppTheme
import joel.scripturememory.ui.theme.AppType

object ReviewCountsTip {
    const val dismissedKey = "tips.reviewCounts.dismissed.v1"

    val isDismissed: Boolean get() = AppDefaults.standard.getBool(dismissedKey) ?: false

    fun dismiss() = AppDefaults.standard.putBool(dismissedKey, true)

    const val newHint = "Verses you haven’t started."
    const val learnHint = "Verses you haven’t got right yet."
    const val dueHint = "Memorised verses scheduled for today."
}

@Composable
fun ReviewCountsTipCard(modifier: Modifier = Modifier) {
    val colors = AppTheme.colors
    val message = buildAnnotatedString {
        fun line(label: String, color: Color, text: String, last: Boolean = false) {
            withStyle(SpanStyle(color = color, fontWeight = FontWeight.SemiBold)) { append(label) }
            append(" – $text")
            if (!last) append("\n")
        }
        line("New", ReviewColor.new, "verses you haven’t started.")
        line("Learn", ReviewColor.learn, "verses you haven’t got right yet. They come back soon.")
        line("Due", ReviewColor.due, "memorised verses scheduled for today. Get them right and they come back less often.", last = true)
    }
    Row(
        modifier
            .fillMaxWidth()
            .groupedPanel()
            .padding(start = AppLayout.panelPadding, top = 16.dp, end = 12.dp, bottom = 16.dp),
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Icon(R.drawable.ic_lightbulb, size = 26.dp, tint = colors.accent)
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Text("New, Learn and Due", style = AppType.headline, color = colors.label)
            Text(message, style = AppType.subheadline, color = colors.secondaryLabel)
        }
        Box(
            Modifier
                .size(28.dp)
                .semantics { contentDescription = "Close" }
                .pressable(pressedScale = 0.9f, onClick = ReviewCountsTip::dismiss)
                .clip(CircleShape)
                .background(colors.fill),
            contentAlignment = Alignment.Center,
        ) {
            Icon(R.drawable.ic_x, size = 12.dp, tint = colors.secondaryLabel)
        }
    }
}
