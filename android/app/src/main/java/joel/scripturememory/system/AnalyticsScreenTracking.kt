package joel.scripturememory.system

import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.ui.Modifier
import joel.scripturememory.model.AnalyticsEvent
import joel.scripturememory.model.AnalyticsScreen

@Composable
fun Modifier.analyticsScreen(screen: AnalyticsScreen): Modifier {
    LaunchedEffect(screen) { Analytics.log(AnalyticsEvent.ScreenViewed(screen)) }
    return this
}
