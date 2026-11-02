package joel.scripturememory.ui.study

import android.text.InputType
import android.view.inputmethod.EditorInfo
import android.view.inputmethod.InputConnection
import androidx.compose.runtime.Composable
import androidx.compose.ui.ExperimentalComposeUiApi
import androidx.compose.ui.platform.InterceptPlatformTextInput
import androidx.compose.ui.platform.PlatformTextInputMethodRequest

enum class StudyInputKind { Recall, Prose }

@OptIn(ExperimentalComposeUiApi::class)
@Composable
fun StudyInputMethod(kind: StudyInputKind, content: @Composable () -> Unit) {
    InterceptPlatformTextInput(
        interceptor = { request, next ->
            next.startInputMethod(
                object : PlatformTextInputMethodRequest {
                    override fun createInputConnection(outAttributes: EditorInfo): InputConnection {
                        val connection = request.createInputConnection(outAttributes)
                        outAttributes.inputType = when (kind) {
                            StudyInputKind.Recall ->
                                InputType.TYPE_CLASS_TEXT or
                                    InputType.TYPE_TEXT_VARIATION_VISIBLE_PASSWORD or
                                    InputType.TYPE_TEXT_FLAG_NO_SUGGESTIONS
                            StudyInputKind.Prose ->
                                (outAttributes.inputType and InputType.TYPE_TEXT_FLAG_AUTO_CORRECT.inv()) or
                                    InputType.TYPE_TEXT_FLAG_NO_SUGGESTIONS
                        }
                        outAttributes.imeOptions = outAttributes.imeOptions or
                            EditorInfo.IME_FLAG_NO_EXTRACT_UI or
                            EditorInfo.IME_FLAG_NO_FULLSCREEN
                        return connection
                    }
                },
            )
        },
        content = content,
    )
}
