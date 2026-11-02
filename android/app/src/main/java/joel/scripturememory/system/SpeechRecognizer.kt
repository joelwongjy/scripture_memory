package joel.scripturememory.system

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.platform.LocalContext
import androidx.core.content.ContextCompat
import android.speech.SpeechRecognizer as PlatformRecognizer

private val contextualStrings = arrayListOf(
    "Lord", "God", "Jesus", "Christ", "Holy Spirit",
    "Scripture", "righteousness", "salvation", "eternal",
    "crucified", "resurrection", "sanctify", "justified",
    "commandments", "covenant", "redemption", "forgiveness",
    "Corinthians", "Galatians", "Ephesians", "Philippians",
    "Colossians", "Thessalonians", "Deuteronomy", "Leviticus",
    "Lamentations", "Habakkuk", "Ecclesiastes", "Proverbs",
    "Isaiah", "Jeremiah", "Hebrews", "Revelation", "Psalm",
    "apostles", "disciples", "Gentiles", "Pharisees",
    "temptation", "transgression", "iniquity", "unrighteousness",
)

class SpeechRecognizer internal constructor(private val context: Context) {
    var transcript by mutableStateOf("")
        private set
    var isListening by mutableStateOf(false)
        private set
    var errorMessage by mutableStateOf<String?>(null)

    internal var askForMicrophone: () -> Unit = {}

    private var recognizer: PlatformRecognizer? = null
    private var earlier = ""

    private val hasMicrophone: Boolean
        get() = ContextCompat.checkSelfPermission(context, Manifest.permission.RECORD_AUDIO) ==
            PackageManager.PERMISSION_GRANTED

    fun startListening() {
        if (isListening) return
        errorMessage = null
        if (!PlatformRecognizer.isRecognitionAvailable(context)) {
            errorMessage = "Speech recognition isn't available right now. Check your connection and try again."
            return
        }
        if (hasMicrophone) beginRecognition() else askForMicrophone()
    }

    fun stopListening() {
        recognizer?.cancel()
        isListening = false
    }

    internal fun microphoneAnswered(granted: Boolean) {
        if (granted) {
            beginRecognition()
        } else {
            errorMessage = "Microphone access was denied. Enable it in Settings › Apps › Scripture Memory › Permissions."
        }
    }

    internal fun destroy() {
        recognizer?.destroy()
        recognizer = null
        isListening = false
    }

    private fun beginRecognition() {
        val session = recognizer ?: PlatformRecognizer.createSpeechRecognizer(context).also {
            it.setRecognitionListener(listener)
            recognizer = it
        }
        earlier = ""
        transcript = ""
        isListening = true
        session.startListening(request())
    }

    private fun request(): Intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
        putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
        putExtra(RecognizerIntent.EXTRA_LANGUAGE, "en-US")
        putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
        putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 1)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            putStringArrayListExtra(RecognizerIntent.EXTRA_BIASING_STRINGS, contextualStrings)
        }
    }

    private fun show(results: Bundle?) {
        val heard = results?.getStringArrayList(PlatformRecognizer.RESULTS_RECOGNITION)?.firstOrNull().orEmpty()
        if (heard.isEmpty()) return
        transcript = if (earlier.isEmpty()) heard else "$earlier $heard"
    }

    private val listener = object : RecognitionListener {
        override fun onReadyForSpeech(params: Bundle?) {}
        override fun onBeginningOfSpeech() {}
        override fun onRmsChanged(rmsdB: Float) {}
        override fun onBufferReceived(buffer: ByteArray?) {}
        override fun onEndOfSpeech() {}
        override fun onEvent(eventType: Int, params: Bundle?) {}

        override fun onPartialResults(partialResults: Bundle?) {
            if (isListening) show(partialResults)
        }

        override fun onResults(results: Bundle?) {
            if (!isListening) return
            show(results)
            earlier = transcript
            recognizer?.startListening(request())
        }

        override fun onError(error: Int) {
            if (!isListening) return
            when {
                error == PlatformRecognizer.ERROR_RECOGNIZER_BUSY ||
                    error == PlatformRecognizer.ERROR_AUDIO ->
                    errorMessage = "Couldn't start the microphone. Another app may be using it."
                transcript.isEmpty() ->
                    errorMessage = "Dictation didn't pick up any audio. Check your microphone and try again."
            }
            stopListening()
        }
    }
}

@Composable
fun rememberSpeechRecognizer(): SpeechRecognizer {
    val context = LocalContext.current
    val speech = remember { SpeechRecognizer(context.applicationContext) }
    val microphone = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
        speech.microphoneAnswered(granted)
    }
    DisposableEffect(speech) {
        speech.askForMicrophone = { microphone.launch(Manifest.permission.RECORD_AUDIO) }
        onDispose { speech.destroy() }
    }
    return speech
}
