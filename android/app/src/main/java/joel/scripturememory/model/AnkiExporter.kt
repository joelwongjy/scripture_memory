package joel.scripturememory.model

import java.io.File

object AnkiExporter {
    const val filename = "Scripture Memory.apkg"

    fun decks(edition: BibleVersion): List<AnkiExportDeck> {
        val srs = SRSStore.shared
        val learning = LearningStore.shared
        fun card(verse: Verse, version: String?) = AnkiExportCard(
            id = verse.srsKey,
            reference = "${verse.book} ${verse.reference}",
            title = verse.title,
            text = verse.verse,
            version = version,
            state = srs.state(verse),
            isLearnt = learning.isLearnt(verse),
        )

        val decks = edition.bundledPacks.mapNotNull { pack ->
            val printed = if (edition == BibleVersion.niv11 && pack.name in BibleVersion.niv11PackNames) "NIV" else "NIV84"
            val cards = pack.verses.map { card(it, it.pinnedVersion ?: printed) }
            if (cards.none { it.state != null || it.isLearnt }) null else AnkiExportDeck(pack.name, cards)
        }.toMutableList()
        for (userPack in UserPackStore.shared.userPacks) {
            if (userPack.verses.isEmpty()) continue
            val cards = userPack.pack.verses.zip(userPack.verses).map { (verse, user) -> card(verse, user.version) }
            decks += AnkiExportDeck(userPack.name, cards)
        }
        return decks
    }

    fun exportFile(edition: BibleVersion, cacheDirectory: File, now: Date = Date.now()): File? {
        val decks = decks(edition)
        if (decks.isEmpty()) return null
        val directory = File(cacheDirectory, "export").apply { mkdirs() }
        val data = AnkiPackageWriter.write(decks, directory, now = now)
        return File(directory, filename).apply { writeBytes(data) }
    }
}
