package joel.scripturememory

import android.content.Intent
import android.graphics.Color
import android.os.Build
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.SystemBarStyle
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import joel.scripturememory.system.Analytics
import joel.scripturememory.system.DeepLink
import joel.scripturememory.system.OpenedFile
import joel.scripturememory.ui.AppRoot
import joel.scripturememory.ui.theme.AppTheme
import kotlinx.coroutines.channels.Channel

class MainActivity : ComponentActivity() {

    private val deepLinks = Channel<DeepLink>(Channel.BUFFERED)
    private val openedFiles = Channel<OpenedFile>(Channel.BUFFERED)

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        Analytics.start()
        if (savedInstanceState == null) receive(intent)
        setContent {
            AppTheme {
                SystemBars()
                AppRoot(deepLinks, openedFiles)
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        receive(intent)
    }

    private fun receive(intent: Intent?) {
        if (intent == null || intent.flags and Intent.FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY != 0) return
        DeepLink.from(intent)?.let(deepLinks::trySend)
        OpenedFile.from(this, intent)?.let(openedFiles::trySend)
    }

    @Composable
    private fun SystemBars() {
        val dark = isSystemInDarkTheme()
        DisposableEffect(dark) {
            val style = SystemBarStyle.auto(Color.TRANSPARENT, Color.TRANSPARENT) { dark }
            enableEdgeToEdge(statusBarStyle = style, navigationBarStyle = style)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                window.isNavigationBarContrastEnforced = false
            }
            onDispose {}
        }
    }
}
