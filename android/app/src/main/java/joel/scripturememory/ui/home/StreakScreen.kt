package joel.scripturememory.ui.home

import android.text.format.DateFormat
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.SizeTransform
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.background
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.runtime.rememberCoroutineScope
import java.time.temporal.ChronoUnit
import kotlinx.coroutines.launch
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.BlendMode
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.CompositingStrategy
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import joel.scripturememory.R
import joel.scripturememory.model.AnalyticsScreen
import joel.scripturememory.model.AppClock
import joel.scripturememory.model.Date
import joel.scripturememory.model.SRSStore
import joel.scripturememory.model.StreakStore
import joel.scripturememory.ui.components.Icon
import joel.scripturememory.ui.components.LocalNavigator
import joel.scripturememory.ui.components.NumericText
import joel.scripturememory.ui.components.ReadableList
import joel.scripturememory.ui.components.Text
import joel.scripturememory.ui.components.TrackScreen
import joel.scripturememory.ui.components.dimOnPress
import joel.scripturememory.ui.components.groupedPanel
import joel.scripturememory.ui.components.symbolBounce
import joel.scripturememory.ui.theme.AppLayout
import joel.scripturememory.ui.theme.AppMotion
import joel.scripturememory.ui.theme.AppTheme
import joel.scripturememory.ui.theme.AppType
import java.time.LocalDate
import java.time.YearMonth
import java.time.format.DateTimeFormatter
import java.time.temporal.TemporalAdjusters

private val flameYellow = Color(0xFFFFCC00)
private val flameOrange = Color(0xFFFF9500)
private val flameRed = Color(0xFFFF3B30)
private val calendarCell = 34.dp

private fun today(): LocalDate = Date.now().localDate(AppClock.current.zone)

@Composable
fun StreakScreen() {
    TrackScreen(AnalyticsScreen.streak)
    val navigator = LocalNavigator.current
    ReadableList("Streak", onBack = navigator::pop) {
        item(key = "hero") { Hero() }
        item(key = "stats") { Stats() }
        item(key = "calendar") { Calendar() }
    }
}

@Composable
private fun Hero() {
    val colors = AppTheme.colors
    val streak = StreakStore.shared
    val count = streak.current
    val lit = streak.isTodayDone
    Column(
        Modifier
            .fillMaxWidth()
            .semantics(mergeDescendants = true) { contentDescription = "$count day streak" }
            .groupedPanel()
            .padding(horizontal = AppLayout.cardPadding, vertical = AppLayout.panelPadding),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            Flame(lit, count)
            Column {
                NumericText(
                    count,
                    style = AppType.largeTitle.copy(fontSize = 48.sp, lineHeight = 54.sp, fontWeight = FontWeight.ExtraBold),
                    color = if (lit) colors.orange else colors.label,
                )
                Text("day streak", style = AppType.headline, color = colors.secondaryLabel)
            }
        }
        StreakWeekRow()
    }
}

@Composable
private fun Flame(lit: Boolean, count: Int) {
    val colors = AppTheme.colors
    val gradient = remember { listOf(flameYellow, flameOrange, flameRed) }
    Icon(
        R.drawable.ic_fire_fill,
        Modifier
            .symbolBounce(count)
            .graphicsLayer { compositingStrategy = CompositingStrategy.Offscreen }
            .then(
                if (lit) {
                    Modifier.drawWithContent {
                        drawContent()
                        drawRect(
                            Brush.linearGradient(gradient, Offset.Zero, Offset(0f, size.height)),
                            blendMode = BlendMode.SrcIn,
                        )
                    }
                } else {
                    Modifier
                },
            ),
        size = 62.dp,
        tint = colors.tertiaryLabel,
    )
}

@Composable
fun StreakWeekRow(modifier: Modifier = Modifier) {
    val colors = AppTheme.colors
    val week = StreakStore.shared.thisWeek()
    Row(
        modifier.clearAndSetSemantics {
            contentDescription = "This week: ${week.count { it.done }} of 7 days active"
        },
        horizontalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        week.forEach { day ->
            Column(
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(6.dp),
            ) {
                Text(
                    day.initial,
                    style = AppType.caption.copy(fontWeight = FontWeight.SemiBold),
                    color = if (day.isToday) colors.orange else colors.secondaryLabel,
                    maxLines = 1,
                )
                Box(
                    Modifier
                        .alpha(if (day.isFuture) 0.4f else 1f)
                        .size(30.dp)
                        .clip(CircleShape)
                        .background(if (day.done) colors.orange else dayTrack)
                        .then(
                            if (!day.done && day.isToday) Modifier.border(2.dp, colors.orange, CircleShape)
                            else Modifier,
                        ),
                    contentAlignment = Alignment.Center,
                ) {
                    if (day.done) Icon(R.drawable.ic_check, size = 14.dp, tint = colors.onAccent)
                }
            }
        }
    }
}

@Composable
private fun Stats() {
    val colors = AppTheme.colors
    val streak = StreakStore.shared
    Row(horizontalArrangement = Arrangement.spacedBy(AppLayout.spacing)) {
        StatTile(streak.longest, "Best streak", R.drawable.ic_fire_fill, colors.orange, Modifier.weight(1f))
        StatTile(streak.totalDays, "Days active", R.drawable.ic_calendar, colors.accent, Modifier.weight(1f))
    }
}

@Composable
private fun StatTile(value: Int, label: String, icon: Int, tint: Color, modifier: Modifier = Modifier) {
    val colors = AppTheme.colors
    Row(
        modifier
            .semantics(mergeDescendants = true) {}
            .groupedPanel()
            .padding(AppLayout.panelPadding),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Icon(icon, size = 26.dp, tint = tint)
        Column {
            Text(
                "$value",
                style = AppType.title3.copy(fontWeight = FontWeight.Bold, fontFeatureSettings = "tnum"),
                color = colors.label,
                maxLines = 1,
            )
            Text(label, style = AppType.footnote, color = colors.secondaryLabel, maxLines = 1)
        }
    }
}

@Composable
private fun Calendar() {
    val streak = StreakStore.shared
    val days = streak.days
    val thisMonth = YearMonth.from(today())
    val oldest = streak.firstDay?.let { YearMonth.from(it) }?.takeIf { it < thisMonth } ?: thisMonth
    val pageCount = (ChronoUnit.MONTHS.between(oldest, thisMonth) + 1).toInt()
    val pager = rememberPagerState { pageCount }
    val scope = rememberCoroutineScope()
    val month = thisMonth.minusMonths(pager.currentPage.toLong())

    fun turn(monthsBack: Int) {
        val target = (pager.currentPage + monthsBack).coerceIn(0, pageCount - 1)
        scope.launch { pager.animateScrollToPage(target, animationSpec = AppMotion.repeated()) }
    }

    Column(
        Modifier
            .fillMaxWidth()
            .groupedPanel()
            .padding(vertical = AppLayout.panelPadding),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Row(Modifier.padding(horizontal = AppLayout.panelPadding), verticalAlignment = Alignment.CenterVertically) {
            AnimatedContent(
                targetState = month,
                modifier = Modifier.weight(1f),
                transitionSpec = {
                    fadeIn(AppMotion.smooth(160, 90)) togetherWith fadeOut(AppMotion.smooth(90)) using SizeTransform(clip = false)
                },
                contentAlignment = Alignment.CenterStart,
                label = "monthTitle",
            ) { shown ->
                Text(monthTitle(shown), style = AppType.headline, color = AppTheme.colors.label, maxLines = 1)
            }
            MonthButton(R.drawable.ic_caret_left, "Previous month", enabled = pager.currentPage < pageCount - 1) {
                turn(1)
            }
            MonthButton(R.drawable.ic_caret_right, "Next month", enabled = pager.currentPage > 0) {
                turn(-1)
            }
        }
        HorizontalPager(pager, Modifier.fillMaxWidth(), reverseLayout = true, verticalAlignment = Alignment.Top) { page ->
            val shown = thisMonth.minusMonths(page.toLong())
            MonthGrid(shown, Modifier.padding(horizontal = AppLayout.panelPadding)) { SRSStore.dayKey(it) in days }
        }
    }
}

@Composable
private fun MonthButton(icon: Int, label: String, enabled: Boolean, onClick: () -> Unit) {
    val colors = AppTheme.colors
    Box(
        Modifier
            .size(44.dp)
            .semantics { contentDescription = label }
            .dimOnPress(enabled = enabled, onClick = onClick),
        contentAlignment = Alignment.Center,
    ) {
        Icon(icon, size = 16.dp, tint = if (enabled) colors.accent else colors.tertiaryLabel)
    }
}

private fun monthTitle(month: YearMonth): String {
    val locale = AppClock.current.locale
    val pattern = DateFormat.getBestDateTimePattern(locale, "MMMMy")
    return DateTimeFormatter.ofPattern(pattern, locale).format(month)
}

private fun weeks(month: YearMonth): List<List<LocalDate?>> {
    val first = month.atDay(1)
    val weekStart = first.with(TemporalAdjusters.previousOrSame(AppClock.current.firstDayOfWeek))
    val leading = first.toEpochDay() - weekStart.toEpochDay()
    val days = ArrayList<LocalDate?>()
    repeat(leading.toInt()) { days.add(null) }
    (1..month.lengthOfMonth()).forEach { days.add(month.atDay(it)) }
    while (days.size < 42) days.add(null)
    return days.chunked(7)
}

@Composable
private fun MonthGrid(month: YearMonth, modifier: Modifier = Modifier, isDone: (LocalDate) -> Boolean) {
    val colors = AppTheme.colors
    val locale = AppClock.current.locale
    val weeks = remember(month, locale) { weeks(month) }
    val headings = remember(locale) {
        val formatter = DateTimeFormatter.ofPattern("EEEEE", locale)
        val start = today().with(TemporalAdjusters.previousOrSame(AppClock.current.firstDayOfWeek))
        (0L until 7L).map { formatter.format(start.plusDays(it)) }
    }
    val all = weeks.flatten().filterNotNull()
    val practised = all.count(isDone)
    Column(
        modifier
            .fillMaxWidth()
            .clearAndSetSemantics { contentDescription = "$practised of ${all.size} days active this month" },
        verticalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        Row {
            headings.forEach { heading ->
                Box(Modifier.weight(1f), contentAlignment = Alignment.Center) {
                    Text(
                        heading,
                        style = AppType.caption2.copy(fontWeight = FontWeight.SemiBold),
                        color = colors.secondaryLabel,
                        maxLines = 1,
                    )
                }
            }
        }
        weeks.forEach { week ->
            Row {
                week.forEachIndexed { column, day ->
                    DayCell(day, column, isDone, Modifier.weight(1f))
                }
            }
        }
    }
}

@Composable
private fun DayCell(day: LocalDate?, column: Int, isDone: (LocalDate) -> Boolean, modifier: Modifier = Modifier) {
    val colors = AppTheme.colors
    Box(modifier.height(calendarCell), contentAlignment = Alignment.Center) {
        if (day == null) return@Box
        val done = isDone(day)
        val joinsLeft = done && column > 0 && isDone(day.minusDays(1))
        val joinsRight = done && column < 6 && isDone(day.plusDays(1))
        val today = today()
        val band = colors.orange.copy(alpha = 0.35f)
        Row(Modifier.fillMaxWidth().height(calendarCell * 0.8f)) {
            BandHalf(if (joinsLeft) band else Color.Transparent, Modifier.weight(1f))
            BandHalf(if (joinsRight) band else Color.Transparent, Modifier.weight(1f))
        }
        Box(
            Modifier
                .size(calendarCell)
                .clip(CircleShape)
                .background(if (done) colors.orange else Color.Transparent)
                .then(if (day == today && !done) Modifier.border(2.dp, colors.orange, CircleShape) else Modifier),
        )
        Text(
            "${day.dayOfMonth}",
            style = AppType.subheadline.copy(fontWeight = if (done) FontWeight.Bold else FontWeight.Normal),
            color = when {
                done -> colors.onAccent
                day > today -> colors.secondaryLabel.copy(alpha = colors.secondaryLabel.alpha * 0.5f)
                else -> colors.label
            },
            maxLines = 1,
        )
    }
}

@Composable
private fun BandHalf(color: Color, modifier: Modifier = Modifier) {
    Box(modifier.fillMaxHeight().background(color))
}
