package joel.scripturememory.ui.components

import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.defaultMinSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.TextFieldValue
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import joel.scripturememory.R
import joel.scripturememory.ui.theme.AppLayout
import joel.scripturememory.ui.theme.AppMotion
import joel.scripturememory.ui.theme.AppTheme
import joel.scripturememory.ui.theme.AppType
import joel.scripturememory.ui.theme.isAccessibilityTextSize
import joel.scripturememory.ui.theme.sizeInDp

private val CapsuleShape = RoundedCornerShape(percent = 50)

@Composable
fun TextFieldRow(
    value: TextFieldValue,
    onValueChange: (TextFieldValue) -> Unit,
    modifier: Modifier = Modifier,
    placeholder: String? = null,
    singleLine: Boolean = true,
    minLines: Int = 1,
    keyboardOptions: KeyboardOptions = KeyboardOptions.Default,
    keyboardActions: KeyboardActions = KeyboardActions.Default,
) {
    val lineHeight = with(LocalDensity.current) { AppType.body.lineHeight.toDp() }
    Box(
        Modifier
            .fillMaxWidth()
            .defaultMinSize(minHeight = 52.dp)
            .padding(horizontal = AppLayout.panelPadding, vertical = 14.dp),
        contentAlignment = Alignment.CenterStart,
    ) {
        AppTextField(
            value = value,
            onValueChange = onValueChange,
            modifier = modifier.fillMaxWidth().heightIn(min = lineHeight * minLines),
            placeholder = placeholder,
            singleLine = singleLine,
            keyboardOptions = keyboardOptions,
            keyboardActions = keyboardActions,
        )
    }
}

@Composable
fun PillButton(
    title: String,
    modifier: Modifier = Modifier,
    leadingIcon: Int? = null,
    bordered: Boolean = false,
    onClick: () -> Unit,
) {
    val colors = AppTheme.colors
    Row(
        modifier
            .pressable(pressedScale = 0.95f, onClick = onClick)
            .clip(CapsuleShape)
            .then(
                if (bordered) Modifier.background(colors.accent.copy(alpha = 0.12f))
                else Modifier.background(colors.fill),
            )
            .padding(horizontal = if (bordered) 12.dp else 8.dp, vertical = if (bordered) 6.dp else 2.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        val tint = if (bordered) colors.accent else colors.label
        if (leadingIcon != null) Icon(leadingIcon, size = 14.dp, tint = tint)
        Text(title, style = AppType.subheadline.copy(fontWeight = FontWeight.SemiBold), color = tint, maxLines = 1)
    }
}

@Composable
fun PillRow(titles: List<String>, onClick: (Int) -> Unit, modifier: Modifier = Modifier) {
    Row(
        modifier
            .fillMaxWidth()
            .horizontalScroll(rememberScrollState())
            .padding(horizontal = AppLayout.panelPadding, vertical = 8.dp),
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        titles.forEachIndexed { i, title -> PillButton(title, bordered = true, onClick = { onClick(i) }) }
    }
}

@Composable
fun StepNumber(number: Int, size: Dp = 24.dp) {
    val colors = AppTheme.colors
    Box(
        Modifier.size(size).border(1.5.dp, colors.accent, CircleShape),
        contentAlignment = Alignment.Center,
    ) {
        Text("$number", style = AppType.footnote.copy(fontWeight = FontWeight.SemiBold), color = colors.accent)
    }
}

@Composable
fun StatusLine(text: String, icon: Int? = null, tint: Color = AppTheme.colors.secondaryLabel, modifier: Modifier = Modifier) {
    Row(
        modifier.padding(start = AppLayout.panelPadding, end = AppLayout.panelPadding, top = 8.dp),
        horizontalArrangement = Arrangement.spacedBy(6.dp),
        verticalAlignment = Alignment.Top,
    ) {
        if (icon != null) Icon(icon, Modifier.padding(top = 1.dp), size = AppType.footnote.sizeInDp().dp * 1.2f, tint = tint)
        Text(text, style = AppType.footnote, color = tint)
    }
}

@Composable
fun DisclosureRow(title: String, expanded: Boolean, onToggle: () -> Unit) {
    val colors = AppTheme.colors
    val turn by animateFloatAsState(if (expanded) 90f else 0f, AppMotion.control(), label = "disclosure")
    Row(
        Modifier
            .fillMaxWidth()
            .defaultMinSize(minHeight = 52.dp)
            .semantics { stateDescription = if (expanded) "Expanded" else "Collapsed" }
            .pressable(pressedScale = 1f, pressedAlpha = 0.55f, onClick = onToggle)
            .padding(horizontal = AppLayout.panelPadding, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Text(title, Modifier.weight(1f), style = AppType.body, color = colors.label)
        Icon(R.drawable.ic_caret_right, Modifier.rotate(turn), size = 13.dp, tint = colors.accent)
    }
}

@Composable
fun ColorSwatches(
    colors: List<Color>,
    names: List<String>,
    selected: Int,
    onSelect: (Int) -> Unit,
    modifier: Modifier = Modifier,
) {
    val outline = AppTheme.colors.label.copy(alpha = 0.12f)
    val size = 30.dp * LocalDensity.current.fontScale.coerceAtLeast(1f)
    val perRow = if (isAccessibilityTextSize()) (colors.size + 1) / 2 else colors.size
    Column(modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        colors.indices.chunked(perRow).forEach { row ->
            Row(Modifier.fillMaxWidth()) {
                row.forEach { i ->
                    Box(
                        Modifier
                            .weight(1f)
                            .heightIn(min = AppLayout.minTapTarget)
                            .semantics {
                                contentDescription = names[i]
                                role = Role.RadioButton
                                this.selected = i == selected
                            }
                            .pressable(pressedScale = 0.9f) { onSelect(i) },
                        contentAlignment = Alignment.Center,
                    ) {
                        Box(
                            Modifier
                                .size(size)
                                .clip(CircleShape)
                                .background(colors[i])
                                .border(1.dp, outline, CircleShape),
                            contentAlignment = Alignment.Center,
                        ) {
                            if (i == selected) Icon(R.drawable.ic_check, size = size * 0.47f, tint = Color.White)
                        }
                    }
                }
                repeat(perRow - row.size) { Spacer(Modifier.weight(1f)) }
            }
        }
    }
}

@Composable
fun LabeledFieldRow(
    label: String,
    value: TextFieldValue,
    onValueChange: (TextFieldValue) -> Unit,
    modifier: Modifier = Modifier,
    placeholder: String? = null,
    textColor: Color = AppTheme.colors.label,
    keyboardOptions: KeyboardOptions = KeyboardOptions.Default,
    keyboardActions: KeyboardActions = KeyboardActions.Default,
) {
    val colors = AppTheme.colors
    val stacked = isAccessibilityTextSize()
    val field = @Composable { fieldModifier: Modifier ->
        AppTextField(
            value = value,
            onValueChange = onValueChange,
            modifier = fieldModifier.then(modifier).semantics { contentDescription = label },
            placeholder = placeholder,
            textColor = textColor,
            keyboardOptions = keyboardOptions,
            keyboardActions = keyboardActions,
            textAlign = if (stacked) TextAlign.Start else TextAlign.End,
        )
    }
    if (stacked) {
        Column(
            Modifier
                .fillMaxWidth()
                .padding(horizontal = AppLayout.panelPadding, vertical = 12.dp),
            verticalArrangement = Arrangement.spacedBy(4.dp),
        ) {
            Text(label, style = AppType.body, color = colors.label)
            field(Modifier.fillMaxWidth())
        }
    } else {
        Row(
            Modifier
                .fillMaxWidth()
                .defaultMinSize(minHeight = 52.dp)
                .padding(horizontal = AppLayout.panelPadding, vertical = 14.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Text(label, style = AppType.body, color = colors.label, maxLines = 1)
            field(Modifier.weight(1f))
        }
    }
}

@Composable
fun ActivityIndicator(modifier: Modifier = Modifier, size: Dp = 28.dp) {
    val tint = AppTheme.colors.secondaryLabel
    val spin = rememberInfiniteTransition(label = "spinner")
    val angle by spin.animateFloat(
        0f,
        360f,
        infiniteRepeatable(tween(900, easing = LinearEasing), RepeatMode.Restart),
        label = "spinnerAngle",
    )
    Canvas(modifier.size(size).rotate(angle)) {
        val stroke = 3.dp.toPx()
        drawArc(
            tint,
            startAngle = 0f,
            sweepAngle = 270f,
            useCenter = false,
            topLeft = Offset(stroke / 2, stroke / 2),
            size = Size(this.size.width - stroke, this.size.height - stroke),
            style = Stroke(stroke, cap = StrokeCap.Round),
        )
    }
}

@Composable
fun ProgressPanel(title: String, modifier: Modifier = Modifier) {
    Column(
        modifier,
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        ActivityIndicator()
        Text(title, style = AppType.callout, color = AppTheme.colors.secondaryLabel)
    }
}
