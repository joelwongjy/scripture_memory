package joel.scripturememory.ui.components

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyListScope
import androidx.compose.foundation.lazy.LazyListState
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.derivedStateOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import joel.scripturememory.ui.theme.AppLayout
import joel.scripturememory.ui.theme.AppMotion
import joel.scripturememory.ui.theme.AppTheme

@Composable
fun ReadableList(
    title: String,
    modifier: Modifier = Modifier,
    state: LazyListState = rememberLazyListState(),
    showsLargeTitle: Boolean = false,
    onBack: (() -> Unit)? = null,
    actions: (@Composable RowScope.() -> Unit)? = null,
    maxContentWidth: Dp = AppLayout.readableWidth,
    verticalSpacing: Dp = AppLayout.spacing,
    content: LazyListScope.() -> Unit,
) {
    val scrolled by remember { derivedStateOf { state.canScrollBackward } }
    val collapsed by remember {
        derivedStateOf { state.firstVisibleItemIndex > 0 || state.firstVisibleItemScrollOffset > 44 }
    }
    val titleAlpha by animateFloatAsState(
        if (!showsLargeTitle || collapsed) 1f else 0f,
        AppMotion.control(),
        label = "titleAlpha",
    )
    BoxWithConstraints(modifier.fillMaxSize().background(AppTheme.colors.background)) {
        val margin = ((maxWidth - maxContentWidth) / 2).coerceAtLeast(AppLayout.screenMargin)
        LazyColumn(
            state = state,
            modifier = Modifier.fillMaxSize(),
            contentPadding = PaddingValues(
                start = margin,
                end = margin,
                top = barContentTop() + if (showsLargeTitle) 0.dp else 8.dp,
                bottom = LocalBottomBarPadding.current + 24.dp,
            ),
            verticalArrangement = Arrangement.spacedBy(verticalSpacing),
        ) {
            if (showsLargeTitle) item(key = "largeTitle") { LargeTitle(title, Modifier.offset(x = -AppLayout.screenMargin)) }
            content()
        }
        TopBar(
            title,
            showsBackground = if (showsLargeTitle) collapsed else scrolled,
            titleAlpha = titleAlpha,
            onBack = onBack,
            actions = actions,
        )
    }
}
