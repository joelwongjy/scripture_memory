package joel.scripturememory.ui.components

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.input.TextFieldValue
import androidx.compose.ui.text.style.TextAlign
import joel.scripturememory.ui.theme.AppTheme
import joel.scripturememory.ui.theme.AppType

@Composable
fun AppTextField(
    value: TextFieldValue,
    onValueChange: (TextFieldValue) -> Unit,
    modifier: Modifier = Modifier,
    placeholder: String? = null,
    textStyle: TextStyle = AppType.body,
    textColor: Color = AppTheme.colors.label,
    singleLine: Boolean = true,
    keyboardOptions: KeyboardOptions = KeyboardOptions.Default,
    keyboardActions: KeyboardActions = KeyboardActions.Default,
    enabled: Boolean = true,
    textAlign: TextAlign = TextAlign.Start,
) {
    val colors = AppTheme.colors
    BasicTextField(
        value = value,
        onValueChange = onValueChange,
        modifier = modifier,
        enabled = enabled,
        textStyle = textStyle.copy(color = textColor, textAlign = textAlign),
        singleLine = singleLine,
        keyboardOptions = keyboardOptions,
        keyboardActions = keyboardActions,
        cursorBrush = SolidColor(colors.accent),
        decorationBox = { inner ->
            val alignment = when (textAlign) {
                TextAlign.End, TextAlign.Right -> Alignment.CenterEnd
                TextAlign.Center -> Alignment.Center
                else -> Alignment.CenterStart
            }
            Box(contentAlignment = alignment) {
                if (value.text.isEmpty() && placeholder != null) {
                    Text(
                        placeholder,
                        if (textAlign == TextAlign.Start) Modifier else Modifier.fillMaxWidth(),
                        style = textStyle,
                        color = colors.tertiaryLabel,
                        maxLines = 1,
                        textAlign = textAlign,
                    )
                }
                inner()
            }
        },
    )
}
