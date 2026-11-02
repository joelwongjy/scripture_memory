package joel.scripturememory.ui.pouch

import androidx.compose.runtime.Composable
import androidx.compose.ui.geometry.Rect
import joel.scripturememory.model.Pack
import joel.scripturememory.ui.components.LargeTitleColumn
import joel.scripturememory.ui.components.Text

@Composable
fun PouchScreen(pack: Pack, startIndex: Int, shelf: (() -> Rect)? = null, animatesPouch: Boolean = true, onClosed: () -> Unit) {
    LargeTitleColumn("Pack") { Text("Pack") }
}
