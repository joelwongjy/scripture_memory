package joel.scripturememory.ui.study

import androidx.compose.runtime.Composable
import joel.scripturememory.model.TestSession
import joel.scripturememory.ui.components.LargeTitleColumn
import joel.scripturememory.ui.components.Text

@Composable
fun TestSessionScreen(session: TestSession, onSessionEnded: () -> Unit) {
    LargeTitleColumn("Practice") { Text("Practice") }
}
