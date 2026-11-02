package joel.scripturememory.ui.study

import androidx.compose.runtime.Composable
import joel.scripturememory.model.TestSession
import joel.scripturememory.ui.components.LargeTitleColumn
import joel.scripturememory.ui.components.Text

@Composable
fun DailyReviewScreen(session: TestSession, onFinished: () -> Unit) {
    LargeTitleColumn("Review") { Text("Review") }
}
