package joel.scripturememory.ui.onboarding

import androidx.compose.runtime.Composable
import joel.scripturememory.ui.components.LargeTitleColumn
import joel.scripturememory.ui.components.Text

@Composable
fun LearningSetupScreen(isOnboarding: Boolean, showsWelcome: Boolean, onComplete: () -> Unit) {
    LargeTitleColumn("Setup") { Text("Setup") }
}
