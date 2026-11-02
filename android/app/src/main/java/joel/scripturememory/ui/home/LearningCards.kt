package joel.scripturememory.ui.home

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.defaultMinSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.widthIn
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.unit.dp
import joel.scripturememory.R
import joel.scripturememory.model.HomeVerseStartMode
import joel.scripturememory.model.LearningStore
import joel.scripturememory.model.Pack
import joel.scripturememory.model.PackListLayout
import joel.scripturememory.model.Verse
import joel.scripturememory.system.HapticEngine
import joel.scripturememory.ui.components.AppMenu
import joel.scripturememory.ui.components.Icon
import joel.scripturememory.ui.components.MenuAction
import joel.scripturememory.ui.components.PaperShape
import joel.scripturememory.ui.components.RowChevron
import joel.scripturememory.ui.components.Text
import joel.scripturememory.ui.components.dimOnPress
import joel.scripturememory.ui.components.groupedPanel
import joel.scripturememory.ui.components.pressable
import joel.scripturememory.ui.components.softShadow
import joel.scripturememory.ui.theme.AppLayout
import joel.scripturememory.ui.theme.AppMotion
import joel.scripturememory.ui.theme.AppTheme
import joel.scripturememory.ui.theme.AppType
import joel.scripturememory.ui.theme.sizeInDp

data class LearningSpot(
    val verse: Verse,
    val pack: Pack,
    val indexInPack: Int,
    val isPinned: Boolean,
)

@OptIn(ExperimentalFoundationApi::class)
@Composable
fun ContinueLearningCard(
    spot: LearningSpot,
    startMode: HomeVerseStartMode,
    modifier: Modifier = Modifier,
    onOpen: () -> Unit,
    onChangePin: () -> Unit,
    onUnpin: () -> Unit,
) {
    val colors = AppTheme.colors
    val verse = spot.verse
    val learning = LearningStore.shared
    var showsMenu by remember { mutableStateOf(false) }
    val source = remember { MutableInteractionSource() }
    val pressed by source.collectIsPressedAsState()
    val scale by animateFloatAsState(if (pressed) 0.97f else 1f, AppMotion.control(), label = "cardPress")
    val label = "${startMode.ctaLabel} ${verse.book} ${verse.reference}"

    Column(
        modifier.widthIn(max = PackListLayout.focalCardWidth(AppType.body.sizeInDp()).dp).fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        BoxWithConstraints(Modifier.fillMaxWidth()) {
            val heading = if (spot.isPinned) "Pinned" else "Continue Learning"
            val position = "${spot.indexInPack + 1} of ${spot.pack.verses.size}"
            val measurer = rememberTextMeasurer()
            val density = LocalDensity.current
            fun width(text: String, style: TextStyle) =
                with(density) { measurer.measure(text, style, maxLines = 1).size.width.toDp() }
            val taken = width(heading, AppType.title3.copy(fontWeight = FontWeight.Bold)) +
                width(position, AppType.subheadline) +
                maxOf(width("Change", AppType.callout), 44.dp) +
                (if (spot.isPinned) 24.dp else 0.dp) + 12.dp
            val showsPosition = maxWidth - 40.dp >= taken
            Row(
                Modifier.fillMaxWidth().padding(horizontal = 20.dp),
                horizontalArrangement = Arrangement.spacedBy(6.dp),
            ) {
                if (spot.isPinned) {
                    Icon(
                        R.drawable.ic_push_pin_fill,
                        Modifier.align(Alignment.CenterVertically),
                        size = 18.dp,
                        tint = colors.label,
                    )
                }
                Text(
                    heading,
                    Modifier.weight(1f).alignByBaseline().semantics { heading() },
                    style = AppType.title3.copy(fontWeight = FontWeight.Bold),
                    color = colors.label,
                    maxLines = 2,
                )
                if (showsPosition) {
                    Text(
                        position,
                        Modifier.alignByBaseline(),
                        style = AppType.subheadline,
                        color = colors.secondaryLabel,
                        maxLines = 1,
                    )
                }
                val pinLabel = if (spot.isPinned) "Change pinned verse" else "Pin a verse"
                Box(
                    Modifier
                        .alignByBaseline()
                        .verticalOverhang(12.dp)
                        .semantics { contentDescription = pinLabel }
                        .dimOnPress(onClick = onChangePin)
                        .defaultMinSize(minWidth = 44.dp)
                        .padding(vertical = 12.dp),
                    contentAlignment = Alignment.CenterEnd,
                ) {
                    Text(
                        if (spot.isPinned) "Change" else "Pin",
                        style = AppType.callout,
                        color = colors.accent,
                        maxLines = 1,
                    )
                }
            }
        }

        BoxWithConstraints(
            Modifier
                .fillMaxWidth()
                .aspectRatio(AppLayout.cardAspect)
                .graphicsLayer {
                    scaleX = scale
                    scaleY = scale
                }
                .softShadow(PaperShape, 8.dp)
                .semantics { contentDescription = label }
                .combinedClickable(
                    interactionSource = source,
                    indication = null,
                    onLongClickLabel = if (spot.isPinned) "Change verse" else "Pin a verse",
                    onLongClick = {
                        HapticEngine.medium()
                        showsMenu = true
                    },
                    onClick = onOpen,
                ),
        ) {
            HomeVerseCard(verse, learning.isLearnt(verse), maxWidth, startMode.ctaLabel)
            if (showsMenu) {
                AppMenu(
                    actions = if (spot.isPinned) {
                        listOf(
                            MenuAction("Change verse", R.drawable.ic_push_pin, onClick = onChangePin),
                            MenuAction("Unpin verse", R.drawable.ic_push_pin_slash) {
                                onUnpin()
                                HapticEngine.light()
                            },
                        )
                    } else {
                        listOf(MenuAction("Pin a verse", R.drawable.ic_push_pin, onClick = onChangePin))
                    },
                    onDismiss = { showsMenu = false },
                )
            }
        }
    }
}

@Composable
fun GoToCurrentVerseCard(verse: Verse, modifier: Modifier = Modifier, onOpen: () -> Unit) {
    val colors = AppTheme.colors
    val reference = "${verse.book} ${verse.reference}"
    Row(
        modifier
            .fillMaxWidth()
            .widthIn(max = 600.dp)
            .semantics(mergeDescendants = true) { contentDescription = "Go to current verse, $reference" }
            .pressable {
                onOpen()
                HapticEngine.light()
            }
            .groupedPanel()
            .padding(horizontal = AppLayout.panelPadding, vertical = AppLayout.panelRowPadding),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Icon(R.drawable.ic_arrow_elbow_down_right, size = 18.dp, tint = colors.accent)
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(
                "Go to current verse",
                style = AppType.callout.copy(fontWeight = FontWeight.SemiBold),
                color = colors.label,
            )
            Text(reference, style = AppType.footnote, color = colors.secondaryLabel)
        }
        RowChevron()
    }
}

@Composable
fun AllLearntCard(modifier: Modifier = Modifier) {
    val colors = AppTheme.colors
    Row(
        modifier
            .fillMaxWidth()
            .semantics(mergeDescendants = true) {}
            .groupedPanel()
            .padding(AppLayout.cardPadding),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Icon(R.drawable.ic_seal_check_fill, size = 28.dp, tint = colors.green)
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text("Every verse learnt", style = AppType.headline, color = colors.label)
            Text("Keep them sharp in Daily Review below.", style = AppType.footnote, color = colors.secondaryLabel)
        }
    }
}
