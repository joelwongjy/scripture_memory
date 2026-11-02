package joel.scripturememory.ui.search

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyListScope
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import joel.scripturememory.R
import joel.scripturememory.model.FavoritesStore
import joel.scripturememory.model.VerseSearchGroup
import joel.scripturememory.model.VerseSearchResult
import joel.scripturememory.ui.components.ContentUnavailable
import joel.scripturememory.ui.components.Icon
import joel.scripturememory.ui.components.RowChevron
import joel.scripturememory.ui.components.RowDivider
import joel.scripturememory.ui.components.Text
import joel.scripturememory.ui.components.VerseRowLabel
import joel.scripturememory.ui.components.groupedPanel
import joel.scripturememory.ui.components.groupedRow
import joel.scripturememory.ui.components.pressable
import joel.scripturememory.ui.components.readableColumn
import joel.scripturememory.ui.theme.AppLayout
import joel.scripturememory.ui.theme.AppTheme
import joel.scripturememory.ui.theme.AppType

fun LazyListScope.verseSearchSections(
    query: String,
    results: List<VerseSearchResult>,
    onSelect: (VerseSearchResult) -> Unit,
) {
    VerseSearchGroup.grouping(results).forEach { group ->
        item(key = "pack-${group.id}") {
            Text(
                group.pack.name,
                Modifier
                    .animateItem()
                    .padding(start = AppLayout.panelPadding, end = AppLayout.panelPadding, top = 18.dp, bottom = 8.dp),
                style = AppType.headline,
                color = AppTheme.colors.secondaryLabel,
            )
        }
        itemsIndexed(group.results, key = { _, result -> result.id }) { index, result ->
            Column(Modifier.animateItem().groupedRow(index, group.results.size)) {
                VerseSearchRow(result, query) { onSelect(result) }
                if (index < group.results.lastIndex) RowDivider()
            }
        }
    }
}

@Composable
fun VerseSearchResultsList(
    query: String,
    results: List<VerseSearchResult>,
    modifier: Modifier = Modifier,
    onSelect: (VerseSearchResult) -> Unit,
) {
    Column(modifier.readableColumn().padding(horizontal = AppLayout.screenMargin).padding(bottom = 16.dp)) {
        if (results.isEmpty()) {
            Box(Modifier.fillMaxWidth().padding(top = 48.dp), contentAlignment = Alignment.Center) {
                VerseSearchNoResults(query)
            }
            return@Column
        }
        VerseSearchGroup.grouping(results).forEach { group ->
            Text(
                group.pack.name.uppercase(),
                Modifier.padding(start = AppLayout.panelPadding, end = AppLayout.panelPadding, top = 22.dp, bottom = 7.dp),
                style = AppType.footnote,
                color = AppTheme.colors.secondaryLabel,
            )
            Column(Modifier.fillMaxWidth().groupedPanel(), verticalArrangement = Arrangement.Top) {
                group.results.forEachIndexed { index, result ->
                    if (index > 0) RowDivider()
                    VerseSearchRow(result, query) { onSelect(result) }
                }
            }
        }
    }
}

@Composable
fun VerseSearchNoResults(query: String, modifier: Modifier = Modifier) {
    ContentUnavailable(
        R.drawable.ic_magnifying_glass,
        "No Results",
        "No verses match “$query”.",
        modifier,
    )
}

@Composable
private fun VerseSearchRow(result: VerseSearchResult, query: String, onClick: () -> Unit) {
    val colors = AppTheme.colors
    val isFavorite = FavoritesStore.shared.isFavorite(result.verse)
    VerseRowLabel(
        result.verse,
        Modifier
            .fillMaxWidth()
            .pressable(pressedScale = 1f, pressedAlpha = 0.55f, onClick = onClick)
            .padding(horizontal = AppLayout.panelPadding, vertical = 11.dp),
        showsPreview = true,
        highlight = query,
        trailing = {
            if (isFavorite) {
                Icon(R.drawable.ic_star_fill, size = 15.dp, tint = colors.yellow, contentDescription = "Favourite")
            }
            RowChevron()
        },
    )
}
