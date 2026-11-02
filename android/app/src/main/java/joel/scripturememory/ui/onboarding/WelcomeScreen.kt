package joel.scripturememory.ui.onboarding

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import joel.scripturememory.R
import joel.scripturememory.ui.components.Icon
import joel.scripturememory.ui.components.PrimaryButton
import joel.scripturememory.ui.components.Text
import joel.scripturememory.ui.components.readableColumn
import joel.scripturememory.ui.theme.AppLayout
import joel.scripturememory.ui.theme.AppTheme
import joel.scripturememory.ui.theme.AppType

private val columnWidth = 520.dp

@Composable
fun WelcomeScreen(onContinue: () -> Unit) {
    val colors = AppTheme.colors
    Column(Modifier.fillMaxSize().background(colors.background).statusBarsPadding().navigationBarsPadding()) {
        BoxWithConstraints(Modifier.weight(1f).fillMaxWidth()) {
            val viewport = maxHeight
            Box(Modifier.fillMaxSize().verticalScroll(rememberScrollState())) {
                Column(
                    Modifier.readableColumn(columnWidth).heightIn(min = viewport),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.Center,
                ) {
                    Icon(
                        R.drawable.ic_book_fill,
                        Modifier.padding(top = 24.dp, bottom = 22.dp),
                        size = 68.dp,
                        tint = colors.accent,
                    )
                    Text(
                        "Welcome to\nScripture Memory",
                        Modifier
                            .padding(horizontal = 24.dp)
                            .padding(bottom = 44.dp)
                            .semantics { heading() },
                        style = AppType.largeTitle,
                        color = colors.label,
                        textAlign = TextAlign.Center,
                    )
                    Column(
                        Modifier.padding(horizontal = 30.dp).padding(bottom = 24.dp),
                        verticalArrangement = Arrangement.spacedBy(30.dp),
                    ) {
                        FeatureRow(
                            R.drawable.ic_book_open_fill,
                            "Memorize Scripture",
                            "Learn verses one at a time, in order, at your own pace.",
                            colors.accent,
                        )
                        FeatureRow(
                            R.drawable.ic_fire_fill,
                            "Build a daily streak",
                            "A verse a day keeps your momentum going.",
                            colors.orange,
                        )
                        FeatureRow(
                            R.drawable.ic_arrows_clockwise,
                            "Reviews that stick",
                            "Spaced repetition brings verses back right before you'd forget.",
                            colors.green,
                        )
                    }
                }
            }
        }
        Box(
            Modifier
                .readableColumn(columnWidth)
                .padding(horizontal = AppLayout.screenMargin)
                .padding(top = 12.dp, bottom = 8.dp),
        ) {
            PrimaryButton("Continue", onClick = onContinue)
        }
    }
}

@Composable
private fun FeatureRow(icon: Int, title: String, subtitle: String, tint: Color) {
    val colors = AppTheme.colors
    Row(
        Modifier.fillMaxWidth().semantics(mergeDescendants = true) {},
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        Box(Modifier.width(42.dp), contentAlignment = Alignment.Center) {
            Icon(icon, size = 36.dp, tint = tint)
        }
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(title, style = AppType.headline, color = colors.label)
            Text(subtitle, style = AppType.subheadline, color = colors.secondaryLabel)
        }
    }
}
