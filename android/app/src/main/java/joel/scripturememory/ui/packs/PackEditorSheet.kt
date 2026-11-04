package joel.scripturememory.ui.packs

import androidx.compose.animation.Crossfade
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.defaultMinSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextRange
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.input.TextFieldValue
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import joel.scripturememory.R
import joel.scripturememory.model.AnalyticsEvent
import joel.scripturememory.model.OwnPackSource
import joel.scripturememory.model.Pack
import joel.scripturememory.model.UserPack
import joel.scripturememory.model.UserPackStore
import joel.scripturememory.model.UserVerse
import joel.scripturememory.model.trimmingWhitespaces
import joel.scripturememory.system.Analytics
import joel.scripturememory.system.HapticEngine
import joel.scripturememory.ui.components.AddItemRow
import joel.scripturememory.ui.components.AlertAction
import joel.scripturememory.ui.components.AppAlert
import joel.scripturememory.ui.components.AppSheet
import joel.scripturememory.ui.components.AppTextField
import joel.scripturememory.ui.components.ColorSwatches
import joel.scripturememory.ui.components.GroupedSection
import joel.scripturememory.ui.components.Icon
import joel.scripturememory.ui.components.ListRow
import joel.scripturememory.ui.components.ReorderGrip
import joel.scripturememory.ui.components.ReorderableRows
import joel.scripturememory.ui.components.SheetHeader
import joel.scripturememory.ui.components.Text
import joel.scripturememory.ui.components.TextButton
import joel.scripturememory.ui.components.dimOnPress
import joel.scripturememory.ui.components.pressable
import joel.scripturememory.ui.components.rememberRowReorder
import joel.scripturememory.ui.components.reorderViewport
import joel.scripturememory.ui.theme.AppLayout
import joel.scripturememory.ui.theme.AppMotion
import joel.scripturememory.ui.theme.AppTheme
import joel.scripturememory.ui.theme.AppType

private val swatchNames = listOf("Red", "Green", "Blue", "Orange", "Purple", "Graphite")
private const val addRowKey = "add"
private const val previewWidthShare = 0.62f

private class VerseSheet(val verse: UserVerse?)

@Composable
fun PackEditorSheet(packID: String? = null, addsVerseOnOpen: Boolean = false, onDismiss: () -> Unit) {
    val store = UserPackStore.shared
    val colors = AppTheme.colors
    val existing = remember { packID?.let { store.pack(it) } }
    var currentID by remember { mutableStateOf(existing?.id) }
    var name by remember {
        val initial = existing?.name ?: store.availableName(UserPack.defaultName)
        mutableStateOf(TextFieldValue(initial, TextRange(initial.length)))
    }
    var color by remember { mutableStateOf(existing?.color ?: UserPack.colors[0]) }
    var verseSheet by remember { mutableStateOf<VerseSheet?>(null) }
    var confirmDelete by remember { mutableStateOf(false) }
    var editingOrder by remember { mutableStateOf(false) }
    val nameFocus = remember { FocusRequester() }
    val scroll = rememberScrollState()
    val reorder = rememberRowReorder(scroll)

    val pack = currentID?.let { store.pack(it) }

    fun commitDetails() {
        val current = pack ?: return
        store.updatePack(current.id, name.text, color)
        val saved = store.pack(current.id)?.name ?: return
        if (saved != name.text) name = TextFieldValue(saved, TextRange(saved.length))
    }

    fun create() {
        val created = store.createPack(name.text, color)
        Analytics.log(AnalyticsEvent.OwnPackCreated(OwnPackSource.newPack))
        currentID = created.id
        name = TextFieldValue(created.name, TextRange(created.name.length))
        HapticEngine.success()
        verseSheet = VerseSheet(null)
    }

    LaunchedEffect(Unit) {
        if (pack == null) nameFocus.requestFocus()
        if (addsVerseOnOpen && pack != null) verseSheet = VerseSheet(null)
    }

    AppSheet(
        onDismiss = {
            commitDetails()
            onDismiss()
        },
        fullHeight = true,
    ) { sheet ->
        SheetHeader(
            if (pack == null) "New Pack" else "Edit Pack",
            leading = {
                if (pack == null) TextButton("Cancel", style = AppType.body, onClick = sheet.dismiss)
            },
            trailing = {
                TextButton(
                    if (pack == null) "Create" else "Done",
                    style = AppType.body.copy(fontWeight = FontWeight.SemiBold),
                    onClick = { if (pack == null) create() else sheet.dismiss() },
                )
            },
        )
        BoxWithConstraints(Modifier.weight(1f).fillMaxWidth()) {
            val sheetWidth = maxWidth
            Column(
                Modifier
                    .fillMaxSize()
                    .reorderViewport(reorder)
                    .verticalScroll(scroll, enabled = !reorder.isDragging)
                    .padding(horizontal = AppLayout.screenMargin)
                    .padding(top = 8.dp, bottom = 24.dp),
                verticalArrangement = Arrangement.spacedBy(AppLayout.spacing * 1.5f),
            ) {
                GroupedSection(
                    footer = if (pack == null) "OYO means “On Your Own”: verses you choose yourself." else null,
                ) {
                    Column(
                        Modifier.fillMaxWidth().padding(horizontal = AppLayout.panelPadding, vertical = 20.dp),
                        horizontalAlignment = Alignment.CenterHorizontally,
                        verticalArrangement = Arrangement.spacedBy(16.dp),
                    ) {
                        val preview = Pack(
                            name = name.text.trimmingWhitespaces().ifEmpty { UserPack.defaultName },
                            color = color,
                            accentText = "",
                            verses = pack?.pack?.verses.orEmpty(),
                            userPackID = currentID ?: "preview",
                        )
                        Crossfade(
                            preview,
                            Modifier.width(sheetWidth * previewWidthShare).clearAndSetSemantics {},
                            animationSpec = AppMotion.smooth(240),
                            label = "cover",
                        ) { PackCover(it) }
                        AppTextField(
                            value = name,
                            onValueChange = { name = it },
                            modifier = Modifier
                                .fillMaxWidth()
                                .clip(RoundedCornerShape(12.dp))
                                .background(colors.fill)
                                .padding(horizontal = 12.dp, vertical = 12.dp)
                                .focusRequester(nameFocus)
                                .semantics { contentDescription = "Pack Name" },
                            placeholder = UserPack.defaultName,
                            textStyle = AppType.title3,
                            textAlign = TextAlign.Center,
                            keyboardOptions = KeyboardOptions(
                                capitalization = KeyboardCapitalization.Words,
                                imeAction = ImeAction.Done,
                            ),
                            keyboardActions = KeyboardActions(onDone = { commitDetails() }),
                        )
                        ColorSwatches(
                            colors = UserPack.colors.map { colorFromHex(it) ?: Color.Gray },
                            names = swatchNames,
                            selected = UserPack.colors.indexOf(color),
                            onSelect = {
                                color = UserPack.colors[it]
                                HapticEngine.light()
                                commitDetails()
                            },
                        )
                    }
                }

                if (pack != null) {
                    Column {
                        Row(
                            Modifier.fillMaxWidth().padding(start = AppLayout.panelPadding, end = AppLayout.panelPadding - 4.dp),
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            Text(
                                "Cards",
                                Modifier.weight(1f).padding(vertical = 8.dp).semantics { heading() },
                                style = AppType.footnote,
                                color = colors.secondaryLabel,
                            )
                            if (pack.verses.isNotEmpty()) {
                                TextButton(
                                    if (editingOrder) "Done" else "Edit",
                                    style = AppType.subheadline,
                                    onClick = { editingOrder = !editingOrder },
                                )
                            }
                        }
                        ReorderableRows(
                            keys = listOf(addRowKey) + pack.verses.map { it.id },
                            reorder = reorder,
                            onMove = { from, to ->
                                store.moveVerses(pack.id, setOf(from - 1), maxOf(to - 1, 0))
                            },
                        ) { row, handle ->
                            if (row == 0) {
                                AddItemRow("Add Verse", onClick = { verseSheet = VerseSheet(null) })
                            } else {
                                val verse = pack.verses[row - 1]
                                VerseRow(
                                    verse,
                                    editing = editingOrder,
                                    onOpen = { verseSheet = VerseSheet(verse) },
                                    onDelete = { store.deleteVerses(setOf(verse.id), pack.id) },
                                    grip = { ReorderGrip(handle) },
                                )
                            }
                        }
                    }
                    GroupedSection {
                        ListRow("Delete Pack", titleColor = colors.red, onClick = { confirmDelete = true })
                    }
                }
            }
        }

        if (confirmDelete && pack != null) {
            AppAlert(
                title = "Delete ${pack.name}?",
                message = "Deletes ${pack.verses.size} cards and their history on all your devices.",
                actions = listOf(
                    AlertAction("Cancel", isCancel = true),
                    AlertAction("Delete Pack", isDestructive = true) {
                        currentID = null
                        store.deletePack(pack.id)
                        sheet.dismiss()
                    },
                ),
                onDismiss = { confirmDelete = false },
            )
        }
    }

    val id = currentID
    verseSheet?.let { sheet ->
        if (id != null) VerseEditorSheet(id, sheet.verse, onDismiss = { verseSheet = null })
    }
}

@Composable
private fun VerseRow(
    verse: UserVerse,
    editing: Boolean,
    onOpen: () -> Unit,
    onDelete: () -> Unit,
    grip: @Composable () -> Unit,
) {
    val colors = AppTheme.colors
    Row(
        Modifier
            .fillMaxWidth()
            .defaultMinSize(minHeight = 56.dp)
            .then(if (editing) Modifier else Modifier.pressable(pressedScale = 1f, pressedAlpha = 0.55f, onClick = onOpen))
            .padding(start = AppLayout.panelPadding, end = if (editing) 6.dp else AppLayout.panelPadding),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        if (editing) {
            Box(
                Modifier
                    .size(32.dp)
                    .semantics { contentDescription = "Delete ${verse.book} ${verse.reference}" }
                    .dimOnPress(onClick = onDelete),
                contentAlignment = Alignment.Center,
            ) {
                Icon(R.drawable.ic_minus_circle_fill, size = 22.dp, tint = colors.red)
            }
        }
        Column(Modifier.weight(1f).padding(vertical = 10.dp), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text("${verse.book} ${verse.reference}", style = AppType.body, color = colors.label, maxLines = 1)
            if (verse.title.isNotEmpty()) {
                Text(verse.title, style = AppType.subheadline, color = colors.secondaryLabel, maxLines = 1)
            }
        }
        if (editing) grip()
    }
}
