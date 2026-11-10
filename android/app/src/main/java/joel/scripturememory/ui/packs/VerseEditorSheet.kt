package joel.scripturememory.ui.packs

import android.content.ActivityNotFoundException
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalFocusManager
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
import joel.scripturememory.model.trimmingWhitespaces
import joel.scripturememory.model.trimmingWhitespacesAndNewlines
import joel.scripturememory.system.Analytics
import joel.scripturememory.system.HapticEngine
import joel.scripturememory.ui.components.AlertAction
import joel.scripturememory.ui.components.AppAlert
import joel.scripturememory.ui.components.AppSheet
import joel.scripturememory.ui.components.GroupedSection
import joel.scripturememory.ui.components.LabeledFieldRow
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
import joel.scripturememory.ui.theme.AppLayout
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
    var choosingTranslation by remember { mutableStateOf(false) }
    var referenceFocused by remember { mutableStateOf(false) }
    val referenceFocus = remember { FocusRequester() }
    val titleFocus = remember { FocusRequester() }
    val textFocus = remember { FocusRequester() }
    val focusManager = LocalFocusManager.current

    val reference = BibleReference.parse(referenceText.text)
    val trimmedText = text.text.trimmingWhitespacesAndNewlines()
    val canSave = reference != null && trimmedText.isNotEmpty()
    val typedIsCanonical = reference != null && referenceText.text.trimmingWhitespaces() == reference.display
    val bibleAppURL = reference?.let { VerseTranslation.bibleAppURL(it, translation) }
    val translationChoices = if (translation in VerseTranslation.choices) VerseTranslation.choices
    else VerseTranslation.choices + translation

    val olderNIVHasIt = reference != null && translation == VerseTranslation.niv && trimmedText.isEmpty() &&
        VerseLookup.bundled(reference, VerseTranslation.niv84) != null
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
        referenceText = field("")
        text = field("")
        title = field("")
        autofilled = null
        pastedText = null
        focusManager.clearFocus()
    }

    LaunchedEffect(referenceText.text, translation) { autofill() }

    AppSheet(onDismiss = onDismiss, fullHeight = true) { sheet ->
        SheetHeader(
            if (editing == null) "Add Verse" else "Edit Verse",
            leading = {
                TextButton(
                    if (editing == null && added.isNotEmpty()) "Done" else "Cancel",
                    style = AppType.body,
                    onClick = sheet.dismiss,
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
        Column(
            Modifier
                .weight(1f)
                .fillMaxWidth()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = AppLayout.screenMargin)
                .padding(top = 8.dp, bottom = 24.dp),
            verticalArrangement = Arrangement.spacedBy(AppLayout.spacing * 1.5f),
        ) {
            Column {
                GroupedSection {
                    LabeledFieldRow(
                        "Reference",
                        value = referenceText,
                        onValueChange = { referenceText = it },
                        modifier = Modifier
                            .focusRequester(referenceFocus)
                            .onFocusChanged { referenceFocused = it.isFocused },
                        placeholder = "Rom 8:28",
                        keyboardOptions = KeyboardOptions(
                            capitalization = KeyboardCapitalization.Words,
                            autoCorrectEnabled = false,
                            imeAction = ImeAction.Next,
                        ),
                        keyboardActions = KeyboardActions(
                            onNext = { if (trimmedText.isEmpty()) textFocus.requestFocus() else titleFocus.requestFocus() },
                        ),
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
                    olderNIVHasIt && !duplicate -> TextButton(
                        "Fill in the app’s ${VerseTranslation.displayName(VerseTranslation.niv84)} text",
                        Modifier.padding(start = AppLayout.panelPadding, end = AppLayout.panelPadding, top = 8.dp),
                        style = AppType.footnote.copy(fontWeight = FontWeight.SemiBold),
                        onClick = { translation = VerseTranslation.niv84 },
                    )
                    reference != null && duplicate -> StatusLine(
                        "Already in this pack",
                        icon = R.drawable.ic_warning_fill,
                        tint = colors.orange,
                    )
                    reference != null -> if (!typedIsCanonical) {
                        StatusLine(reference.display, icon = R.drawable.ic_check_circle_fill, tint = colors.green)
                    }
                    added.isNotEmpty() && referenceText.text.isEmpty() -> StatusLine("Added ${added.last()}")
                    referenceText.text.isNotEmpty() -> StatusLine("Try “Rom 8:28”")
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
                            text = it
                        }
                    },
                    modifier = Modifier
                        .focusRequester(textFocus)
                        .semantics { contentDescription = "Verse" },
                    placeholder = "Type or paste the verse",
                    singleLine = false,
                    minLines = 4,
                    keyboardOptions = KeyboardOptions(
                        capitalization = KeyboardCapitalization.Sentences,
                        imeAction = ImeAction.Done,
                    ),
                    keyboardActions = KeyboardActions(onDone = { focusManager.clearFocus() }),
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

            GroupedSection {
                LabeledFieldRow(
                    "Title",
                    value = title,
                    onValueChange = { title = it },
                    modifier = Modifier.focusRequester(titleFocus),
                    placeholder = "Optional",
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

private fun openBibleApp(context: Context, url: String) {
    try {
        context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url)).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
    } catch (_: ActivityNotFoundException) {
    }
}
