package joel.scripturememory.ui.study

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.wrapContentSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.dp
import joel.scripturememory.model.Date
import joel.scripturememory.model.SRSCardState
import joel.scripturememory.model.SRSGrade
import joel.scripturememory.model.predictedIntervalLabel
import joel.scripturememory.system.HapticEngine
import joel.scripturememory.ui.components.Text
import joel.scripturememory.ui.components.pressable
import joel.scripturememory.ui.theme.AppTheme
import joel.scripturememory.ui.theme.AppType

private const val maxGradeFontScale = 1.35f
private val gradeNameStyle = AppType.subheadline.copy(fontWeight = FontWeight.SemiBold)
private val gradeIntervalStyle = AppType.footnote.copy(fontWeight = FontWeight.Medium, fontFeatureSettings = "tnum")
private val suggestedStyle = AppType.caption2.copy(fontWeight = FontWeight.Bold)

@Composable
fun SRSGradingButtons(
    state: SRSCardState,
    suggested: SRSGrade?,
    selected: SRSGrade?,
    now: Date,
    onPick: (SRSGrade) -> Unit,
) {
    val density = LocalDensity.current
    CompositionLocalProvider(
        LocalDensity provides Density(density.density, density.fontScale.coerceAtMost(maxGradeFontScale)),
    ) {
        Row(
            Modifier.fillMaxWidth().padding(top = 16.dp),
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            SRSGrade.entries.forEach { grade ->
                GradeButton(
                    grade = grade,
                    label = predictedIntervalLabel(state, grade, now),
                    isSuggested = grade == suggested,
                    isSelected = grade == selected,
                    onPick = onPick,
                    modifier = Modifier.weight(1f),
                )
            }
        }
    }
}

@Composable
private fun gradeColor(grade: SRSGrade): Color {
    val colors = AppTheme.colors
    return when (grade) {
        SRSGrade.again -> colors.red
        SRSGrade.hard -> colors.orange
        SRSGrade.good -> colors.green
        SRSGrade.easy -> colors.accent
    }
}

@Composable
private fun GradeButton(
    grade: SRSGrade,
    label: String,
    isSuggested: Boolean,
    isSelected: Boolean,
    onPick: (SRSGrade) -> Unit,
    modifier: Modifier,
) {
    val colors = AppTheme.colors
    val tint = gradeColor(grade)
    val textColor = when {
        isSelected -> colors.onAccent
        isSuggested -> tint
        else -> colors.label
    }
    Box(modifier, contentAlignment = Alignment.TopCenter) {
        Column(
            Modifier
                .fillMaxWidth()
                .semantics {
                    contentDescription = grade.displayName
                    stateDescription = if (isSuggested) "$label, suggested" else label
                }
                .pressable {
                    HapticEngine.light()
                    onPick(grade)
                }
                .clip(CapsuleShape)
                .background(if (isSelected) tint else colors.panel)
                .then(
                    if (isSuggested && !isSelected) Modifier.border(2.dp, tint, CapsuleShape) else Modifier,
                )
                .padding(vertical = 12.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(2.dp),
        ) {
            Text(grade.displayName, style = gradeNameStyle, color = textColor, maxLines = 1)
            Text(label, style = gradeIntervalStyle, color = textColor.copy(alpha = 0.85f), maxLines = 1)
        }
        if (isSuggested) {
            Text(
                "Suggested",
                Modifier
                    .wrapContentSize(unbounded = true)
                    .offset(y = (-9).dp)
                    .clip(CapsuleShape)
                    .background(colors.background)
                    .padding(1.5.dp)
                    .clip(CapsuleShape)
                    .background(tint)
                    .padding(horizontal = 7.dp, vertical = 2.dp),
                style = suggestedStyle,
                color = colors.onAccent,
                maxLines = 1,
            )
        }
    }
}
