package joel.scripturememory.ui.components

import androidx.compose.animation.animateColorAsState
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import joel.scripturememory.ui.theme.AppMotion
import joel.scripturememory.ui.theme.AppTheme
import joel.scripturememory.ui.theme.AppType

data class TabItem(val title: String, val icon: Int, val selectedIcon: Int)

val TabBarHeight = 58.dp

@Composable
fun TabBar(tabs: List<TabItem>, selected: Int, onSelect: (Int) -> Unit, modifier: Modifier = Modifier) {
    val colors = AppTheme.colors
    Column(modifier.fillMaxWidth().background(colors.chrome)) {
        Divider()
        Row(
            Modifier
                .fillMaxWidth()
                .navigationBarsPadding()
                .height(TabBarHeight)
                .padding(horizontal = 4.dp),
            horizontalArrangement = Arrangement.SpaceEvenly,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            tabs.forEachIndexed { index, tab ->
                val isSelected = index == selected
                val tint by animateColorAsState(
                    if (isSelected) colors.accent else colors.secondaryLabel,
                    AppMotion.control(),
                    label = "tabTint",
                )
                Column(
                    Modifier
                        .weight(1f)
                        .semantics {
                            this.selected = isSelected
                            role = Role.Tab
                        }
                        .pressable(pressedScale = 0.92f) { onSelect(index) }
                        .padding(vertical = 6.dp),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(3.dp),
                ) {
                    Icon(if (isSelected) tab.selectedIcon else tab.icon, size = 24.dp, tint = tint)
                    Text(tab.title, style = AppType.caption2, color = tint, maxLines = 1)
                }
            }
        }
    }
}
