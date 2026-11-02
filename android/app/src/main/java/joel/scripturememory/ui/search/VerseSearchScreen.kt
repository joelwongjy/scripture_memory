package joel.scripturememory.ui.search

import androidx.compose.foundation.background
import androidx.compose.foundation.interaction.DragInteraction
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.ime
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.TextFieldValue
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import joel.scripturememory.R
import joel.scripturememory.model.AnalyticsEvent
import joel.scripturememory.model.AnalyticsScreen
import joel.scripturememory.model.BibleVersion
import joel.scripturememory.model.PackPreferencesStore
import joel.scripturememory.model.VerseSearch
import joel.scripturememory.model.VerseSearchResult
import joel.scripturememory.system.Analytics
import joel.scripturememory.ui.components.AppTextField
import joel.scripturememory.ui.components.ContentUnavailable
import joel.scripturememory.ui.components.Icon
import joel.scripturememory.ui.components.LocalBottomBarPadding
import joel.scripturememory.ui.components.LocalCovers
import joel.scripturememory.ui.components.ReadableList
import joel.scripturememory.ui.components.TrackScreen
import joel.scripturememory.ui.components.barContentTop
import joel.scripturememory.ui.components.dimOnPress
import joel.scripturememory.ui.components.hairlineBorder
import joel.scripturememory.ui.components.readableColumn
import joel.scripturememory.ui.components.softShadow
import joel.scripturememory.ui.pouch.PouchScreen
import joel.scripturememory.ui.theme.AppLayout
import joel.scripturememory.ui.theme.AppTheme
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.filterIsInstance
import kotlinx.coroutines.withContext

private const val foundNothingDelayMillis = 1500L
private val fieldHeight = 48.dp
private val fieldGap = 10.dp
private val FieldShape = RoundedCornerShape(percent = 50)

@Composable
fun VerseSearchScreen() {
    TrackScreen(AnalyticsScreen.search)
    val covers = LocalCovers.current
    val focus = LocalFocusManager.current
    val focusRequester = remember { FocusRequester() }
    val listState = rememberLazyListState()
    var field by rememberSaveable(stateSaver = TextFieldValue.Saver) { mutableStateOf(TextFieldValue()) }
    val searchText = field.text
    val packs = PackPreferencesStore.shared.visible(BibleVersion.saved().packs)
    val results = remember(searchText, packs) { VerseSearch.results(searchText, packs) }

    val density = LocalDensity.current
    val keyboard = with(density) { WindowInsets.ime.getBottom(this).toDp() }
    val tabBar = LocalBottomBarPadding.current
    val fieldBottom = maxOf(tabBar, keyboard) + fieldGap
    val listBottom = fieldBottom + fieldHeight

    fun open(result: VerseSearchResult) {
        VerseSearch.logOpened(result, results, Analytics::log)
        focus.clearFocus()
        covers.present("pack-${result.pack.id}-${result.verseIndex}") { dismiss ->
            PouchScreen(result.pack, result.verseIndex, animatesPouch = false, onClosed = dismiss)
        }
    }

    LaunchedEffect(packs) { withContext(Dispatchers.Default) { VerseSearch.prewarm(packs) } }
    LaunchedEffect(Unit) { focusRequester.requestFocus() }
    LaunchedEffect(listState) {
        listState.interactionSource.interactions
            .filterIsInstance<DragInteraction.Start>()
            .collect { focus.clearFocus() }
    }
    LaunchedEffect(searchText) {
        listState.scrollToItem(0)
        if (searchText.isEmpty()) return@LaunchedEffect
        delay(foundNothingDelayMillis)
        Analytics.log(AnalyticsEvent.SearchPerformed(results.size))
        if (results.isEmpty()) Analytics.log(AnalyticsEvent.SearchFoundNothing)
    }

    Box(Modifier.fillMaxSize()) {
        CompositionLocalProvider(LocalBottomBarPadding provides listBottom) {
            ReadableList("Search", state = listState, showsLargeTitle = true, verticalSpacing = 0.dp) {
                verseSearchSections(searchText, results, ::open)
            }
        }
        Box(
            Modifier.fillMaxSize().padding(top = barContentTop(), bottom = listBottom),
            contentAlignment = Alignment.Center,
        ) {
            if (searchText.isEmpty()) {
                ContentUnavailable(
                    R.drawable.ic_magnifying_glass,
                    "Search Verses",
                    "Find a verse by its words, reference or title.",
                )
            } else if (results.isEmpty()) {
                VerseSearchNoResults(searchText)
            }
        }
        SearchField(
            value = field,
            onValueChange = { field = it },
            bottom = fieldBottom,
            focusRequester = focusRequester,
            onSearch = focus::clearFocus,
            modifier = Modifier.align(Alignment.BottomCenter),
        )
    }
}

@Composable
private fun SearchField(
    value: TextFieldValue,
    onValueChange: (TextFieldValue) -> Unit,
    bottom: Dp,
    focusRequester: FocusRequester,
    onSearch: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val colors = AppTheme.colors
    Box(modifier.readableColumn().padding(horizontal = AppLayout.screenMargin).padding(bottom = bottom)) {
        Row(
            Modifier
                .fillMaxWidth()
                .height(fieldHeight)
                .softShadow(FieldShape, 8.dp)
                .clip(FieldShape)
                .background(colors.panelRaised)
                .hairlineBorder(FieldShape)
                .padding(start = 16.dp, end = 6.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            Icon(R.drawable.ic_magnifying_glass, size = 20.dp, tint = colors.secondaryLabel)
            AppTextField(
                value = value,
                onValueChange = onValueChange,
                modifier = Modifier.weight(1f).focusRequester(focusRequester),
                placeholder = "Search verses",
                keyboardOptions = KeyboardOptions(imeAction = ImeAction.Search),
                keyboardActions = KeyboardActions(onSearch = { onSearch() }),
            )
            if (value.text.isNotEmpty()) {
                Box(
                    Modifier
                        .size(36.dp)
                        .semantics { contentDescription = "Clear search" }
                        .dimOnPress { onValueChange(TextFieldValue()) },
                    contentAlignment = Alignment.Center,
                ) {
                    Box(
                        Modifier.size(20.dp).clip(CircleShape).background(colors.tertiaryLabel),
                        contentAlignment = Alignment.Center,
                    ) {
                        Icon(R.drawable.ic_x, size = 11.dp, tint = colors.panelRaised)
                    }
                }
            }
        }
    }
}
