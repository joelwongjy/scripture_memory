package joel.scripturememory.ui.packs

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.width
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import joel.scripturememory.model.Pack
import joel.scripturememory.ui.theme.AppLayout

@Composable
fun PackCover(
    pack: Pack,
    modifier: Modifier = Modifier,
    isCurrentPack: Boolean = false,
    cornerRadius: Dp = AppLayout.cardRadius,
    showsShadow: Boolean = true,
) {
    Box(modifier.aspectRatio(AppLayout.cardAspect).background(Color.Gray))
}

@Composable
fun PackBadge(pack: Pack, modifier: Modifier = Modifier, width: Dp = 46.dp) {
    PackCover(pack, modifier.width(width), cornerRadius = width * 0.09f, showsShadow = false)
}
