package joel.scripturememory.ui.packs

import android.content.ActivityNotFoundException
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.core.snap
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.SideEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.platform.LocalSoftwareKeyboardController
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.disabled
import androidx.compose.ui.semantics.onClick
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextRange
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.input.TextFieldValue
import androidx.compose.ui.unit.dp
import joel.scripturememory.R
import joel.scripturememory.model.AnalyticsEvent
import joel.scripturememory.model.AppDefaults
import joel.scripturememory.model.BibleBooks
import joel.scripturememory.model.BibleReference
import joel.scripturememory.model.OwnVerseSource
import joel.scripturememory.model.PastedVerse
import joel.scripturememory.model.SRSKey
import joel.scripturememory.model.UserPackStore
import joel.scripturememory.model.UserVerse
import joel.scripturememory.model.VerseLookup
import joel.scripturememory.model.VerseLookupResult
import joel.scripturememory.model.VerseTranslation
import joel.scripturememory.model.trimmingWhitespacesAndNewlines
import joel.scripturememory.system.Analytics
import joel.scripturememory.system.HapticEngine
import joel.scripturememory.ui.components.AlertAction
import joel.scripturememory.ui.components.AppAlert
import joel.scripturememory.ui.components.AppSheet
import joel.scripturememory.ui.components.GroupedSection
import joel.scripturememory.ui.components.ListRow
import joel.scripturememory.ui.components.PickerSheet
import joel.scripturememory.ui.components.PillRow
import joel.scripturememory.ui.components.RowDivider
import joel.scripturememory.ui.components.BorderedButton
import joel.scripturememory.ui.components.SheetHeader
import joel.scripturememory.ui.components.StatusLine
import joel.scripturememory.ui.components.Text
import joel.scripturememory.ui.components.TextButton
import joel.scripturememory.ui.components.TextFieldRow
import joel.scripturememory.ui.components.UndoToastHost
import joel.scripturememory.ui.components.UndoToastState
import joel.scripturememory.ui.theme.AppLayout
import joel.scripturememory.ui.theme.AppMotion
import joel.scripturememory.ui.theme.AppTheme
import joel.scripturememory.ui.theme.AppType
import joel.scripturememory.ui.theme.isAccessibilityTextSize

private const val lastTranslationKey = "userVerse.lastTranslation.v1"

private fun field(text: String) = TextFieldValue(text, TextRange(text.length))

@Composable
fun VerseEditorSheet(
    packID: String,
    editing: UserVerse? = null,
    draft: PastedVerse? = null,
    onDismiss: () -> Unit,
) {
    val store = UserPackStore.shared
    val colors = AppTheme.colors
    val context = LocalContext.current

    val lastTranslation = AppDefaults.standard.getString(lastTranslationKey) ?: VerseTranslation.niv
    var referenceText by remember {
        mutableStateOf(
            field(editing?.let { "${it.book} ${it.reference}" } ?: draft?.reference?.display.orEmpty()),
        )
    }
    var translation by remember {
        mutableStateOf(
            editing?.let { it.version ?: VerseTranslation.niv }
                ?: draft?.version
                ?: lastTranslation,
        )
    }
    var text by remember { mutableStateOf(field(editing?.text ?: draft?.text.orEmpty())) }
    var title by remember { mutableStateOf(field(editing?.title.orEmpty())) }
    var autofilled by remember { mutableStateOf<VerseLookupResult?>(null) }
    var added by remember { mutableStateOf(listOf<String>()) }
    var pastedText by remember { mutableStateOf(if (editing == null) draft?.text else null) }
    var confirmDelete by remember { mutableStateOf(false) }
    var confirmDiscard by remember { mutableStateOf(false) }
    var addedToast by remember { mutableStateOf<UndoToastState?>(null) }
    var choosingTranslation by remember { mutableStateOf(false) }
    var referenceFocused by remember { mutableStateOf(false) }
    val referenceFocus = remember { FocusRequester() }
    val keyboard = remember { KeyboardCloser() }

    val reference = BibleReference.parse(referenceText.text)
    val trimmedText = text.text.trimmingWhitespacesAndNewlines()
    val canSave = reference != null && trimmedText.isNotEmpty()
    val hasChanges = if (editing != null) {
        referenceText.text != "${editing.book} ${editing.reference}" || text.text != editing.text ||
            title.text != editing.title || translation != (editing.version ?: VerseTranslation.niv)
    } else {
        referenceText.text.isNotBlank() || trimmedText.isNotEmpty() || title.text.isNotBlank()
    }
    val bibleAppURL = reference?.let { VerseTranslation.bibleAppURL(it, translation) }
    val translationChoices = if (translation in VerseTranslation.choices) VerseTranslation.choices
    else VerseTranslation.choices + translation

    val olderNIVText = if (reference != null && translation == VerseTranslation.niv && trimmedText.isEmpty()) {
        VerseLookup.bundled(reference, VerseTranslation.niv84)
    } else {
        null
    }
    val duplicate = reference != null && store.pack(packID)?.verses?.any {
        val wanted = SRSKey.normalizedReference(reference.reference)
        it.id != editing?.id && it.book == reference.book.name && SRSKey.normalizedReference(it.reference) == wanted
    } == true

    val bookSuggestions = run {
        val raw = referenceText.text
        val shows = reference == null && referenceFocused &&
            (raw.none { it.isDigit() } || raw.firstOrNull()?.isDigit() == true) &&
            raw.count { it.isDigit() } <= 1
        if (shows) BibleBooks.matching(raw) else emptyList()
    }

    fun autofill() {
        val ref = BibleReference.parse(referenceText.text) ?: return
        val isUntouched = text.text.trimmingWhitespacesAndNewlines().isEmpty() || text.text == autofilled?.text
        val found = if (isUntouched) VerseLookup.bundled(ref, translation) else null
        if (found == null) {
            val previous = autofilled
            if (isUntouched && previous != null) {
                text = field("")
                if (title.text == previous.title) title = field("")
                autofilled = null
            }
            return
        }
        if (title.text.isEmpty() || title.text == autofilled?.title) title = field(found.title)
        text = field(found.text)
        autofilled = found
    }

    fun applyPaste(raw: String) {
        val pasted = PastedVerse.parse(raw)
        pasted.reference?.let { referenceText = field(it.display) }
        pasted.version?.let { translation = if (it == "NIV") VerseTranslation.niv else it }
        if (pasted.text.isNotEmpty()) {
            text = field(pasted.text)
            pastedText = pasted.text
            autofilled = null
        }
        keyboard.close()
        HapticEngine.light()
    }

    fun paste() {
        val clipboard = context.getSystemService(ClipboardManager::class.java) ?: return
        val clip = clipboard.primaryClip ?: return
        if (clip.itemCount == 0) return
        val raw = clip.getItemAt(0).coerceToText(context)?.toString().orEmpty()
        if (raw.isNotEmpty()) applyPaste(raw)
    }

    fun save(dismiss: () -> Unit) {
        val ref = reference ?: return
        if (!canSave) return
        val verse = UserVerse(
            id = editing?.id ?: UserVerse.newID(),
            title = title.text.trimmingWhitespacesAndNewlines(),
            text = trimmedText,
            book = ref.book.name,
            reference = ref.reference,
            version = translation,
        )
        AppDefaults.standard.putString(lastTranslationKey, translation)
        if (editing != null) {
            store.updateVerse(verse, packID)
            dismiss()
            return
        }
        store.addVerse(verse, packID)
        val source = when {
            autofilled?.text == text.text -> OwnVerseSource.bundledText
            pastedText == text.text -> OwnVerseSource.pasted
            else -> OwnVerseSource.typed
        }
        Analytics.log(AnalyticsEvent.OwnVerseAdded(source))
        HapticEngine.success()
        added = added + ref.display
        val packName = store.pack(packID)?.name ?: "this pack"
        addedToast = UndoToastState("Added ${ref.display} to $packName") {
            store.deleteVerses(setOf(verse.id), packID)
        }
        referenceText = field("")
        text = field("")
        title = field("")
        autofilled = null
        pastedText = null
        keyboard.close()
    }

    LaunchedEffect(referenceText.text, translation) { autofill() }

    AppSheet(
        onDismiss = onDismiss,
        fullHeight = true,
        onDismissAttempt = if (hasChanges) ({ confirmDiscard = true }) else null,
    ) { sheet ->
        val focusManager = LocalFocusManager.current
        val softKeyboard = LocalSoftwareKeyboardController.current
        SideEffect {
            keyboard.close = {
                focusManager.clearFocus()
                softKeyboard?.hide()
            }
        }
        SheetHeader(
            when {
                editing != null -> "Edit Verse"
                added.isEmpty() -> "Add Verse"
                else -> "Add Another Verse"
            },
            leading = {
                TextButton(
                    if (editing == null && added.isNotEmpty() && !hasChanges) "Done" else "Cancel",
                    style = AppType.body,
                    onClick = { if (hasChanges) confirmDiscard = true else sheet.dismiss() },
                )
            },
            trailing = {
                TextButton(
                    if (editing == null) "Add" else "Save",
                    enabled = canSave,
                    style = AppType.body.copy(fontWeight = FontWeight.SemiBold),
                    onClick = { save(sheet.dismiss) },
                )
            },
        )
        Box(Modifier.weight(1f).fillMaxWidth()) {
            AnimatedContent(
                targetState = added.size,
                transitionSpec = { slideInHorizontally(AppMotion.content()) { it } togetherWith fadeOut(snap()) },
                label = "verseForm",
            ) { _ ->
                Column(
                    Modifier
                        .fillMaxSize()
                        .pointerInput(Unit) { detectTapGestures { keyboard.close() } }
                        .verticalScroll(rememberScrollState())
                        .padding(horizontal = AppLayout.screenMargin)
                        .padding(top = 8.dp, bottom = 24.dp),
                    verticalArrangement = Arrangement.spacedBy(AppLayout.spacing * 1.5f),
                ) {
                    Column {
                        GroupedSection {
                            TextFieldRow(
                                value = referenceText,
                                onValueChange = { referenceText = it },
                                modifier = Modifier
                                    .focusRequester(referenceFocus)
                                    .onFocusChanged { referenceFocused = it.isFocused }
                                    .semantics { contentDescription = "Reference" },
                                placeholder = "Reference, like Rom 8:28",
                                keyboardOptions = KeyboardOptions(
                                    capitalization = KeyboardCapitalization.Words,
                                    autoCorrectEnabled = false,
                                    imeAction = ImeAction.Done,
                                ),
                                keyboardActions = KeyboardActions(onDone = { keyboard.close() }),
                            )
                            if (bookSuggestions.isNotEmpty()) {
                                PillRow(bookSuggestions.map { it.name }, onClick = { i ->
                                    referenceText = field(bookSuggestions[i].name + " ")
                                })
                            }
                            RowDivider()
                            ListRow(
                                "Translation",
                                value = VerseTranslation.displayName(translation),
                                showsChevron = true,
                                onClick = { choosingTranslation = true },
                            )
                        }
                        when {
                            olderNIVText != null && !duplicate -> TextButton(
                                "This verse is already in ${olderNIVText.pack}. Tap to fill it in.",
                                Modifier.padding(start = AppLayout.panelPadding, end = AppLayout.panelPadding, top = 8.dp),
                                style = AppType.footnote.copy(fontWeight = FontWeight.SemiBold),
                                maxLines = 3,
                                onClick = { translation = VerseTranslation.niv84 },
                            )
                            reference != null && duplicate -> StatusLine(
                                "Already in this pack",
                                icon = R.drawable.ic_warning_fill,
                                tint = colors.orange,
                            )
                            reference == null && referenceText.text.isNotEmpty() -> StatusLine("Try “Rom 8:28”")
                        }
                    }

                    GroupedSection(
                        title = "Verse",
                        footer = if (autofilled != null && autofilled?.text == text.text) {
                            "From the app’s ${VerseTranslation.displayName(translation)} text"
                        } else {
                            "Copy it in your Bible app, then tap Paste."
                        },
                    ) {
                        TextFieldRow(
                            value = text,
                            onValueChange = {
                                if (it.text.length > text.text.length + 1 && PastedVerse.share(it.text) != null) {
                                    applyPaste(it.text)
                                } else {
                                    val pastedIntoEmpty = editing == null && text.text.isEmpty() &&
                                        it.text.length >= 40 && it.text != autofilled?.text
                                    text = it
                                    if (pastedIntoEmpty) {
                                        pastedText = it.text
                                        keyboard.close()
                                    }
                                }
                            },
                            modifier = Modifier.semantics { contentDescription = "Verse" },
                            placeholder = "Type or paste the verse",
                            singleLine = false,
                            minLines = 4,
                            keyboardOptions = KeyboardOptions(
                                capitalization = KeyboardCapitalization.Sentences,
                                imeAction = ImeAction.Done,
                            ),
                            keyboardActions = KeyboardActions(onDone = { keyboard.close() }),
                        )
                        RowDivider()
                        val bibleLabel = reference?.let { "Find ${it.display} in the Bible app" } ?: "Find in the Bible app"
                        val openInBible = @Composable { modifier: Modifier ->
                            BorderedButton(
                                "Open in Bible",
                                modifier.clearAndSetSemantics {
                                    contentDescription = bibleLabel
                                    role = Role.Button
                                    if (bibleAppURL == null) disabled()
                                    onClick {
                                        bibleAppURL?.let { openBibleApp(context, it) }
                                        true
                                    }
                                },
                                enabled = bibleAppURL != null,
                                leadingIcon = R.drawable.ic_book_open_fill,
                                onClick = { bibleAppURL?.let { openBibleApp(context, it) } },
                            )
                        }
                        val pasteButton = @Composable { modifier: Modifier ->
                            BorderedButton("Paste", modifier, leadingIcon = R.drawable.ic_clipboard, onClick = ::paste)
                        }
                        val buttonsPadding = Modifier.fillMaxWidth().padding(horizontal = AppLayout.panelPadding, vertical = 10.dp)
                        if (isAccessibilityTextSize()) {
                            Column(buttonsPadding, verticalArrangement = Arrangement.spacedBy(12.dp)) {
                                openInBible(Modifier.fillMaxWidth())
                                pasteButton(Modifier.fillMaxWidth())
                            }
                        } else {
                            Row(buttonsPadding, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                                openInBible(Modifier.weight(1f))
                                pasteButton(Modifier.weight(1f))
                            }
                        }
                    }

                    GroupedSection(footer = "Optional. Shown on the front of the card.") {
                        TextFieldRow(
                            value = title,
                            onValueChange = { title = it },
                            modifier = Modifier.semantics { contentDescription = "Title" },
                            placeholder = "Title, like Christ the Center",
                            keyboardOptions = KeyboardOptions(
                                capitalization = KeyboardCapitalization.Words,
                                imeAction = ImeAction.Done,
                            ),
                        )
                    }

                    if (editing != null) {
                        GroupedSection {
                            ListRow("Delete Verse", titleColor = colors.red, onClick = { confirmDelete = true })
                        }
                    }
                }
            }
            UndoToastHost(addedToast) { addedToast = it }
        }

        if (confirmDiscard) {
            AppAlert(
                title = if (editing == null) "Discard this verse?" else "Discard your changes?",
                actions = listOf(
                    AlertAction("Keep Editing", isCancel = true),
                    AlertAction(if (editing == null) "Discard Verse" else "Discard Changes", isDestructive = true) {
                        sheet.dismiss()
                    },
                ),
                onDismiss = { confirmDiscard = false },
            )
        }

        if (confirmDelete && editing != null) {
            AppAlert(
                title = "Delete Verse?",
                message = "Its review history is deleted too.",
                actions = listOf(
                    AlertAction("Cancel", isCancel = true),
                    AlertAction("Delete Verse", isDestructive = true) {
                        store.deleteVerses(setOf(editing.id), packID)
                        sheet.dismiss()
                    },
                ),
                onDismiss = { confirmDelete = false },
            )
        }
    }

    if (choosingTranslation) {
        PickerSheet(
            title = "Translation",
            options = translationChoices,
            selected = translation,
            label = VerseTranslation::displayName,
            onSelect = { translation = it },
            onDismiss = { choosingTranslation = false },
        )
    }
}

private class KeyboardCloser {
    var close: () -> Unit = {}
}

private fun openBibleApp(context: Context, url: String) {
    try {
        context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url)).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
    } catch (_: ActivityNotFoundException) {
    }
}
