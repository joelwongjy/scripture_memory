package joel.scripturememory.ui.pouch

import androidx.compose.foundation.layout.Box
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.SemanticsActions
import androidx.compose.ui.semantics.SemanticsNode
import androidx.compose.ui.semantics.SemanticsProperties
import androidx.compose.ui.semantics.getOrNull
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.text.TextLayoutResult
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.dp
import androidx.test.platform.app.InstrumentationRegistry
import joel.scripturememory.model.Verse
import joel.scripturememory.model.VerseCatalog
import joel.scripturememory.ui.theme.AppTheme
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test

class CardTextFitTests {
    @get:Rule
    val compose = createComposeRule()

    private data class Shown(val verse: Verse, val width: Float, val fontScale: Float, val front: Boolean)

    private val cards: List<Verse> by lazy {
        val assets = InstrumentationRegistry.getInstrumentation().targetContext.assets
        VerseCatalog.configure({ assets.open(it) }, null, null)
        (VerseCatalog.packs("NIV84", "verseData.json") + VerseCatalog.packs("NIV11", "verseDataNIV11.json"))
            .flatMap { it.verses }
            .distinctBy { listOf(it.packName, it.title, it.book, it.reference, it.verse, it.version, it.subpack) }
    }


    @Test
    fun everyCardFitsItsText() {
        var shown by mutableStateOf(Shown(cards.first(), 256f, 1f, true))
        compose.setContent {
            val base = LocalDensity.current
            CompositionLocalProvider(LocalDensity provides Density(base.density, shown.fontScale)) {
                AppTheme {
                    PaperAppearance {
                        Box(Modifier.testTag("card")) {
                            if (shown.front) {
                                PouchVerseCard(shown.verse, isLearnt = true, width = shown.width.dp)
                            } else {
                                PouchCardBack(shown.verse, shown.width.dp)
                            }
                        }
                    }
                }
            }
        }

        val problems = mutableListOf<String>()
        for (width in listOf(256f, 360f)) {
            for (fontScale in listOf(1f, 2f)) {
                for (front in listOf(true, false)) {
                    for (verse in cards) {
                        compose.runOnIdle { shown = Shown(verse, width, fontScale, front) }
                        compose.waitForIdle()
                        val face = if (front) "front" else "back"
                        problems += problems(verse).map {
                            "${verse.packName} · ${verse.book} ${verse.reference} ($face, ${width.toInt()}dp, text ×$fontScale): $it"
                        }
                    }
                }
            }
        }
        problems.forEach { android.util.Log.w("CardTextFit", it) }
        assertTrue("${problems.size} problems:\n" + problems.take(40).joinToString("\n"), problems.isEmpty())
    }

    private fun problems(verse: Verse): List<String> {
        val card = compose.onNodeWithTag("card", useUnmergedTree = true).fetchSemanticsNode()
        val bounds = card.boundsInRoot
        val found = mutableListOf<String>()
        texts(card).forEach { (node, layout) ->
            val text = node.config.getOrNull(SemanticsProperties.Text)?.joinToString("").orEmpty()
            val label = "\"${text.take(40)}${if (text.length > 40) "…" else ""}\""
            val widest = (0 until layout.lineCount).maxOfOrNull { layout.getLineRight(it) - layout.getLineLeft(it) } ?: 0f
            val extraWidth = widest - layout.size.width
            val extraHeight = layout.multiParagraph.height - layout.size.height
            val ellipsized = (0 until layout.lineCount).any(layout::isLineEllipsized)
            if (ellipsized || layout.multiParagraph.didExceedMaxLines || extraHeight > 1f || extraWidth > 1f) found += "$label is cut off"
            if (!bounds.inflate(0.5f).contains(node.boundsInRoot)) found += "$label spills outside the card"
        }
        return found
    }

    private fun Rect.contains(other: Rect) =
        other.left >= left && other.top >= top && other.right <= right && other.bottom <= bottom

    private fun texts(node: SemanticsNode): List<Pair<SemanticsNode, TextLayoutResult>> {
        val own = node.config.getOrNull(SemanticsActions.GetTextLayoutResult)?.action?.let { action ->
            val results = mutableListOf<TextLayoutResult>()
            action(results)
            results.firstOrNull()?.let { node to it }
        }
        return listOfNotNull(own) + node.children.flatMap(::texts)
    }
}
