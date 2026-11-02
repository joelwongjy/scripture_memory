package joel.scripturememory.ui.study

import androidx.activity.compose.BackHandler
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import joel.scripturememory.R
import joel.scripturememory.model.AppClock
import joel.scripturememory.model.AppDefaults
import joel.scripturememory.model.BibleVersion
import joel.scripturememory.model.Date
import joel.scripturememory.model.NewCardCap
import joel.scripturememory.model.PackPreferencesStore
import joel.scripturememory.model.SRSGrade
import joel.scripturememory.model.SRSQueueBuilder
import joel.scripturememory.model.SRSStore
import joel.scripturememory.model.SessionKind
import joel.scripturememory.model.StreakStore
import joel.scripturememory.model.TestSession
import joel.scripturememory.model.Verse
import joel.scripturememory.system.HapticEngine
import joel.scripturememory.ui.components.Icon
import joel.scripturememory.ui.components.PrimaryButton
import joel.scripturememory.ui.components.Text
import joel.scripturememory.ui.components.groupedPanel
import joel.scripturememory.ui.components.readableColumn
import joel.scripturememory.ui.theme.AppLayout
import joel.scripturememory.ui.theme.AppMotion
import joel.scripturememory.ui.theme.AppTheme
import joel.scripturememory.ui.theme.AppType
import kotlin.math.roundToInt

@Composable
fun DailyReviewScreen(session: TestSession, onFinished: () -> Unit, onClose: (() -> Unit)? = null) {
    var current by remember { mutableStateOf(session) }
    var firstRound by remember { mutableStateOf(emptyList<SRSGrade>()) }
    var finished by remember { mutableStateOf(false) }
    val close = rememberSessionClose(onClose)

    fun roundEnded(grades: List<SRSGrade>, missed: List<Verse>) {
        if (current.round == 1) firstRound = grades
        if (missed.isEmpty()) {
            HapticEngine.success()
            finished = true
        } else {
            current = TestSession(missed, SessionKind.srs, round = current.round + 1)
        }
    }

    AnimatedContent(
        targetState = if (finished) null else current,
        contentKey = { it?.id },
        transitionSpec = { fadeIn(AppMotion.content()).togetherWith(fadeOut(AppMotion.content())) },
        label = "dailyReview",
    ) { shown ->
        if (shown == null) {
            ReviewCompleteView(firstRound) {
                onFinished()
                close()
            }
        } else {
            TestSessionScreen(
                session = shown,
                onSessionEnded = onFinished,
                onRoundEnded = ::roundEnded,
                onClose = close,
            )
        }
    }
}

@Composable
fun ReviewCompleteView(grades: List<SRSGrade>, onContinue: () -> Unit) {
    val colors = AppTheme.colors
    val density = LocalDensity.current.density
    val bounce = rememberSymbolBounce()
    val appeared = remember { Animatable(0f) }
    val remembered = grades.count { it != SRSGrade.again }
    val percent = if (grades.isEmpty()) 0 else (remembered.toDouble() / grades.size * 100).roundToInt()
    val tomorrow = remember { tomorrowLine() }

    BackHandler(onBack = onContinue)
    LaunchedEffect(Unit) {
        kotlinx.coroutines.delay(50)
        appeared.animateTo(1f, AppMotion.movement())
    }

    Box(
        Modifier
            .fillMaxSize()
            .background(colors.background)
            .statusBarsPadding()
            .navigationBarsPadding(),
    ) {
        Column(
            Modifier.readableColumn(520.dp).fillMaxHeight(),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Spacer(Modifier.weight(1f))
            Icon(
                R.drawable.ic_seal_check_fill,
                Modifier
                    .padding(bottom = 20.dp)
                    .graphicsLayer {
                        scaleX = bounce.value
                        scaleY = bounce.value
                    },
                size = 88.dp,
                tint = colors.green,
            )
            Text("Review complete", style = AppType.title1, color = colors.label)
            Text(
                tomorrow,
                Modifier.padding(top = 6.dp).padding(horizontal = 32.dp),
                style = AppType.body,
                color = colors.secondaryLabel,
                textAlign = TextAlign.Center,
            )
            Row(
                Modifier
                    .padding(top = 32.dp)
                    .padding(horizontal = AppLayout.screenMargin)
                    .graphicsLayer {
                        alpha = appeared.value
                        if (!AppMotion.reduceMotion) translationY = (1f - appeared.value) * 12f * density
                    },
                horizontalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                Stat("Cards", "${grades.size}", colors.accent, Modifier.weight(1f))
                Stat("Remembered", "$percent%", colors.green, Modifier.weight(1f))
                Stat("Streak", "${StreakStore.shared.current}", colors.orange, Modifier.weight(1f), R.drawable.ic_fire_fill)
            }
            Spacer(Modifier.weight(1f))
            PrimaryButton(
                "Continue",
                Modifier.padding(horizontal = AppLayout.screenMargin).padding(bottom = 24.dp),
                tint = colors.green,
                onClick = onContinue,
            )
        }
    }
}

private val statLabelStyle = AppType.caption2.copy(fontWeight = FontWeight.Bold)
private val statValueStyle = AppType.title1.copy(fontSize = 25.sp, fontFeatureSettings = "tnum")

@Composable
private fun Stat(label: String, value: String, color: Color, modifier: Modifier, symbol: Int? = null) {
    Column(
        modifier
            .semantics(mergeDescendants = true) {}
            .groupedPanel()
            .padding(vertical = AppLayout.panelRowPadding),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        Text(label.uppercase(), style = statLabelStyle, color = color, maxLines = 1)
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
            if (symbol != null) Icon(symbol, size = 22.dp, tint = color)
            Text(value, style = statValueStyle, color = AppTheme.colors.label, maxLines = 1)
        }
    }
}

private fun tomorrowLine(): String {
    val zone = AppClock.current.zone
    val endOfTomorrow = Date.from(
        Date.now().localDate(zone).plusDays(2).atStartOfDay(zone).toInstant(),
    ).addingTimeInterval(-1.0)
    val store = SRSStore.shared
    val version = BibleVersion.saved()
    val active = store.activePacks(PackPreferencesStore.shared.visible(version.packs))
    val cap = AppDefaults.standard.getInt(NewCardCap.dailyReviewCapKey) ?: NewCardCap.dailyReviewCapDefault
    val n = SRSQueueBuilder.dueSummary(
        activePacks = active,
        store = store,
        newCap = NewCardCap.current(),
        dailyReviewCap = cap,
        now = endOfTomorrow,
    ).total
    return when (n) {
        0 -> "That's everything for now. Nothing is due tomorrow."
        1 -> "That's it for today. 1 card is waiting tomorrow."
        else -> "That's it for today. $n cards are waiting tomorrow."
    }
}
