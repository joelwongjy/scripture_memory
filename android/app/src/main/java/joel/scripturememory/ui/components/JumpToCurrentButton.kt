package joel.scripturememory.ui.components

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.animateDpAsState
import androidx.compose.animation.fadeOut
import androidx.compose.animation.shrinkHorizontally
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.defaultMinSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
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
import joel.scripturememory.R
import joel.scripturememory.ui.theme.AppLayout
import joel.scripturememory.ui.theme.AppMotion
import joel.scripturememory.ui.theme.AppTheme
import joel.scripturememory.ui.theme.AppType
import kotlinx.coroutines.delay

private const val expandedMillis = 1000L
private val Capsule = RoundedCornerShape(percent = 50)

@Composable
fun JumpToCurrentButton(
    modifier: Modifier = Modifier,
    startExpanded: Boolean = true,
    onExpandedShown: () -> Unit = {},
    action: () -> Unit,
) {
    val colors = AppTheme.colors
    var expanded by remember { mutableStateOf(startExpanded) }
    val horizontal by animateDpAsState(if (expanded) 14.dp else 0.dp, AppMotion.movement(), label = "jumpHorizontal")
    val vertical by animateDpAsState(if (expanded) 10.dp else 0.dp, AppMotion.movement(), label = "jumpVertical")
    val minimum by animateDpAsState(if (expanded) 0.dp else AppLayout.minTapTarget, AppMotion.movement(), label = "jumpMinimum")
    val iconSize by animateDpAsState(if (expanded) 14.dp else 18.dp, AppMotion.movement(), label = "jumpIcon")

    LaunchedEffect(Unit) {
        if (!expanded) return@LaunchedEffect
        onExpandedShown()
        delay(expandedMillis)
        expanded = false
    }

    Row(
        modifier
            .semantics { contentDescription = "Jump to current verse" }
            .pressable(onClick = action)
            .softShadow(Capsule, 6.dp)
            .clip(Capsule)
            .background(colors.accent)
            .defaultMinSize(minimum, minimum)
            .padding(horizontal = horizontal, vertical = vertical),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.Center,
    ) {
        Icon(R.drawable.ic_bookmark_fill, size = iconSize, tint = colors.onAccent)
        AnimatedVisibility(
            visible = expanded,
            enter = androidx.compose.animation.EnterTransition.None,
            exit = fadeOut(AppMotion.movement()) + shrinkHorizontally(AppMotion.movement()),
        ) {
            Text(
                "Jump to current verse",
                Modifier.padding(start = 6.dp),
                style = AppType.footnote.copy(fontWeight = FontWeight.SemiBold),
                color = colors.onAccent,
                maxLines = 1,
            )
        }
    }
}
