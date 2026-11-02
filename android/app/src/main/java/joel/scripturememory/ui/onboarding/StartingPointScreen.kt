package joel.scripturememory.ui.onboarding

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import joel.scripturememory.R
import joel.scripturememory.model.Pack
import joel.scripturememory.model.Verse
import joel.scripturememory.system.HapticEngine
import joel.scripturememory.ui.components.BottomActionBar
import joel.scripturememory.ui.components.ChromeTextButton
import joel.scripturememory.ui.components.GroupedSection
import joel.scripturememory.ui.components.Icon
import joel.scripturememory.ui.components.InlineScreen
import joel.scripturememory.ui.components.ListRow
import joel.scripturememory.ui.components.PackVersePicker
import joel.scripturememory.ui.components.PrimaryButton
import joel.scripturememory.ui.components.SelectionCheckmark
import joel.scripturememory.ui.components.readableColumn
import joel.scripturememory.ui.theme.AppLayout
import joel.scripturememory.ui.theme.AppTheme

@Composable
fun StartingPointScreen(
    packs: List<Pack>,
    ordered: List<Verse>,
    isOnboarding: Boolean,
    currentKey: String?,
    onPick: (Verse) -> Unit,
    onCancel: () -> Unit,
) {
    val colors = AppTheme.colors
    var pendingKey by rememberSaveable { mutableStateOf(currentKey) }
    val pending = ordered.firstOrNull { it.srsKey == pendingKey }
    val first = ordered.firstOrNull()

    InlineScreen(
        title = if (isOnboarding) "Your Starting Point" else "Current Verse",
        leading = if (isOnboarding) null else ({ ChromeTextButton("Cancel", onClick = onCancel) }),
        bottomBar = {
            Box(Modifier.background(colors.chrome).navigationBarsPadding()) {
                BottomActionBar {
                    PrimaryButton(
                        "Confirm",
                        Modifier.readableColumn(),
                        enabled = pending != null,
                    ) {
                        if (pending != null) {
                            HapticEngine.light()
                            onPick(pending)
                        }
                    }
                }
            }
        },
    ) {
        LazyColumn(
            contentPadding = PaddingValues(all = AppLayout.screenMargin),
            verticalArrangement = Arrangement.spacedBy(24.dp),
        ) {
            item(key = "beginning") {
                Column(Modifier.readableColumn()) {
                    GroupedSection {
                        ListRow(
                            "Start from the beginning",
                            leading = { Icon(R.drawable.ic_flag_fill, size = 20.dp, tint = colors.label) },
                            trailing = { if (first != null && pending?.srsKey == first.srsKey) SelectionCheckmark() },
                            onClick = {
                                if (first != null) {
                                    pendingKey = first.srsKey
                                    HapticEngine.light()
                                }
                            },
                        )
                    }
                }
            }
            item(key = "packs") {
                Column(Modifier.readableColumn()) {
                    PackVersePicker(
                        packs = packs,
                        selectedKey = if (pending?.srsKey == first?.srsKey) null else pending?.srsKey,
                        header = "Pick where you stopped",
                    ) { pendingKey = it.srsKey }
                }
            }
        }
    }
}
