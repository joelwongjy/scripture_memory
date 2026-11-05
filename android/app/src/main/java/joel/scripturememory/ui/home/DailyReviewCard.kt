package joel.scripturememory.ui.home

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.SizeTransform
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.compose.LifecycleEventEffect
import joel.scripturememory.R
import joel.scripturememory.model.AppClock
import joel.scripturememory.model.AppDefaults
import joel.scripturememory.model.Date
import joel.scripturememory.model.NewCapUnit
import joel.scripturememory.model.NewCardCap
import joel.scripturememory.model.Pack
import joel.scripturememory.model.SRSPhase
import joel.scripturememory.model.SRSQueueBuilder
import joel.scripturememory.model.SRSStore
import joel.scripturememory.model.SessionKind
import joel.scripturememory.model.TestSession
import joel.scripturememory.model.TestSessionViewModel
import joel.scripturememory.ui.components.Icon
import joel.scripturememory.ui.components.NumericText
import joel.scripturememory.ui.components.PrimaryButton
import joel.scripturememory.ui.components.Text
import joel.scripturememory.ui.components.groupedPanel
import joel.scripturememory.ui.components.symbolBounce
import joel.scripturememory.ui.theme.AppLayout
import joel.scripturememory.ui.theme.AppMotion
import joel.scripturememory.ui.theme.AppTheme
import joel.scripturememory.ui.theme.AppType
import kotlinx.coroutines.delay
import kotlin.math.min

private const val refreshMillis = 60_000L

private data class DueCounts(
    val learning: Int,
    val review: Int,
    val newToday: Int,
    val newCandidates: Int,
    val overLimit: Int,
) {
    val total: Int get() = learning + review + newToday
}

private enum class ReviewPanelState { NoActivePacks, Due, CaughtUp }

@Composable
fun DailyReviewCard(activePacks: List<Pack>, modifier: Modifier = Modifier, onStart: (TestSession) -> Unit) {
    val store = SRSStore.shared
    val newCap = NewCardCap.current()
    val dailyReviewCap = AppDefaults.standard.getInt(NewCardCap.dailyReviewCapKey) ?: NewCardCap.dailyReviewCapDefault
    var tick by remember { mutableIntStateOf(0) }

    LifecycleEventEffect(Lifecycle.Event.ON_RESUME) { tick += 1 }
    LaunchedEffect(Unit) {
        while (true) {
            delay(refreshMillis)
            tick += 1
        }
    }

    val now = remember(tick, store.states, store.reviewedByDate, store.dailyNewByDate) { Date.now() }
    val counts = dueCounts(activePacks, store, newCap, dailyReviewCap, now)
    val state = when {
        activePacks.isEmpty() -> ReviewPanelState.NoActivePacks
        counts.total > 0 -> ReviewPanelState.Due
        else -> ReviewPanelState.CaughtUp
    }

    Column(modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(8.dp)) {
        AnimatedContent(
            targetState = state,
            modifier = Modifier
                .fillMaxWidth()
                .groupedPanel()
                .padding(horizontal = AppLayout.panelPadding, vertical = AppLayout.panelRowPadding),
            transitionSpec = {
                fadeIn(AppMotion.smooth(240, 130)) togetherWith fadeOut(AppMotion.smooth(130)) using
                    SizeTransform(clip = true) { _, _ -> AppMotion.content() }
            },
            contentAlignment = Alignment.TopCenter,
            label = "dailyReviewState",
        ) { shown ->
            when (shown) {
                ReviewPanelState.NoActivePacks -> NoActivePacks()
                ReviewPanelState.Due -> Due(counts) {
                    val session = TestSession.dailyReview(activePacks, newCap, dailyReviewCap)
                    if (session != null) {
                        TestSessionViewModel.clearPersistedProgress(SessionKind.srs)
                        onStart(session)
                    }
                }
                ReviewPanelState.CaughtUp -> CaughtUp(
                    title = if (store.reviewedToday(now) > 0) "Done for today" else "All caught up",
                    message = caughtUpMessage(counts, activePacks, store, newCap, dailyReviewCap, now),
                )
            }
        }
        if (state == ReviewPanelState.Due && !ReviewCountsTip.isDismissed) ReviewCountsTipCard()
    }
}

@Composable
private fun NoActivePacks() {
    val colors = AppTheme.colors
    Row(
        Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Icon(R.drawable.ic_cards_slash, size = 28.dp, tint = colors.secondaryLabel)
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text("No active packs", style = AppType.headline, color = colors.label)
            Text(
                "Turn on a pack to start your daily review.",
                style = AppType.footnote,
                color = colors.secondaryLabel,
            )
        }
    }
}

@Composable
private fun Due(counts: DueCounts, onStart: () -> Unit) {
    val label = "Start review, ${counts.total} ${if (counts.total == 1) "card" else "cards"}"
    Column(
        Modifier.fillMaxWidth().padding(vertical = 4.dp),
        verticalArrangement = Arrangement.spacedBy(AppLayout.spacing),
    ) {
        Row(Modifier.fillMaxWidth()) {
            Count("New", counts.newToday, ReviewColor.new, ReviewCountsTip.newHint, Modifier.weight(1f))
            Count("Learn", counts.learning, ReviewColor.learn, ReviewCountsTip.learnHint, Modifier.weight(1f))
            Count("Due", counts.review, ReviewColor.due, ReviewCountsTip.dueHint, Modifier.weight(1f))
        }
        PrimaryButton(
            "Start review",
            Modifier.semantics { contentDescription = label },
            onClick = onStart,
        )
    }
}

@Composable
private fun Count(label: String, value: Int, color: Color, hint: String, modifier: Modifier = Modifier) {
    val colors = AppTheme.colors
    Column(
        modifier.semantics(mergeDescendants = true) { contentDescription = "$value $label. $hint" },
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(2.dp),
    ) {
        NumericText(
            value,
            style = AppType.title1.copy(fontSize = 28.sp, lineHeight = 34.sp, fontWeight = FontWeight.SemiBold),
            color = if (value > 0) color else colors.tertiaryLabel,
        )
        Text(
            label,
            style = AppType.footnote.copy(fontWeight = FontWeight.Medium),
            color = colors.secondaryLabel,
            maxLines = 1,
        )
    }
}

@Composable
private fun CaughtUp(title: String, message: String) {
    val colors = AppTheme.colors
    Row(
        Modifier.fillMaxWidth().padding(vertical = 6.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Icon(
            R.drawable.ic_seal_check_fill,
            Modifier.symbolBounce(onAppear = true),
            size = 32.dp,
            tint = colors.green,
        )
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(title, style = AppType.headline, color = colors.label)
            Text(message, style = AppType.footnote, color = colors.secondaryLabel)
        }
    }
}

private fun dueCounts(
    activePacks: List<Pack>,
    store: SRSStore,
    newCap: NewCardCap,
    dailyReviewCap: Int,
    now: Date,
): DueCounts {
    val policy = SRSQueueBuilder.NewCardPolicy.current
    val served = SRSQueueBuilder.reviewCards(activePacks, store, dailyReviewCap, policy, now)
    val learning = served.count { store.state(it)?.phase == SRSPhase.learning }
    val newCandidates = activePacks.sumOf { policy.fresh(it.verses, store).size }
    val unlimited = SRSQueueBuilder.reviewCards(activePacks, store, Int.MAX_VALUE, policy, now)
    return DueCounts(
        learning = learning,
        review = served.size - learning,
        newToday = min(SRSQueueBuilder.globalNewRemaining(store, newCap, now), newCandidates),
        newCandidates = newCandidates,
        overLimit = unlimited.size - served.size,
    )
}

private fun caughtUpMessage(
    counts: DueCounts,
    activePacks: List<Pack>,
    store: SRSStore,
    newCap: NewCardCap,
    dailyReviewCap: Int,
    now: Date,
): String {
    val zone = AppClock.current.zone
    val next = activePacks.flatMap { it.verses }.mapNotNull { store.state(it)?.due }.filter { it > now }.minOrNull()
    val tomorrow = Date.from(now.localDate(zone).plusDays(1).atStartOfDay(zone).toInstant())

    if (counts.overLimit > 0) {
        return "You've reached today's limit of $dailyReviewCap reviews. " +
            "${counts.overLimit} more ${if (counts.overLimit == 1) "is" else "are"} waiting for tomorrow."
    }
    if (next != null && next < tomorrow) return "Your next review is in ${formatRelative(next, now)}."
    if (counts.newCandidates > 0 && newCap.amount > 0) {
        val n = min(newCap.amount, counts.newCandidates)
        val whenBack = if (newCap.unit == NewCapUnit.day) "tomorrow" else "next week"
        return if (n == 1) "Come back $whenBack for a new verse." else "Come back $whenBack for $n new verses."
    }
    if (next != null) return "Your next review is in ${formatRelative(next, now)}."
    if (counts.newCandidates > 0) return "Raise your daily new verses in Settings to keep going."
    return "You've reviewed every verse in your active packs."
}

private fun formatRelative(date: Date, now: Date): String {
    val dt = date.timeIntervalSince(now)
    if (dt <= 0) return "now"
    if (dt < 60) return "<1m"
    if (dt < 3_600) return "${(dt / 60).toInt()}m"
    if (dt < SRSStore.secondsPerDay) return "${(dt / 3_600).toInt()}h"
    val days = (dt / SRSStore.secondsPerDay).toInt()
    return if (days == 1) "1 day" else "$days days"
}
