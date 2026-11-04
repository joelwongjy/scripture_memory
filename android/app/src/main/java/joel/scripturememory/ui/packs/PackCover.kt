package joel.scripturememory.ui.packs

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.TextAutoSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.clipToBounds
import androidx.compose.ui.draw.dropShadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.TransformOrigin
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.shadow.Shadow
import androidx.compose.ui.layout.Layout
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.PlatformTextStyle
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextGeometricTransform
import androidx.compose.ui.unit.Constraints
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.DpOffset
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import joel.scripturememory.R
import joel.scripturememory.model.FavoritesStore
import joel.scripturememory.model.Pack
import joel.scripturememory.model.UserPack
import joel.scripturememory.model.VerseNumbering
import joel.scripturememory.ui.components.Icon
import joel.scripturememory.ui.components.Text
import joel.scripturememory.ui.theme.AppLayout
import joel.scripturememory.ui.theme.AppTheme
import joel.scripturememory.ui.theme.InterDisplay
import joel.scripturememory.ui.theme.InterText
import joel.scripturememory.ui.theme.SerifFamily

private val designWidth = 340.dp
private val designHeight = 204.dp
private val contentInset = 28.dp

private val coverWhite = Color.White
private val tmsPanel = Color(0.98f, 0.97f, 0.95f)
private val systemGreen = Color(0xFF34C759)
private val coverSeparator = Color(0x4A3C3C43)

private val DefaultCoverShadowRadius = 8.dp

private val Pack.isDEP: Boolean get() = name.startsWith("DEP")
private val Pack.isTMS180: Boolean get() = name.startsWith("TMS 180")
private val Pack.isFavorites: Boolean get() = name == FavoritesStore.packName
private val Pack.baseColor: Color get() = (colorFromHex(color) ?: Color(0xFF8E8E93)).muted

private val Pack.displayTitle: String
    get() = if (isDEP) name.replace("DEP ", "").replace(": ", ". ") else name

private val Pack.borderColor: Color
    get() = when {
        isDEP -> if (fieldIsLight) coverSeparator.copy(alpha = coverSeparator.alpha * 0.5f) else Color.White.copy(alpha = 0.08f)
        name == "TMS 60" -> coverSeparator.copy(alpha = coverSeparator.alpha * 0.3f)
        else -> Color.Transparent
    }

private val Pack.shadowOpacity: Float get() = if (name == "TMS 60") 0.08f else 0.12f

private val Pack.depGold: Color
    get() {
        if (fieldIsLight) return Color(0.91f, 0.83f, 0.78f)
        val degrees = fieldColor.hueDegrees
        return if (degrees in 185f..300f) fieldColor.lightened(0.62f) else Color(0.94f, 0.86f, 0.55f)
    }

private val Pack.seriesLabel: String
    get() {
        val number = VerseNumbering.packCode(name).split("S").lastOrNull().orEmpty()
        return if (number.isEmpty()) "" else "series $number"
    }

private val Pack.seriesTitle: String get() = name.split(" · ").last()

private fun type(
    size: Float,
    weight: FontWeight = FontWeight.Normal,
    family: FontFamily = InterText,
    italic: Boolean = false,
    tracking: Float = 0f,
    line: Float? = null,
) = TextStyle(
    fontFamily = family,
    fontSize = size.sp,
    fontWeight = weight,
    fontStyle = if (italic) FontStyle.Italic else FontStyle.Normal,
    letterSpacing = tracking.sp,
    lineHeight = line?.sp ?: androidx.compose.ui.unit.TextUnit.Unspecified,
    platformStyle = PlatformTextStyle(includeFontPadding = false),
)

@Composable
fun PackCover(
    pack: Pack,
    modifier: Modifier = Modifier,
    isCurrentPack: Boolean = false,
    cornerRadius: Dp = AppLayout.cardRadius,
    showsShadow: Boolean = true,
) {
    val shape = RoundedCornerShape(cornerRadius)
    val density = LocalDensity.current
    val locked = remember(density) { Density(density.density, 1f) }
    val border = pack.borderColor
    CompositionLocalProvider(LocalDensity provides locked) {
        Box(modifier.aspectRatio(AppLayout.cardAspect)) {
            Box(
                Modifier
                    .matchParentSize()
                    .then(
                        if (showsShadow) {
                            Modifier.dropShadow(
                                shape,
                                Shadow(
                                    radius = DefaultCoverShadowRadius * ShadowRadiusScale,
                                    color = Color.Black,
                                    alpha = pack.shadowOpacity,
                                    offset = DpOffset(0.dp, 4.dp),
                                ),
                            )
                        } else {
                            Modifier
                        },
                    )
                    .clip(shape)
                    .then(if (border.alpha > 0f) Modifier.border(0.5.dp, border, shape) else Modifier),
            ) {
                CoverCanvas { CoverContent(pack) }
            }
            if (isCurrentPack) CurrentPackBadge(Modifier.align(Alignment.TopEnd).padding(8.dp))
        }
    }
}

internal const val ShadowRadiusScale = 1.73f

@Composable
fun PackBadge(pack: Pack, modifier: Modifier = Modifier, width: Dp = 46.dp) {
    PackCover(
        pack,
        modifier.width(width).height(width / AppLayout.cardAspect),
        cornerRadius = width * 0.09f,
        showsShadow = false,
    )
}

@Composable
private fun CoverCanvas(content: @Composable () -> Unit) {
    Layout(content, Modifier.fillMaxSize().clipToBounds()) { measurables, constraints ->
        val w = designWidth.roundToPx()
        val h = designHeight.roundToPx()
        val placeable = measurables.first().measure(Constraints.fixed(w, h))
        val scale = constraints.maxWidth.toFloat() / w
        layout(constraints.maxWidth, constraints.maxHeight) {
            placeable.placeWithLayer(0, 0) {
                scaleX = scale
                scaleY = scale
                transformOrigin = TransformOrigin(0f, 0f)
            }
        }
    }
}

@Composable
private fun CurrentPackBadge(modifier: Modifier = Modifier) {
    val accent = AppTheme.colors.accent
    val capsule = RoundedCornerShape(percent = 50)
    Row(
        modifier
            .dropShadow(
                capsule,
                Shadow(
                    radius = 3.dp * ShadowRadiusScale,
                    color = Color.Black,
                    alpha = 0.18f,
                    offset = DpOffset(0.dp, 1.dp),
                ),
            )
            .clip(capsule)
            .background(coverWhite)
            .padding(horizontal = 8.dp, vertical = 4.dp)
            .semantics { contentDescription = "Current pack" },
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(3.dp),
    ) {
        Icon(R.drawable.ic_bookmark_fill, size = 11.dp, tint = accent)
        Text("Current", style = type(10f, FontWeight.Bold), color = accent, maxLines = 1)
    }
}

@Composable
private fun CoverContent(pack: Pack) {
    when {
        pack.isUserMade -> OyoCover(pack)
        pack.isFavorites -> FavoritesCover(pack)
        pack.isDEP -> DepCover(pack)
        pack.isTMS180 -> Tms180Cover(pack)
        pack.name == "TMS 60" -> TmsCover(pack)
        pack.name == "5 Assurances" -> AssurancesCover(pack)
        else -> GenericCover(pack)
    }
}

@Composable
private fun AssurancesCover(pack: Pack) {
    val field = pack.fieldColor
    val band = field.darkened(0.34f)
    Box(Modifier.fillMaxSize().background(field)) {
        Canvas(
            Modifier
                .align(Alignment.Center)
                .offset(x = 78.dp, y = (-4).dp)
                .size(168.dp, 132.dp),
        ) {
            drawPath(
                leafBranchPath(size),
                Color.White.copy(alpha = 0.42f),
                style = Stroke(width = 1.4.dp.toPx(), cap = StrokeCap.Round),
            )
        }
        Text(
            "5 Assurances",
            Modifier.padding(start = 26.dp, top = 18.dp, end = 110.dp),
            style = type(26f, family = SerifFamily, tracking = 0.5f),
            color = Color.White,
            maxLines = 1,
            autoSize = TextAutoSize.StepBased(18.2.sp, 26.sp, 0.25.sp),
        )
        Row(
            Modifier
                .align(Alignment.BottomCenter)
                .fillMaxWidth()
                .background(band)
                .padding(horizontal = 20.dp, vertical = 11.dp),
            verticalAlignment = Alignment.Bottom,
        ) {
            Text(
                "${pack.verses.size} cards",
                style = type(11f, FontWeight.Medium),
                color = Color.White.copy(alpha = 0.75f),
            )
            Spacer(Modifier.weight(1f).width(8.dp))
            Column(horizontalAlignment = Alignment.End, verticalArrangement = Arrangement.spacedBy((-1).dp)) {
                Text(
                    "Growing in",
                    style = type(9f, family = SerifFamily, line = 11f),
                    color = Color.White.copy(alpha = 0.75f),
                )
                Text(
                    "CHRIST",
                    style = type(16f, FontWeight.Bold, SerifFamily, tracking = 1.5f, line = 19f),
                    color = Color.White,
                )
                Text(
                    "Series",
                    style = type(9f, family = SerifFamily, line = 11f),
                    color = Color.White.copy(alpha = 0.75f),
                )
            }
        }
    }
}

@Composable
private fun FavoritesCover(pack: Pack) {
    Box(Modifier.fillMaxSize().background(pack.baseColor)) {
        Icon(
            R.drawable.ic_star_fill,
            Modifier.align(Alignment.Center).offset(x = 95.dp, y = 10.dp),
            size = 170.dp,
            tint = Color.White.copy(alpha = 0.1f),
        )
        Column(Modifier.fillMaxSize().padding(18.dp), verticalArrangement = Arrangement.spacedBy(5.dp)) {
            Icon(R.drawable.ic_star_fill, size = 24.dp, tint = Color.White.copy(alpha = 0.9f))
            Text(
                pack.name,
                style = type(20f, FontWeight.Bold, SerifFamily),
                color = Color.White,
                maxLines = 2,
                autoSize = TextAutoSize.StepBased(14.sp, 20.sp, 0.25.sp),
            )
            Spacer(Modifier.weight(1f))
            Text(
                "${pack.verses.size} starred",
                style = type(12f, FontWeight.Medium),
                color = Color.White.copy(alpha = 0.65f),
            )
        }
    }
}

@Composable
private fun DepCover(pack: Pack) {
    val field = pack.fieldColor
    val ink = pack.inkColor
    val gold = pack.depGold
    Box(Modifier.fillMaxSize().background(field)) {
        Text(
            pack.displayTitle,
            Modifier.padding(start = contentInset, end = contentInset, top = 18.dp),
            style = type(25f, FontWeight.Medium, InterDisplay, tracking = 0.1f),
            color = ink,
            maxLines = 2,
            autoSize = TextAutoSize.StepBased(17.5.sp, 25.sp, 0.25.sp),
        )
        OutlinedText(
            "242",
            type(64f, FontWeight.Black, InterDisplay, italic = true),
            stroke = gold,
            fill = field,
            modifier = Modifier.align(Alignment.BottomEnd).padding(end = contentInset, bottom = 6.dp),
            width = 1.5.dp,
        )
        Text(
            "DEP",
            Modifier.align(Alignment.BottomEnd).padding(end = contentInset + 59.dp, bottom = 62.dp),
            style = type(42f, FontWeight.Black, InterDisplay, italic = true, tracking = -1.1f),
            color = gold,
            maxLines = 1,
        )
        Text(
            "NIV",
            Modifier.align(Alignment.BottomEnd).padding(end = contentInset + 3.dp, bottom = 74.dp),
            style = type(13f, FontWeight.Bold, SerifFamily, italic = true),
            color = gold,
            maxLines = 1,
        )
        Column(
            Modifier.align(Alignment.BottomStart).padding(start = contentInset, bottom = 15.dp),
            verticalArrangement = Arrangement.spacedBy(2.dp),
        ) {
            NavigatorsMark(ink)
            Text(
                "${pack.verses.size} cards",
                Modifier.alpha(0.8f),
                style = type(10f),
                color = ink,
            )
        }
    }
}

@Composable
private fun NavigatorsMark(ink: Color) {
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
        Icon(R.drawable.ic_moon_fill, size = 13.dp, tint = ink)
        Text("THE NAVIGATORS", style = type(12f, FontWeight.Medium, tracking = 0.4f), color = ink, maxLines = 1)
    }
}

@Composable
private fun Tms180Cover(pack: Pack) {
    Box(Modifier.fillMaxSize().background(pack.fieldColor)) {
        Column(
            Modifier.fillMaxWidth().padding(start = 20.dp, top = 16.dp, end = 20.dp),
            horizontalAlignment = Alignment.End,
            verticalArrangement = Arrangement.spacedBy(4.dp),
        ) {
            Text(pack.seriesLabel, style = type(15f), color = Color.White.copy(alpha = 0.95f), maxLines = 1)
            Text(
                pack.seriesTitle,
                style = type(30f, FontWeight.Bold, InterDisplay, tracking = -0.2f),
                color = Color.White,
                textAlign = TextAlign.End,
                maxLines = 2,
                autoSize = TextAutoSize.StepBased(18.sp, 30.sp, 0.25.sp),
            )
        }
        Row(
            Modifier
                .align(Alignment.BottomCenter)
                .fillMaxWidth()
                .padding(start = 20.dp, end = 20.dp, bottom = 12.dp),
            verticalAlignment = Alignment.Bottom,
        ) {
            Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                    val tint = Color.White.copy(alpha = 0.92f)
                    Text("네비게이토", style = type(13f, FontWeight.SemiBold), color = tint, maxLines = 1)
                    Icon(R.drawable.ic_moon_fill, size = 12.dp, tint = tint)
                    Text("출판사", style = type(13f, FontWeight.SemiBold), color = tint, maxLines = 1)
                }
                Text(
                    "TO KNOW CHRIST AND TO MAKE HIM KNOWN",
                    style = type(7f, FontWeight.Medium, tracking = 0.2f),
                    color = Color.White.copy(alpha = 0.92f),
                    maxLines = 1,
                )
            }
            Spacer(Modifier.weight(1f))
            Text("${pack.verses.size} cards", style = type(10f), color = Color.White.copy(alpha = 0.7f))
        }
    }
}

@Composable
private fun TmsCover(pack: Pack) {
    val base = pack.baseColor
    val heroDigits = TextStyle(
        fontFamily = InterDisplay,
        fontSize = 104.sp,
        fontWeight = FontWeight.Black,
        fontFeatureSettings = "zero, tnum",
        letterSpacing = (-1).sp,
        textGeometricTransform = TextGeometricTransform(scaleX = 0.87f),
        platformStyle = PlatformTextStyle(includeFontPadding = false),
    )
    Box(Modifier.fillMaxSize().background(tmsPanel)) {
        Text(
            "주제별 성경암송",
            Modifier.offset(x = 52.dp, y = 16.dp),
            style = type(20f, FontWeight.Medium, tracking = 0.4f),
            color = Color.Black,
            maxLines = 1,
        )
        Text("60", Modifier.offset(x = 55.dp, y = 48.dp), style = heroDigits, color = base, maxLines = 1)
        Box(
            Modifier
                .offset(x = 181.dp, y = 58.dp)
                .clip(RoundedCornerShape(percent = 50))
                .background(base)
                .padding(horizontal = 9.dp, vertical = 5.dp),
        ) {
            Text("개역한글판", style = type(14f, FontWeight.SemiBold), color = Color.White, maxLines = 1)
        }
        Text(
            "구절",
            Modifier.offset(x = 180.dp, y = 72.dp),
            style = type(65f, FontWeight.Bold).copy(textGeometricTransform = TextGeometricTransform(scaleX = 0.92f)),
            color = base,
            maxLines = 1,
        )
        Row(
            Modifier
                .align(Alignment.BottomCenter)
                .fillMaxWidth()
                .background(systemGreen.copy(alpha = 0.15f))
                .padding(horizontal = 10.dp, vertical = 7.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(5.dp),
        ) {
            val ink = Color.Black.copy(alpha = 0.78f)
            Text(
                "TO KNOW CHRIST AND TO MAKE HIM KNOWN",
                Modifier.weight(1f),
                style = type(8.5f, family = SerifFamily, tracking = 0.45f),
                color = ink,
                maxLines = 1,
                autoSize = TextAutoSize.StepBased(4.25.sp, 8.5.sp, 0.25.sp),
            )
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                val style = type(10f, FontWeight.SemiBold, tracking = 0.25f)
                Text("네비게이토", style = style, color = ink, maxLines = 1)
                Icon(R.drawable.ic_moon_fill, size = 11.dp, tint = ink)
                Text("출판사", style = style, color = ink, maxLines = 1)
            }
        }
    }
}

@Composable
private fun OyoCover(pack: Pack) {
    val ink = pack.inkColor.copy(alpha = 0.94f)
    Box(Modifier.fillMaxSize().background(pack.fieldColor)) {
        Column(
            Modifier.fillMaxSize().padding(start = contentInset, end = contentInset, top = 16.dp, bottom = 14.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Text(
                "자신만의 성경암송을 위한 빈카드",
                style = type(13f, FontWeight.Medium, tracking = 0.6f),
                color = ink,
                maxLines = 1,
                autoSize = TextAutoSize.StepBased(7.8.sp, 13.sp, 0.25.sp),
            )
            Text(
                "(${UserPack.subtitle} Card)",
                Modifier.padding(top = 2.dp),
                style = type(11f, family = SerifFamily),
                color = ink,
                maxLines = 1,
            )
            Text(
                pack.name,
                Modifier.padding(top = 4.dp),
                style = type(58f, family = SerifFamily),
                color = ink,
                maxLines = 1,
                autoSize = TextAutoSize.StepBased(18.5.sp, 58.sp, 0.5.sp),
            )
            Text("카드", style = type(22f, FontWeight.Bold, tracking = 2f), color = ink, maxLines = 1)
            Spacer(Modifier.weight(1f))
            Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                val footer = type(12f, FontWeight.SemiBold)
                Text("네비게이토", style = footer, color = ink, maxLines = 1)
                Icon(R.drawable.ic_moon_fill, size = 9.dp, tint = ink)
                Text("출판사", style = footer, color = ink, maxLines = 1)
                Spacer(Modifier.weight(1f))
                Text(
                    if (pack.verses.size == 1) "1 card" else "${pack.verses.size} cards",
                    Modifier
                        .border(0.8.dp, pack.inkColor.copy(alpha = 0.8f), RoundedCornerShape(2.dp))
                        .padding(horizontal = 5.dp, vertical = 1.dp),
                    style = type(11f, FontWeight.Medium),
                    color = ink,
                    maxLines = 1,
                )
            }
        }
    }
}

@Composable
private fun GenericCover(pack: Pack) {
    Box(Modifier.fillMaxSize().background(pack.baseColor)) {
        if (pack.accentText.isNotEmpty()) {
            Text(
                pack.accentText,
                Modifier.align(Alignment.Center).offset(x = 80.dp),
                style = type(64f, FontWeight.Black, InterDisplay),
                color = Color.White.copy(alpha = 0.1f),
                maxLines = 1,
            )
        }
        Row(Modifier.fillMaxSize().padding(18.dp)) {
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(5.dp)) {
                Text(
                    pack.name,
                    style = type(20f, FontWeight.Bold, SerifFamily),
                    color = Color.White,
                    maxLines = 2,
                    autoSize = TextAutoSize.StepBased(14.sp, 20.sp, 0.25.sp),
                )
                Spacer(Modifier.weight(1f))
                Text(
                    "${pack.verses.size} cards",
                    style = type(12f, FontWeight.Medium),
                    color = Color.White.copy(alpha = 0.6f),
                )
            }
            Icon(
                R.drawable.ic_caret_right,
                Modifier.align(Alignment.Bottom),
                size = 14.dp,
                tint = Color.White.copy(alpha = 0.35f),
            )
        }
    }
}
