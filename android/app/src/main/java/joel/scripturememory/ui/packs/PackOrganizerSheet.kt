package joel.scripturememory.ui.packs

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import joel.scripturememory.R
import joel.scripturememory.model.AnalyticsEvent
import joel.scripturememory.model.AnalyticsScreen
import joel.scripturememory.model.Pack
import joel.scripturememory.model.PackPreferencesStore
import joel.scripturememory.system.Analytics
import joel.scripturememory.system.HapticEngine
import joel.scripturememory.ui.components.AlertAction
import joel.scripturememory.ui.components.AppAlert
import joel.scripturememory.ui.components.AppSheet
import joel.scripturememory.ui.components.Icon
import joel.scripturememory.ui.components.PackRowLabel
import joel.scripturememory.ui.components.ReorderGrip
import joel.scripturememory.ui.components.ReorderHandle
import joel.scripturememory.ui.components.ReorderableRows
import joel.scripturememory.ui.components.SheetHeader
import joel.scripturememory.ui.components.Text
import joel.scripturememory.ui.components.TextButton
import joel.scripturememory.ui.components.TrackScreen
import joel.scripturememory.ui.components.dimOnPress
import joel.scripturememory.ui.components.rememberRowReorder
import joel.scripturememory.ui.components.reorderViewport
import joel.scripturememory.ui.theme.AppLayout
import joel.scripturememory.ui.theme.AppTheme
import joel.scripturememory.ui.theme.AppType

@Composable
fun PackOrganizerSheet(allPacks: List<Pack>, onDismiss: () -> Unit) {
    val store = PackPreferencesStore.shared
    val colors = AppTheme.colors
    var showResetConfirm by remember { mutableStateOf(false) }
    val scroll = rememberScrollState()
    val reorder = rememberRowReorder(scroll)

    TrackScreen(AnalyticsScreen.organizePacks)

    val arranged = store.arranged(allPacks)
    val current by rememberUpdatedState(arranged)

    AppSheet(onDismiss = onDismiss, fullHeight = true) { sheet ->
        SheetHeader(
            "Edit Packs",
            leading = {
                TextButton(
                    "Reset",
                    enabled = store.hasCustomization,
                    style = AppType.body,
                    onClick = { showResetConfirm = true },
                )
            },
            trailing = {
                TextButton(
                    "Done",
                    style = AppType.body.copy(fontWeight = FontWeight.SemiBold),
                    onClick = sheet.dismiss,
                )
            },
        )
        Column(
            Modifier
                .weight(1f)
                .fillMaxWidth()
                .reorderViewport(reorder)
                .verticalScroll(scroll, enabled = !reorder.isDragging)
                .padding(horizontal = AppLayout.screenMargin)
                .padding(bottom = 24.dp),
        ) {
            Text(
                "Drag to reorder. Hidden packs don't appear in Packs, Daily Review, Quiz or Search.",
                Modifier.padding(horizontal = AppLayout.panelPadding, vertical = 8.dp),
                style = AppType.footnote,
                color = colors.secondaryLabel,
            )
            ReorderableRows(
                keys = arranged.map { it.name },
                reorder = reorder,
                onMove = { from, to ->
                    store.move(current, setOf(from), to)
                    Analytics.log(AnalyticsEvent.PacksReordered)
                },
            ) { row, handle ->
                val pack = arranged[row]
                OrganizerRow(
                    pack = pack,
                    isHidden = store.isHidden(pack.name),
                    handle = handle,
                    onToggle = {
                        val hidden = store.isHidden(pack.name)
                        store.setHidden(pack.name, !hidden)
                        Analytics.log(AnalyticsEvent.PackVisibilityChanged(!hidden))
                        HapticEngine.light()
                    },
                )
            }
        }
    }

    if (showResetConfirm) {
        AppAlert(
            title = "Reset Pack Order?",
            message = "Restores the original order and shows all packs.",
            actions = listOf(
                AlertAction("Cancel", isCancel = true),
                AlertAction("Reset", isDestructive = true) {
                    store.reset()
                    HapticEngine.light()
                },
            ),
            onDismiss = { showResetConfirm = false },
        )
    }
}

@Composable
private fun OrganizerRow(
    pack: Pack,
    isHidden: Boolean,
    handle: ReorderHandle,
    onToggle: () -> Unit,
) {
    val colors = AppTheme.colors
    Row(
        Modifier
            .fillMaxWidth()
            .alpha(if (isHidden) 0.45f else 1f)
            .padding(start = AppLayout.panelPadding, end = 6.dp, top = 8.dp, bottom = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        PackRowLabel(pack, Modifier.weight(1f).alpha(if (isHidden) 0.5f else 1f))
        Box(
            Modifier
                .size(width = 44.dp, height = 30.dp)
                .semantics { contentDescription = if (isHidden) "Show ${pack.name}" else "Hide ${pack.name}" }
                .dimOnPress(onClick = onToggle),
            contentAlignment = Alignment.Center,
        ) {
            Icon(
                if (isHidden) R.drawable.ic_eye_slash else R.drawable.ic_eye,
                size = 20.dp,
                tint = if (isHidden) colors.secondaryLabel else colors.accent,
            )
        }
        ReorderGrip(handle)
    }
}
