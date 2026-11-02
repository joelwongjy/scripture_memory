package joel.scripturememory.widget

import android.net.Uri
import joel.scripturememory.model.BibleVersion
import joel.scripturememory.system.DeepLink

data class WidgetVerse(
    val title: String,
    val verse: String,
    val book: String,
    val reference: String,
    val packName: String,
) {
    val fullReference: String get() = "$book $reference"

    val deepLinkUri: Uri get() = DeepLink.read(packName, book, reference)
}

object VerseLibrary {
    val firstVerse: WidgetVerse?
        get() {
            val pack = BibleVersion.saved().packs.firstOrNull() ?: return null
            val verse = pack.verses.firstOrNull() ?: return null
            return WidgetVerse(verse.title, verse.verse, verse.book, verse.reference, pack.name)
        }
}

val WidgetBridge.Snapshot.featuredVerse: WidgetVerse?
    get() = verse?.let { WidgetVerse(it.title, it.verse, it.book, it.reference, it.packName) }
