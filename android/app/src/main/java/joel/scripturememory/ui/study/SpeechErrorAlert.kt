package joel.scripturememory.ui.study

import androidx.compose.runtime.Composable
import joel.scripturememory.system.SpeechRecognizer
import joel.scripturememory.ui.components.AlertAction
import joel.scripturememory.ui.components.AppAlert

@Composable
fun SpeechErrorAlert(speech: SpeechRecognizer, onDismissed: () -> Unit = {}) {
    val message = speech.errorMessage ?: return
    AppAlert(
        title = "Dictation Unavailable",
        message = message,
        actions = listOf(AlertAction("OK", isCancel = true)),
        onDismiss = {
            speech.errorMessage = null
            onDismissed()
        },
    )
}
