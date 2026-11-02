package joel.scripturememory.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.asPaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveableStateHolder
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import joel.scripturememory.R
import joel.scripturememory.ui.components.CoverHost
import joel.scripturememory.ui.components.Covers
import joel.scripturememory.ui.components.LocalBottomBarPadding
import joel.scripturememory.ui.components.LocalCovers
import joel.scripturememory.ui.components.Navigator
import joel.scripturememory.ui.components.StackHost
import joel.scripturememory.ui.components.TabBar
import joel.scripturememory.ui.components.TabBarHeight
import joel.scripturememory.ui.components.TabItem
import joel.scripturememory.ui.theme.AppTheme
import joel.scripturememory.ui.home.HomeScreen
import joel.scripturememory.ui.packs.PackListScreen
import joel.scripturememory.ui.quiz.TestSetupScreen
import joel.scripturememory.ui.search.VerseSearchScreen
import joel.scripturememory.ui.settings.SettingsScreen

private val tabs = listOf(
    TabItem("Home", R.drawable.ic_house, R.drawable.ic_house_fill),
    TabItem("Packs", R.drawable.ic_cards, R.drawable.ic_cards_fill),
    TabItem("Quiz", R.drawable.ic_check_circle, R.drawable.ic_check_circle_fill),
    TabItem("Settings", R.drawable.ic_gear, R.drawable.ic_gear_fill),
    TabItem("Search", R.drawable.ic_magnifying_glass, R.drawable.ic_magnifying_glass_bold),
)

@Composable
fun AppRoot() {
    val covers = remember { Covers() }
    val navigators = remember { List(tabs.size) { Navigator() } }
    var selected by androidx.compose.runtime.saveable.rememberSaveable { mutableIntStateOf(0) }
    val holder = rememberSaveableStateHolder()
    val navBar = WindowInsets.navigationBars.asPaddingValues().calculateBottomPadding()

    CompositionLocalProvider(
        LocalCovers provides covers,
        LocalBottomBarPadding provides TabBarHeight + navBar,
    ) {
        Box(Modifier.fillMaxSize().background(AppTheme.colors.background)) {
            holder.SaveableStateProvider(selected) {
                StackHost(navigators[selected]) { TabRoot(selected) }
            }
            TabBar(tabs, selected, onSelect = { selected = it }, modifier = Modifier.align(Alignment.BottomCenter))
            CoverHost(covers)
        }
    }
}

@Composable
private fun TabRoot(index: Int) {
    when (index) {
        0 -> HomeScreen()
        1 -> PackListScreen()
        2 -> TestSetupScreen()
        3 -> SettingsScreen()
        else -> VerseSearchScreen()
    }
}
