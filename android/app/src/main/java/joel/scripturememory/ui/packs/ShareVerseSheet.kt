package joel.scripturememory.ui.packs

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextRange
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.input.TextFieldValue
import androidx.compose.ui.unit.dp
import joel.scripturememory.R
import joel.scripturememory.model.BibleReference
import joel.scripturememory.model.PastedVerse
import joel.scripturememory.model.SharedVerseDefaults
import joel.scripturememory.model.SharedVerseDraft
import joel.scripturememory.model.UserPack
import joel.scripturememory.model.VerseTranslation
import joel.scripturememory.model.trimmingWhitespaces
import joel.scripturememory.model.trimmingWhitespacesAndNewlines
import joel.scripturememory.ui.components.AppSheet
import joel.scripturememory.ui.components.GroupedSection
import joel.scripturememory.ui.components.LabeledFieldRow
import joel.scripturememory.ui.components.ListRow
import joel.scripturememory.ui.components.PickerSheet
import joel.scripturememory.ui.components.RowDivider
import joel.scripturememory.ui.components.SheetHeader
import joel.scripturememory.ui.components.StatusLine
import joel.scripturememory.ui.components.TextButton
import joel.scripturememory.ui.components.TextFieldRow
import joel.scripturememory.ui.theme.AppLayout
import joel.scripturememory.ui.theme.AppTheme
import joel.scripturememory.ui.theme.AppType

private const val newPackID = "new"

@Composable
fun ShareVerseSheet(
    pasted: PastedVerse,
    packs: List<UserPack>,
    onAdd: (SharedVerseDraft) -> Unit,
    onDismiss: () -> Unit,
) {
    val colors = AppTheme.colors
    var referenceText by remember { mutableStateOf(field(pasted.reference?.display.orEmpty())) }
    var translation by remember {
        mutableStateOf(pasted.version ?: SharedVerseDefaults.lastTranslation ?: VerseTranslation.niv)
    }
    var text by remember { mutableStateOf(field(pasted.text)) }
    var title by remember { mutableStateOf(field("")) }
    var packID by remember {
        val last = SharedVerseDefaults.lastPackID
        mutableStateOf(packs.firstOrNull { it.id == last }?.id ?: packs.firstOrNull()?.id ?: newPackID)
    }
    var choosingTranslation by remember { mutableStateOf(false) }
    var choosingPack by remember { mutableStateOf(false) }
    val referenceFocus = remember { FocusRequester() }

    val reference = BibleReference.parse(referenceText.text)
    val trimmedText = text.text.trimmingWhitespacesAndNewlines()
    val translationChoices = if (translation in VerseTranslation.choices) VerseTranslation.choices
    else VerseTranslation.choices + translation
    val newPackLabel = if (packs.isEmpty()) "New Pack “OYO”" else "New Pack"
    fun packName(id: String) = packs.firstOrNull { it.id == id }?.name ?: newPackLabel

    fun add() {
        val ref = reference ?: return
        if (trimmedText.isEmpty()) return
        val isNew = packID == newPackID
        SharedVerseDefaults.lastTranslation = translation
        if (!isNew) SharedVerseDefaults.lastPackID = packID
        onAdd(
            SharedVerseDraft(
                packID = if (isNew) null else packID,
                newPackName = if (isNew) UserPack.defaultName else null,
                title = title.text.trimmingWhitespacesAndNewlines(),
                text = trimmedText,
                book = ref.book.name,
                reference = ref.reference,
                version = translation,
            ),
        )
    }

    LaunchedEffect(Unit) { if (referenceText.text.isEmpty()) referenceFocus.requestFocus() }

    AppSheet(onDismiss = onDismiss, fullHeight = true) { sheet ->
        SheetHeader(
            "Add Verse",
            leading = { TextButton("Cancel", style = AppType.body, onClick = sheet.dismiss) },
            trailing = {
                TextButton(
                    "Add",
                    enabled = reference != null && trimmedText.isNotEmpty(),
                    style = AppType.body.copy(fontWeight = FontWeight.SemiBold),
                    onClick = {
                        add()
                        sheet.dismiss()
                    },
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
                        modifier = Modifier.focusRequester(referenceFocus),
                        placeholder = "Romans 8:28",
                        keyboardOptions = KeyboardOptions(
                            capitalization = KeyboardCapitalization.Words,
                            autoCorrectEnabled = false,
                        ),
                    )
                    RowDivider()
                    LabeledFieldRow(
                        "Topic",
                        value = title,
                        onValueChange = { title = it },
                        placeholder = "Optional",
                        keyboardOptions = KeyboardOptions(capitalization = KeyboardCapitalization.Words),
                    )
                    RowDivider()
                    ListRow(
                        "Translation",
                        value = VerseTranslation.displayName(translation),
                        showsChevron = true,
                        onClick = { choosingTranslation = true },
                    )
                }
                if (reference != null) {
                    if (referenceText.text.trimmingWhitespaces() != reference.display) {
                        StatusLine(reference.display, icon = R.drawable.ic_check_circle_fill, tint = colors.green)
                    }
                } else {
                    StatusLine("Try “Romans 8:28”")
                }
            }

            GroupedSection(title = "Verse") {
                TextFieldRow(
                    value = text,
                    onValueChange = { text = it },
                    modifier = Modifier.semantics { contentDescription = "Verse" },
                    singleLine = false,
                    minLines = 3,
                    keyboardOptions = KeyboardOptions(capitalization = KeyboardCapitalization.Sentences),
                )
            }

            GroupedSection {
                ListRow(
                    "Pack",
                    value = packName(packID),
                    showsChevron = true,
                    onClick = { choosingPack = true },
                )
            }
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
    if (choosingPack) {
        PickerSheet(
            title = "Pack",
            options = packs.map { it.id } + newPackID,
            selected = packID,
            label = ::packName,
            onSelect = { packID = it },
            onDismiss = { choosingPack = false },
        )
    }
}

private fun field(text: String) = TextFieldValue(text, TextRange(text.length))
