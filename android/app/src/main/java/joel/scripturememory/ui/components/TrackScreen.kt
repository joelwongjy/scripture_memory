package joel.scripturememory.ui.components

import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import joel.scripturememory.model.AnalyticsEvent
import joel.scripturememory.model.AnalyticsScreen
import joel.scripturememory.system.Analytics

@Composable
fun TrackScreen(screen: AnalyticsScreen) {
    LaunchedEffect(Unit) { Analytics.log(AnalyticsEvent.ScreenViewed(screen)) }
}
