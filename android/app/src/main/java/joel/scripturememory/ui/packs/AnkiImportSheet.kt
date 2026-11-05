package joel.scripturememory.ui.packs

import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.IntrinsicSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.TextRange
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.input.TextFieldValue
import androidx.compose.ui.unit.dp
import java.io.File
import joel.scripturememory.R
import joel.scripturememory.model.AnalyticsEvent
import joel.scripturememory.model.AnkiImport
import joel.scripturememory.model.AnkiImportException
import joel.scripturememory.model.AnkiImportPlan
import joel.scripturememory.model.AnkiImportSummary
import joel.scripturememory.model.AnkiImporter
import joel.scripturememory.model.UserPack
import joel.scripturememory.model.read
import joel.scripturememory.system.Analytics
import joel.scripturememory.system.HapticEngine
import joel.scripturememory.system.OpenedFile
import joel.scripturememory.ui.components.AppSheet
import joel.scripturememory.ui.components.ContentUnavailable
import joel.scripturememory.ui.components.DisclosureRow
import joel.scripturememory.ui.components.GroupedSection
import joel.scripturememory.ui.components.Icon
import joel.scripturememory.ui.components.LabeledFieldRow
import joel.scripturememory.ui.components.ListRow
import joel.scripturememory.ui.components.PrimaryButton
import joel.scripturememory.ui.components.ProgressPanel
import joel.scripturememory.ui.components.RowDivider
import joel.scripturememory.ui.components.SheetHeader
import joel.scripturememory.ui.components.StepNumber
import joel.scripturememory.ui.components.Text
import joel.scripturememory.ui.components.TextButton
import joel.scripturememory.ui.components.ToggleRow
import joel.scripturememory.ui.theme.AppLayout
import joel.scripturememory.ui.theme.AppTheme
import joel.scripturememory.ui.theme.AppType
import joel.scripturememory.ui.theme.sizeInDp
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

private sealed class Stage {
    data object Intro : Stage()
    data object Reading : Stage()
    data class Review(val plan: AnkiImportPlan) : Stage()
    data class Failed(val message: String) : Stage()
    data class Done(val summary: AnkiImportSummary) : Stage()
}

private val documentTypes = arrayOf(
    "application/octet-stream",
    "application/zip",
    "application/x-zip-compressed",
    "application/apkg",
    "application/vnd.anki",
    "text/plain",
    "text/csv",
    "text/comma-separated-values",
    "text/tab-separated-values",
)

@Composable
fun AnkiImportSheet(initialFile: File? = null, onDismiss: () -> Unit) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var stage by remember { mutableStateOf(if (initialFile != null) Stage.Reading else Stage.Intro) }
    val includes = remember { mutableStateListOf<Boolean>() }
    val names = remember { mutableStateListOf<TextFieldValue>() }
    var includeMatches by remember { mutableStateOf(true) }
    var showsSkipped by remember { mutableStateOf(false) }

    fun read(load: () -> File) {
        stage = Stage.Reading
        scope.launch {
            val result = withContext(Dispatchers.IO) {
                runCatching {
                    val file = load()
                    try {
                        val source = AnkiImport.read(file)
                        AnkiImporter.plan(source)
                    } finally {
                        file.delete()
                    }
                }
            }
            stage = result.fold(
                onSuccess = { plan ->
                    if (plan.decks.isEmpty() && plan.matches.isEmpty()) {
                        Stage.Failed("No notes have a reference like Romans 8:28.")
                    } else {
                        includes.clear()
                        includes.addAll(plan.decks.map { true })
                        names.clear()
                        names.addAll(plan.decks.map { TextFieldValue(it.name, TextRange(it.name.length)) })
                        Stage.Review(plan)
                    }
                },
                onFailure = { Stage.Failed(message(it)) },
            )
        }
    }

    val chooser = rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument()) { uri ->
        if (uri != null) read { OpenedFile.copyToCache(context, uri) }
    }

    LaunchedEffect(Unit) { initialFile?.let { file -> read { file } } }

    fun apply(plan: AnkiImportPlan) {
        val choices = plan.decks.indices.map { AnkiImporter.DeckChoice(includes[it], names[it].text) }
        val summary = AnkiImporter.apply(plan, choices, includeMatches)
        Analytics.log(AnalyticsEvent.AnkiImported(summary.versesAdded, summary.progressCarried, summary.matchedBundled))
        HapticEngine.success()
        stage = Stage.Done(summary)
    }

    AppSheet(onDismiss = onDismiss, fullHeight = true, dismissDisabled = stage is Stage.Review) { sheet ->
        val current = stage
        SheetHeader(
            "Import from Anki",
            leading = {
                if (current !is Stage.Done) TextButton("Cancel", style = AppType.body, onClick = sheet.dismiss)
            },
            trailing = {
                val bold = AppType.body.copy(fontWeight = FontWeight.SemiBold)
                when (current) {
                    is Stage.Review -> TextButton(
                        "Import",
                        enabled = includes.any { it } || (includeMatches && current.plan.matches.isNotEmpty()),
                        style = bold,
                        onClick = { apply(current.plan) },
                    )
                    is Stage.Done -> TextButton("Done", style = bold, onClick = sheet.dismiss)
                    else -> Unit
                }
            },
        )
        when (current) {
            Stage.Reading -> Box(Modifier.weight(1f).fillMaxSize(), contentAlignment = Alignment.Center) {
                ProgressPanel("Reading…")
            }
            Stage.Intro -> {
                ScrollingSections { Intro() }
                PrimaryButton(
                    "Choose File",
                    Modifier.padding(horizontal = AppLayout.screenMargin).padding(top = 8.dp, bottom = 8.dp),
                    onClick = { chooser.launch(documentTypes) },
                )
            }
            is Stage.Failed -> Box(Modifier.weight(1f).fillMaxSize(), contentAlignment = Alignment.Center) {
                ContentUnavailable(
                    icon = R.drawable.ic_file,
                    title = "Couldn’t Read This File",
                    description = current.message,
                    actions = {
                        PrimaryButton(
                            "Choose Another File",
                            Modifier.width(IntrinsicSize.Max),
                            onClick = { chooser.launch(documentTypes) },
                        )
                    },
                )
            }
            else -> ScrollingSections {
                when (current) {
                    is Stage.Review -> Review(
                        plan = current.plan,
                        includes = includes,
                        names = names,
                        includeMatches = includeMatches,
                        onIncludeMatches = { includeMatches = it },
                        showsSkipped = showsSkipped,
                        onToggleSkipped = { showsSkipped = !showsSkipped },
                    )
                    is Stage.Done -> Done(current.summary)
                    else -> Unit
                }
            }
        }
    }
}

@Composable
private fun ColumnScope.ScrollingSections(content: @Composable () -> Unit) {
    Column(
        Modifier
            .weight(1f)
            .fillMaxWidth()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = AppLayout.screenMargin)
            .padding(top = 8.dp, bottom = 24.dp),
        verticalArrangement = Arrangement.spacedBy(AppLayout.spacing * 1.5f),
    ) { content() }
}

@Composable
private fun Intro() {
    val colors = AppTheme.colors
    Column(
        Modifier.fillMaxWidth().padding(horizontal = AppLayout.panelPadding, vertical = 8.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Icon(R.drawable.ic_download, size = AppType.largeTitle.sizeInDp().dp * 1.2f, tint = colors.accent)
        Text(
            "Bring Your Deck",
            Modifier.semantics { heading() },
            style = AppType.title2,
            color = colors.label,
            textAlign = TextAlign.Center,
        )
        Text(
            "Your review history comes too.",
            style = AppType.body,
            color = colors.secondaryLabel,
            textAlign = TextAlign.Center,
        )
    }
    GroupedSection(
        title = "Export from Anki",
        footer = "Works with AnkiMobile, AnkiDroid and desktop Anki.",
    ) {
        val steps = listOf(
            "Choose your deck, then Export.",
            "Pick Anki Deck Package, with scheduling.",
            "Save to Files, then choose it below.",
        )
        steps.forEachIndexed { i, step ->
            if (i > 0) RowDivider()
            ListRow(step, leading = { StepNumber(i + 1) })
        }
    }
}

@Composable
private fun Review(
    plan: AnkiImportPlan,
    includes: MutableList<Boolean>,
    names: MutableList<TextFieldValue>,
    includeMatches: Boolean,
    onIncludeMatches: (Boolean) -> Unit,
    showsSkipped: Boolean,
    onToggleSkipped: () -> Unit,
) {
    val colors = AppTheme.colors
    plan.decks.forEachIndexed { i, deck ->
        if (i >= includes.size || i >= names.size) return@forEachIndexed
        val withProgress = deck.verses.count { it.hasProgress }
        val count = if (deck.verses.size == 1) "1 verse" else "${deck.verses.size} verses"
        GroupedSection(
            title = deck.name,
            footer = count + if (withProgress > 0) " · $withProgress with history" else "",
        ) {
            ToggleRow("Import as Pack", checked = includes[i], onCheckedChange = { includes[i] = it })
            if (includes[i]) {
                RowDivider()
                LabeledFieldRow(
                    "Pack Name",
                    value = names[i],
                    onValueChange = { names[i] = it },
                    placeholder = UserPack.defaultName,
                    textColor = colors.accent,
                    keyboardOptions = KeyboardOptions(capitalization = KeyboardCapitalization.Words),
                )
                deck.verses.firstOrNull()?.let { first ->
                    RowDivider()
                    Column(
                        Modifier
                            .fillMaxWidth()
                            .padding(horizontal = AppLayout.panelPadding, vertical = 12.dp),
                        verticalArrangement = Arrangement.spacedBy(2.dp),
                    ) {
                        Text(first.reference.display, style = AppType.body, color = colors.label)
                        Text(first.text, style = AppType.subheadline, color = colors.secondaryLabel, maxLines = 2)
                    }
                }
            }
        }
    }
    if (plan.matches.isNotEmpty()) {
        GroupedSection(
            title = if (plan.matches.size == 1) "1 verse already in the app" else "${plan.matches.size} verses already in the app",
            footer = "They’re TMS or DEP cards, so they won’t be added twice.",
        ) {
            ToggleRow("Keep Anki Progress", checked = includeMatches, onCheckedChange = onIncludeMatches)
        }
    }
    if (plan.skipped.isNotEmpty()) {
        GroupedSection {
            DisclosureRow(
                if (plan.skipped.size == 1) "1 note has no reference" else "${plan.skipped.size} notes have no reference",
                expanded = showsSkipped,
                onToggle = onToggleSkipped,
            )
            if (showsSkipped) {
                plan.skipped.take(50).forEach { front ->
                    RowDivider()
                    Text(
                        front.ifEmpty { "Empty note" },
                        Modifier.fillMaxWidth().padding(horizontal = AppLayout.panelPadding, vertical = 10.dp),
                        style = AppType.subheadline,
                        color = colors.secondaryLabel,
                        maxLines = 2,
                    )
                }
            }
        }
    }
}

@Composable
private fun Done(summary: AnkiImportSummary) {
    GroupedSection(footer = "Known cards come up in Daily Review when due.") {
        val rows = buildList {
            if (summary.versesAdded > 0) {
                add("Verses added" to "${summary.versesAdded}")
                add((if (summary.packsCreated == 1) "New pack" else "New packs") to "${summary.packsCreated}")
            }
            if (summary.matchedBundled > 0) add("TMS & DEP cards updated" to "${summary.matchedBundled}")
            add("History kept" to "${summary.progressCarried}")
        }
        rows.forEachIndexed { i, (title, value) ->
            if (i > 0) RowDivider()
            ListRow(title, value = value)
        }
    }
}

private fun message(error: Throwable): String = when (error) {
    AnkiImportException.Empty -> "This deck is empty."
    else -> "Export it again as an Anki Deck Package (.apkg)."
}
