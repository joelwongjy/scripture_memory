package joel.scripturememory.ui.components

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.widthIn
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import joel.scripturememory.ui.theme.AppTheme
import joel.scripturememory.ui.theme.AppType

@Composable
fun ContentUnavailable(icon: Int, title: String, description: String, modifier: Modifier = Modifier) {
    val colors = AppTheme.colors
    Column(
        modifier
            .widthIn(max = 340.dp)
            .padding(horizontal = 32.dp)
            .semantics(mergeDescendants = true) {},
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        Icon(icon, Modifier.padding(bottom = 8.dp), size = 46.dp, tint = colors.secondaryLabel)
        Text(title, style = AppType.title3, color = colors.label, textAlign = TextAlign.Center)
        Text(description, style = AppType.subheadline, color = colors.secondaryLabel, textAlign = TextAlign.Center)
    }
}
