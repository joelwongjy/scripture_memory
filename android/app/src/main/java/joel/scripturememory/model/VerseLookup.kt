package joel.scripturememory.model

data class VerseLookupResult(val text: String, val title: String)

fun VerseTranslation.bundledPacks(code: String): List<Pack>? = when (code.uppercase()) {
    niv -> packsNIV11
    niv84 -> packsNIV84
    else -> null
}

object VerseLookup {

    fun bundled(reference: BibleReference, translation: String): VerseLookupResult? {
        val packs = VerseTranslation.bundledPacks(translation) ?: return null
        val wanted = SRSKey.normalizedReference(reference.reference)
        for (pack in packs) {
            for (verse in pack.verses) {
                if (verse.pinnedVersion != null) continue
                if (SRSKey.normalizedReference(verse.reference) != wanted) continue
                if (BibleBooks.book(verse.book) != reference.book) continue
                return VerseLookupResult(verse.verse, verse.title)
            }
        }
        return null
    }
}
