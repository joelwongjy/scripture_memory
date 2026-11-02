package joel.scripturememory.ui.components

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import joel.scripturememory.ui.theme.AppLayout

@Composable
fun <T> PickerSheet(
    title: String,
    options: List<T>,
    selected: T,
    label: (T) -> String,
    onSelect: (T) -> Unit,
    onDismiss: () -> Unit,
) {
    AppSheet(onDismiss = onDismiss) { sheet ->
        SheetHeader(title)
        Column(
            Modifier
                .verticalScroll(rememberScrollState())
                .padding(start = AppLayout.screenMargin, end = AppLayout.screenMargin, top = 4.dp, bottom = 20.dp),
        ) {
            GroupedSection {
                options.forEachIndexed { index, option ->
                    if (index > 0) RowDivider()
                    ListRow(
                        title = label(option),
                        modifier = Modifier.semantics {
                            this.selected = option == selected
                            role = Role.RadioButton
                        },
                        onClick = {
                            onSelect(option)
                            sheet.dismiss()
                        },
                        trailing = { SelectionMark(option == selected) },
                    )
                }
            }
        }
    }
}
