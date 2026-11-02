package joel.scripturememory.ui.quiz

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.Orientation
import androidx.compose.foundation.gestures.draggable
import androidx.compose.foundation.gestures.rememberDraggableState
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.IntrinsicSize
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.CustomAccessibilityAction
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.customActions
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import joel.scripturememory.R
import joel.scripturememory.model.Pack
import joel.scripturememory.model.Verse
import joel.scripturememory.ui.components.Divider
import joel.scripturememory.ui.components.Icon
import joel.scripturememory.ui.components.PackRowLabel
import joel.scripturememory.ui.components.RowChevron
import joel.scripturememory.ui.components.SelectionCircle
import joel.scripturememory.ui.components.Text
import joel.scripturememory.ui.components.VerseRowLabel
import joel.scripturememory.ui.components.dimOnPress
import joel.scripturememory.ui.components.pressable
import joel.scripturememory.ui.study.CapsuleShape
import joel.scripturememory.ui.theme.AppLayout
import joel.scripturememory.ui.theme.AppMotion
import joel.scripturememory.ui.theme.AppTheme
import joel.scripturememory.ui.theme.AppType
import kotlinx.coroutines.launch
import kotlin.math.roundToInt

internal val Pack.fieldColor: Color
    get() {
        val hex = color.trim().removePrefix("#")
        val value = hex.takeIf { it.length == 6 }?.toLongOrNull(16) ?: return Color.Gray
        return Color(0xFF000000 or value)
    }

private val Pack.fieldIsLight: Boolean
    get() = fieldColor.let { 0.299f * it.red + 0.587f * it.green + 0.114f * it.blue } > 0.85f

internal val Pack.tint: Color
    get() = if (fieldIsLight) Color(red = 0.72f, green = 0.16f, blue = 0.11f) else fieldColor

internal val Pack.shortName: String
    get() {
        if (name.startsWith("DEP") || name.startsWith("TMS 180")) {
            for (separator in listOf(": ", " · ")) {
                val at = name.indexOf(separator)
                if (at >= 0) return name.substring(at + separator.length)
            }
        }
        return name
    }

@Composable
internal fun SectionHeader(title: String, modifier: Modifier = Modifier) {
    Text(
        title,
        modifier.padding(start = AppLayout.panelPadding, end = AppLayout.panelPadding, top = 20.dp, bottom = 8.dp),
        style = AppType.footnote,
        color = AppTheme.colors.secondaryLabel,
    )
}

@Composable
internal fun PackHeaderRow(
    pack: Pack,
    detail: String,
    allSelected: Boolean,
    someSelected: Boolean,
    isExpanded: Boolean,
    showsDivider: Boolean,
    onToggleSelection: () -> Unit,
    onToggleExpanded: () -> Unit,
) {
    val colors = AppTheme.colors
    val chevron by animateFloatAsState(if (isExpanded) 90f else 0f, AppMotion.content(), label = "chevron")
    Column {
        Row(Modifier.fillMaxWidth().height(IntrinsicSize.Min), verticalAlignment = Alignment.CenterVertically) {
            Box(
                Modifier
                    .padding(start = 4.dp)
                    .size(width = 44.dp, height = 60.dp)
                    .semantics {
                        contentDescription = if (allSelected) {
                            "Deselect all verses in ${pack.name}"
                        } else {
                            "Select all verses in ${pack.name}"
                        }
                    }
                    .pressable(pressedScale = 0.9f, onClick = onToggleSelection),
                contentAlignment = Alignment.Center,
            ) {
                SelectionCircle(allSelected, someSelected && !allSelected, 22.dp, pack.tint)
            }
            PackRowLabel(
                pack = pack,
                title = pack.shortName,
                showsBadge = true,
                detail = detail,
                modifier = Modifier
                    .weight(1f)
                    .semantics {
                        contentDescription = if (isExpanded) {
                            "Collapse ${pack.name}"
                        } else {
                            "Expand ${pack.name} to pick individual verses"
                        }
                    }
                    .pressable(pressedScale = 1f, pressedAlpha = 0.55f, onClick = onToggleExpanded)
                    .padding(vertical = 8.dp),
                trailing = {
                    Box(
                        Modifier
                            .padding(end = 4.dp)
                            .size(44.dp)
                            .graphicsLayer { rotationZ = chevron },
                        contentAlignment = Alignment.Center,
                    ) {
                        RowChevron()
                    }
                },
            )
        }
        if (showsDivider) Divider(Modifier.padding(start = 106.dp, end = AppLayout.panelPadding))
    }
}

@Composable
internal fun VerseSelectRow(
    verse: Verse,
    tint: Color,
    isSelected: Boolean,
    showsDivider: Boolean,
    frames: DragSelectFrames,
    onToggle: () -> Unit,
    onSelectUpTo: () -> Unit,
) {
    val colors = AppTheme.colors
    Column(Modifier.dragSelectRow(verse.id, frames)) {
        Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
            VerseRowLabel(
                verse = verse,
                modifier = Modifier
                    .weight(1f)
                    .semantics(mergeDescendants = true) {
                        contentDescription = "${verse.title}, ${verse.book} ${verse.reference}"
                        stateDescription = if (isSelected) "Selected" else "Not selected"
                        selected = isSelected
                    }
                    .pressable(pressedScale = 1f, pressedAlpha = 0.55f, onClick = onToggle)
                    .padding(start = 40.dp, top = 6.dp, bottom = 6.dp),
                leading = { SelectionCircle(isSelected, size = 20.dp, tint = tint) },
            )
            Box(
                Modifier
                    .padding(end = 8.dp)
                    .size(width = 44.dp, height = 44.dp)
                    .semantics { contentDescription = "Select all verses up to ${verse.title}" }
                    .dimOnPress(onClick = onSelectUpTo),
                contentAlignment = Alignment.Center,
            ) {
                Icon(R.drawable.ic_arrow_line_up, size = 15.dp, tint = colors.tertiaryLabel)
            }
        }
        if (showsDivider) Divider(Modifier.padding(start = 72.dp, end = AppLayout.panelPadding))
    }
}

@Composable
internal fun ResumeRow(
    done: Int,
    total: Int,
    packsText: String,
    onResume: () -> Unit,
    onEnd: () -> Unit,
) {
    val colors = AppTheme.colors
    val scope = rememberCoroutineScope()
    val offset = remember { Animatable(0f) }
    val revealWidth = 88.dp
    val reveal = with(LocalDensity.current) { revealWidth.toPx() }
    val fraction by animateFloatAsState(done.toFloat() / total.coerceAtLeast(1), AppMotion.content(), label = "resume")

    Box(Modifier.fillMaxWidth().height(IntrinsicSize.Min)) {
        if (offset.value < 0f) {
            Box(
                Modifier
                    .align(Alignment.CenterEnd)
                    .fillMaxHeight()
                    .width(revealWidth)
                    .background(colors.red)
                    .pressable(pressedScale = 1f, pressedAlpha = 0.6f, onClick = onEnd),
                contentAlignment = Alignment.Center,
            ) {
                Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(2.dp)) {
                    Icon(R.drawable.ic_trash, size = 20.dp, tint = colors.onAccent)
                    Text("End", style = AppType.caption.copy(fontWeight = FontWeight.SemiBold), color = colors.onAccent)
                }
            }
        }
        Row(
            Modifier
                .fillMaxWidth()
                .offset { IntOffset(offset.value.roundToInt(), 0) }
                .background(colors.panel)
                .semantics(mergeDescendants = true) {
                    contentDescription = "Unfinished quiz, $done of $total verses done, $packsText"
                    customActions = listOf(
                        CustomAccessibilityAction("End") {
                            onEnd()
                            true
                        },
                    )
                }
                .draggable(
                    orientation = Orientation.Horizontal,
                    state = rememberDraggableState { delta ->
                        scope.launch { offset.snapTo((offset.value + delta).coerceIn(-reveal, 0f)) }
                    },
                    onDragStopped = {
                        val target = if (offset.value < -reveal / 2) -reveal else 0f
                        scope.launch { offset.animateTo(target, AppMotion.control()) }
                    },
                )
                .pressable(pressedScale = 1f, pressedAlpha = 0.7f) {
                    if (offset.value < 0f) {
                        scope.launch { offset.animateTo(0f, AppMotion.control()) }
                    } else {
                        onResume()
                    }
                }
                .padding(horizontal = AppLayout.panelPadding, vertical = 16.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                Text(
                    "$done of $total verses done",
                    style = AppType.headline.copy(fontFeatureSettings = "tnum"),
                    color = colors.label,
                    maxLines = 1,
                )
                Text(packsText, style = AppType.subheadline, color = colors.secondaryLabel, maxLines = 1)
                Box(Modifier.fillMaxWidth().height(4.dp).clip(CapsuleShape).background(colors.fill)) {
                    Box(Modifier.fillMaxHeight().fillMaxWidth(fraction).clip(CapsuleShape).background(colors.accent))
                }
            }
            Box(
                Modifier
                    .clip(CapsuleShape)
                    .background(colors.accent)
                    .padding(horizontal = 16.dp, vertical = 8.dp),
            ) {
                Text(
                    "Resume",
                    style = AppType.headline,
                    color = colors.onAccent,
                    maxLines = 1,
                )
            }
        }
    }
}
