package joel.scripturememory.ui.components

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.ScrollState
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.asPaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyListScope
import androidx.compose.foundation.lazy.LazyListState
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.runtime.Composable
import androidx.compose.runtime.compositionLocalOf
import androidx.compose.runtime.derivedStateOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import joel.scripturememory.R
import joel.scripturememory.ui.theme.AppLayout
import joel.scripturememory.ui.theme.AppMotion
import joel.scripturememory.ui.theme.AppTheme
import joel.scripturememory.ui.theme.AppType

val BarHeight = 52.dp

val LocalBottomBarPadding = compositionLocalOf { 0.dp }

@Composable
fun BackChevronButton(onBack: () -> Unit) {
    ChromeIconButton(R.drawable.ic_caret_left, "Back", size = 40.dp, iconSize = 16.dp, onClick = onBack)
}

@Composable
fun TopBar(
    title: String?,
    modifier: Modifier = Modifier,
    subtitle: String? = null,
    showsBackground: Boolean = true,
    titleAlpha: Float = 1f,
    onBack: (() -> Unit)? = null,
    leading: (@Composable RowScope.() -> Unit)? = null,
    actions: (@Composable RowScope.() -> Unit)? = null,
) {
    val colors = AppTheme.colors
    val backgroundAlpha by animateFloatAsState(if (showsBackground) 1f else 0f, AppMotion.content(), label = "barBackground")
    Box(
        modifier
            .fillMaxWidth()
            .background(colors.chrome.copy(alpha = colors.chrome.alpha * backgroundAlpha))
            .statusBarsPadding(),
    ) {
        Box(Modifier.fillMaxWidth().height(BarHeight).padding(horizontal = 12.dp)) {
            Row(
                Modifier.align(Alignment.CenterStart),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                if (onBack != null) BackChevronButton(onBack)
                if (leading != null) leading()
            }
            if (title != null) {
                Column(
                    Modifier
                        .align(Alignment.Center)
                        .padding(horizontal = 96.dp)
                        .graphicsLayer { alpha = titleAlpha },
                    horizontalAlignment = Alignment.CenterHorizontally,
                ) {
                    Text(title, style = AppType.headline, color = colors.label, maxLines = 1)
                    if (subtitle != null) {
                        Text(subtitle, style = AppType.caption, color = colors.secondaryLabel, maxLines = 1)
                    }
                }
            }
            Row(
                Modifier.align(Alignment.CenterEnd),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                if (actions != null) actions()
            }
        }
        if (showsBackground && titleAlpha > 0.5f) Divider(Modifier.align(Alignment.BottomCenter))
    }
}

@Composable
fun LargeTitle(title: String, modifier: Modifier = Modifier) {
    Text(
        title,
        modifier
            .padding(horizontal = 20.dp)
            .padding(top = 4.dp, bottom = 12.dp)
            .semantics { heading() },
        style = AppType.largeTitle,
        color = AppTheme.colors.label,
    )
}

@Composable
fun barContentTop(): Dp = WindowInsets.statusBars.asPaddingValues().calculateTopPadding() + BarHeight

@Composable
fun LargeTitleList(
    title: String,
    modifier: Modifier = Modifier,
    state: LazyListState = rememberLazyListState(),
    onBack: (() -> Unit)? = null,
    actions: (@Composable RowScope.() -> Unit)? = null,
    contentPadding: PaddingValues = PaddingValues(horizontal = AppLayout.screenMargin),
    verticalSpacing: Dp = AppLayout.spacing,
    content: LazyListScope.() -> Unit,
) {
    val collapsed by remember {
        derivedStateOf { state.firstVisibleItemIndex > 0 || state.firstVisibleItemScrollOffset > 44 }
    }
    val titleAlpha by animateFloatAsState(if (collapsed) 1f else 0f, AppMotion.control(), label = "titleAlpha")
    Box(modifier.fillMaxSize().background(AppTheme.colors.background)) {
        LazyColumn(
            state = state,
            modifier = Modifier.fillMaxSize(),
            contentPadding = PaddingValues(
                top = barContentTop(),
                bottom = LocalBottomBarPadding.current + 24.dp,
            ),
            verticalArrangement = Arrangement.spacedBy(verticalSpacing),
        ) {
            item(key = "largeTitle") { LargeTitle(title) }
            item(key = "contentPaddingGuard") { Box(Modifier.height(0.dp)) }
            content()
        }
        TopBar(title, showsBackground = collapsed, titleAlpha = titleAlpha, onBack = onBack, actions = actions)
    }
}

@Composable
fun LargeTitleColumn(
    title: String,
    modifier: Modifier = Modifier,
    scrollState: ScrollState = rememberScrollState(),
    onBack: (() -> Unit)? = null,
    actions: (@Composable RowScope.() -> Unit)? = null,
    maxContentWidth: Dp = AppLayout.readableWidth,
    content: @Composable ColumnScope.() -> Unit,
) {
    val collapsed by remember { derivedStateOf { scrollState.value > 120 } }
    val titleAlpha by animateFloatAsState(if (collapsed) 1f else 0f, AppMotion.control(), label = "titleAlpha")
    Box(modifier.fillMaxSize().background(AppTheme.colors.background)) {
        Column(
            Modifier
                .fillMaxSize()
                .verticalScroll(scrollState)
                .padding(top = barContentTop(), bottom = LocalBottomBarPadding.current + 24.dp),
        ) {
            Column(Modifier.readableColumn(maxContentWidth)) {
                LargeTitle(title)
                Column(
                    Modifier.padding(horizontal = AppLayout.screenMargin),
                    verticalArrangement = Arrangement.spacedBy(AppLayout.spacing),
                    content = content,
                )
            }
        }
        TopBar(title, showsBackground = collapsed, titleAlpha = titleAlpha, onBack = onBack, actions = actions)
    }
}

@Composable
fun InlineScreen(
    title: String?,
    modifier: Modifier = Modifier,
    subtitle: String? = null,
    onBack: (() -> Unit)? = null,
    leading: (@Composable RowScope.() -> Unit)? = null,
    actions: (@Composable RowScope.() -> Unit)? = null,
    bottomBar: (@Composable () -> Unit)? = null,
    content: @Composable BoxScope.() -> Unit,
) {
    Column(modifier.fillMaxSize().background(AppTheme.colors.background)) {
        TopBar(title, subtitle = subtitle, onBack = onBack, leading = leading, actions = actions)
        Box(Modifier.weight(1f).fillMaxWidth(), content = content)
        if (bottomBar != null) Box(Modifier.imePadding()) { bottomBar() }
    }
}
