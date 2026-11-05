package joel.scripturememory

import android.content.Intent
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import joel.scripturememory.model.PastedVerse
import joel.scripturememory.model.UserPackStore
import joel.scripturememory.ui.packs.ShareVerseSheet
import joel.scripturememory.ui.theme.AppTheme

class ShareVerseActivity : ComponentActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        val pasted = PastedVerse.parse(sharedText(intent))
        setContent {
            AppTheme {
                ShareVerseSheet(
                    pasted = pasted,
                    packs = UserPackStore.shared.userPacks,
                    onAdd = UserPackStore.shared::addShared,
                    onDismiss = ::finish,
                )
            }
        }
    }

    private fun sharedText(intent: Intent): String {
        val text = intent.getCharSequenceExtra(Intent.EXTRA_TEXT)?.toString().orEmpty()
        val subject = intent.getStringExtra(Intent.EXTRA_SUBJECT).orEmpty()
        val parts = buildList {
            if (subject.isNotBlank() && subject.trim() !in text) add(subject)
            if (text.isNotBlank()) add(text)
        }
        return parts.joinToString("\n")
    }
}
