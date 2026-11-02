package joel.scripturememory.ui.onboarding

import androidx.compose.animation.Crossfade
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.asPaddingValues
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import joel.scripturememory.model.AnalyticsEvent
import joel.scripturememory.model.AnalyticsScreen
import joel.scripturememory.model.BibleVersion
import joel.scripturememory.model.Catalogue
import joel.scripturememory.model.LearningStore
import joel.scripturememory.model.OnboardingStart
import joel.scripturememory.model.PackPreferencesStore
import joel.scripturememory.system.Analytics
import joel.scripturememory.ui.components.DismissOnBack
import joel.scripturememory.ui.components.LocalBottomBarPadding
import joel.scripturememory.ui.components.Navigator
import joel.scripturememory.ui.components.StackHost
import joel.scripturememory.ui.components.TrackScreen
import joel.scripturememory.ui.theme.AppMotion

@Composable
fun LearningSetupScreen(isOnboarding: Boolean, showsWelcome: Boolean, onComplete: () -> Unit) {
    val learning = LearningStore.shared
    val version = BibleVersion.saved()
    val packs = PackPreferencesStore.shared.visible(version.packs)
    val ordered = Catalogue.verses(packs)
    val navigator = remember { Navigator() }
    var showWelcome by rememberSaveable { mutableStateOf(isOnboarding && showsWelcome) }
    val navBar = WindowInsets.navigationBars.asPaddingValues().calculateBottomPadding()

    DismissOnBack(enabled = !isOnboarding, onBack = onComplete)

    CompositionLocalProvider(LocalBottomBarPadding provides navBar) {
        Crossfade(showWelcome, animationSpec = AppMotion.content(), label = "learningSetup") { welcome ->
            if (welcome) {
                WelcomeScreen { showWelcome = false }
            } else {
                TrackScreen(if (isOnboarding) AnalyticsScreen.onboarding else AnalyticsScreen.currentVersePicker)
                StackHost(navigator) {
                    StartingPointScreen(
                        packs = packs,
                        ordered = ordered,
                        isOnboarding = isOnboarding,
                        currentKey = learning.current(ordered)?.verse?.srsKey,
                        onPick = { verse ->
                            learning.setProgress(verse, ordered)
                            if (isOnboarding) {
                                val start = if (verse.srsKey == ordered.firstOrNull()?.srsKey) {
                                    OnboardingStart.beginning
                                } else {
                                    OnboardingStart.pickedVerse
                                }
                                Analytics.log(AnalyticsEvent.OnboardingFinished(start, version.rawValue))
                            }
                            onComplete()
                        },
                        onCancel = onComplete,
                    )
                }
            }
        }
    }
}
