package joel.scripturememory.ui.pouch

import androidx.compose.animation.animateContentSize
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.defaultMinSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import joel.scripturememory.R
import joel.scripturememory.ui.components.Icon
import joel.scripturememory.ui.components.Text
import joel.scripturememory.ui.components.pressable
import joel.scripturememory.ui.components.softShadow
import joel.scripturememory.ui.theme.AppMotion
import joel.scripturememory.ui.theme.AppTheme
import joel.scripturememory.ui.theme.AppType
import kotlinx.coroutines.delay

@Composable
internal fun PouchJumpButton(
    startExpanded: Boolean,
    onExpandedShown: () -> Unit,
    modifier: Modifier = Modifier,
    action: () -> Unit,
) {
    val colors = AppTheme.colors
    var expanded by remember { mutableStateOf(startExpanded) }
    val capsule = RoundedCornerShape(percent = 50)

    LaunchedEffect(Unit) {
        if (expanded) {
            onExpandedShown()
            delay(1000)
            expanded = false
        }
    }

    Row(
        modifier
            .semantics { contentDescription = "Jump to current verse" }
            .pressable(onClick = action)
            .softShadow(capsule, 8.dp)
            .clip(capsule)
            .background(colors.accent)
            .animateContentSize(AppMotion.movement())
            .defaultMinSize(minWidth = if (expanded) 0.dp else 44.dp, minHeight = if (expanded) 0.dp else 44.dp)
            .padding(horizontal = if (expanded) 14.dp else 0.dp, vertical = if (expanded) 10.dp else 0.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(6.dp, Alignment.CenterHorizontally),
    ) {
        Icon(R.drawable.ic_bookmark_fill, size = if (expanded) 14.dp else 18.dp, tint = colors.onAccent)
        if (expanded) {
            Text(
                "Jump to current verse",
                style = AppType.footnote.copy(fontWeight = FontWeight.SemiBold, fontSize = 13.sp),
                color = colors.onAccent,
                maxLines = 1,
            )
        }
    }
}
