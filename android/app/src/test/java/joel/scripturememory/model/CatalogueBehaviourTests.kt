package joel.scripturememory.model

import androidx.compose.ui.geometry.Offset
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

class CatalogueBehaviourTests {

    @Before
    fun setUp() {
        installModel()
    }

    private fun named(name: String) = packsNIV84.first { it.name == name }

    @Test
    fun printedCodesMatchTheBooklets() {
        val tms = named("TMS 60")
        val c7 = tms.verses.filter { it.subpack == "C" }[6]
        assertEquals("TMS 60 C-7", VerseNumbering.code(c7))
        assertEquals("5A-3", VerseNumbering.code(named("5 Assurances").verses[2]))
        assertEquals("DEP 1-9", VerseNumbering.code(named("DEP 1: Assurance of Salvation").verses[8]))
    }

    @Test
    fun packCodesAreBuiltFromTheCatalogue() {
        assertEquals("DEP 2", VerseNumbering.packCode("DEP 2: Quiet Time"))
        assertEquals("5A", VerseNumbering.packCode("5 Assurances"))
        assertEquals("TMS 60", VerseNumbering.packCode("TMS 60"))
        assertEquals("TMS 180 S1", VerseNumbering.packCode("TMS 180 · Getting to Know God"))
        assertEquals("TMS 180 S5", VerseNumbering.packCode("TMS 180 · Sharing Christ with Others"))
        assertEquals("Unknown", VerseNumbering.packCode("Unknown"))
    }

    @Test
    fun printedNumberIsOnlyForDep() {
        assertEquals("1-9", VerseNumbering.printedNumber(named("DEP 1: Assurance of Salvation").verses[8]))
        assertNull(VerseNumbering.printedNumber(named("TMS 60").verses[0]))
    }

    @Test
    fun aVerseOutsideTheCatalogueHasNoCode() {
        assertNull(VerseNumbering.code(verse(1)))
        assertNull(VerseNumbering.code(verse(1, packName = "")))
    }

    @Test
    fun depTopicsCountDistinctRunsOfTitles() {
        val verses = named("DEP 1: Assurance of Salvation").verses
        assertEquals(1, VerseNumbering.topic(verses[0]))
        val changes = verses.zipWithNext().count { (a, b) -> a.title != b.title }
        assertEquals(changes + 1, VerseNumbering.topic(verses.last()))
        assertNull(VerseNumbering.topic(named("TMS 60").verses[0]))
    }

    @Test
    fun numberingSurvivesATranslationSwitch() {
        val niv84 = named("TMS 60").verses[3]
        val niv11 = BibleVersion.niv11.packs.first { it.name == "TMS 60" }.verses[3]
        assertEquals(VerseNumbering.code(niv84), VerseNumbering.code(niv11))
    }

    @Test
    fun onlyTms60UsesNiv2011() {
        val niv11 = BibleVersion.niv11.packs
        assertEquals(packsNIV84.map { it.name }, niv11.map { it.name })
        for (pack in niv11) {
            if (pack.name == "TMS 60") continue
            assertEquals(named(pack.name), pack)
        }
    }

    @Test
    fun tms60KeepsItsNiv84IdsUnderNiv2011Text() {
        val niv84 = named("TMS 60").verses
        val niv11 = BibleVersion.niv11.packs.first { it.name == "TMS 60" }.verses
        assertEquals(niv84.map { it.cardUid to it.id }, niv11.map { it.cardUid to it.id })
        assertTrue(niv84.zip(niv11).any { (a, b) -> a.verse != b.verse })
    }

    @Test
    fun cardFooterUsesSeriesNamesWhereTheyExist() {
        val c7 = named("TMS 60").verses.filter { it.subpack == "C" }[6]
        assertEquals("C-7 · Rely on God's Resources", CardFooter.label(c7))
        assertEquals("3 · Beginning with Christ", CardFooter.label(named("5 Assurances").verses[2]))
        val dep = named("DEP 2: Quiet Time").verses[0]
        assertEquals("DEP 2: Quiet Time", CardFooter.label(dep))
        assertEquals("Fallback", CardFooter.label(verse(1, packName = ""), "Fallback"))
    }

    @Test
    fun catalogueIsMemoizedPerPackSet() {
        val first = Catalogue.verses(packsNIV84)
        assertSame(first, Catalogue.verses(packsNIV84))
        assertEquals(487, first.size)
        assertNotEquals(Catalogue.fingerprint(packsNIV84), Catalogue.fingerprint(BibleVersion.niv11.packs))
        assertNotEquals(
            Catalogue.fingerprint(packsNIV84),
            Catalogue.fingerprint(packsNIV84.reversed()),
        )
    }

    @Test
    fun searchLeadsWithReferenceAndTitleMatches() {
        val results = VerseSearch.results("  JOHN 3:16 ", packsNIV84)
        assertTrue(results.isNotEmpty())
        assertTrue(results.all { it.matchedOnReference })
        assertTrue("john 3:16" in "${results[0].verse.book} ${results[0].verse.reference}".lowercase())
    }

    @Test
    fun searchRanksReferenceHitsAboveBodyHits() {
        val packs = listOf(
            Pack(
                "P",
                "#",
                "",
                listOf(
                    verse(1, text = "love one another"),
                    verse(2, title = "On love", text = "other"),
                ),
            ),
        )
        val results = VerseSearch.results("love", packs)
        assertEquals(listOf(2, 1), results.map { it.verse.id })
        assertEquals(listOf(true, false), results.map { it.matchedOnReference })
        assertEquals(listOf(1, 0), results.map { it.verseIndex })
    }

    @Test
    fun searchIsCappedAndEmptyQueriesReturnNothing() {
        assertEquals(25, VerseSearch.results("the", packsNIV84).size)
        assertEquals(emptyList<VerseSearchResult>(), VerseSearch.results("  \n", packsNIV84))
        assertEquals(emptyList<VerseSearchResult>(), VerseSearch.results("zzzzqqq", packsNIV84))
    }

    @Test
    fun searchIndexFollowsThePackSet() {
        VerseSearch.prewarm(packsNIV84)
        val packs = listOf(Pack("Only", "#", "", listOf(verse(1, text = "unique-word"))))
        assertEquals(listOf("Only"), VerseSearch.results("unique-word", packs).map { it.pack.name })
        assertEquals(emptyList<VerseSearchResult>(), VerseSearch.results("unique-word", packsNIV84))
    }

    @Test
    fun groupingKeepsTheOrderBestMatchesRanked() {
        val a = pack("A", 1, 2)
        val b = pack("B", 3)
        val results = listOf(
            VerseSearchResult(b.verses[0], b, 0),
            VerseSearchResult(a.verses[1], a, 1),
            VerseSearchResult(a.verses[0], a, 0),
        )
        val groups = VerseSearchGroup.grouping(results)
        assertEquals(listOf("B", "A"), groups.map { it.pack.name })
        assertEquals(listOf(2, 1), groups[1].results.map { it.verse.id })
    }

    @Test
    fun loggingAnOpenedResultRanksItAsShown() {
        val a = pack("A", 1, 2)
        val b = pack("B", 3)
        val results = listOf(
            VerseSearchResult(a.verses[0], a, 0, matchedOnReference = true),
            VerseSearchResult(b.verses[0], b, 0),
            VerseSearchResult(a.verses[1], a, 1),
        )
        val events = ArrayList<AnalyticsEvent>()
        VerseSearch.logOpened(results[1], results, events::add)
        assertEquals(
            listOf(
                AnalyticsEvent.SearchResultOpened(3, false),
                AnalyticsEvent.PackOpened("B", PackSource.search),
            ),
            events,
        )
    }

    @Test
    fun practiceStartsFromTheChosenCard() {
        val verses = listOf(verse(1), verse(2), verse(3))
        assertEquals(listOf(2, 3), TestSession.practice(verses, 1)?.verses?.map { it.id })
        assertEquals(SessionKind.pack, TestSession.practice(verses, 1)?.kind)
        assertNull(TestSession.practice(verses, 3))
        assertNull(TestSession.practice(verses, -1))
    }

    @Test
    fun pinnedVersionIsNormalised() {
        assertNull(verse(1).pinnedVersion)
        assertNull(verse(1).copy(version = "  ").pinnedVersion)
        assertEquals("KJV", verse(1).copy(version = " kjv ").pinnedVersion)
    }

    @Test
    fun verseFallsBackToTheLegacyKeyOutsideTheCatalogue() {
        val adHoc = verse(1).copy(cardUid = null, book = " Psalm ", reference = "1 : 2")
        assertEquals("Pack#psalm|1:2", adHoc.srsKey)
        assertEquals("uid-1", verse(1).srsKey)
    }

    @Test
    fun hintFillAddsOneWordAndCorrectsWhatIsThere() {
        val target = "\"For God so\nloved"
        assertEquals("\"For", HintFill.next(target, ""))
        assertEquals("\"For God", HintFill.next(target, "wrong"))
        assertEquals("\"For God so loved", HintFill.next(target, "a b c"))
        assertNull(HintFill.next(target, "a b c d"))
        assertEquals(listOf("a", "b"), HintFill.words("  a \n\n b "))
    }

    @Test
    fun wordingPluralises() {
        assertEquals("1 verse", Wording.verses(1))
        assertEquals("0 verses", Wording.verses(0))
        assertEquals("2 verses", Wording.verses(2))
    }

    @Test
    fun swipeProgressIsDirectionalAndCapped() {
        assertEquals(0f, CardSwipeConfig.forwardDragProgress(10f), 0f)
        assertEquals(0.5f, CardSwipeConfig.forwardDragProgress(-75f), 1e-6f)
        assertEquals(1f, CardSwipeConfig.forwardDragProgress(-500f), 0f)
        assertEquals(0f, CardSwipeConfig.backwardDragProgress(-10f), 0f)
        assertEquals(0.5f, CardSwipeConfig.backwardDragProgress(100f), 1e-6f)
        assertEquals(1f, CardSwipeConfig.backwardDragProgress(500f), 0f)
    }

    @Test
    fun swipeRubberBandsPastTheEnds() {
        val left = Offset(-100f, 20f)
        val right = Offset(100f, 20f)
        assertEquals(left, CardSwipeConfig.clampedDragTranslation(left, canGoNext = true, canGoPrev = false))
        assertEquals(right, CardSwipeConfig.clampedDragTranslation(right, canGoNext = false, canGoPrev = true))
        val damped = CardSwipeConfig.clampedDragTranslation(left, canGoNext = false, canGoPrev = true)
        assertEquals(-15f, damped.x, 1e-4f)
        assertEquals(3f, damped.y, 1e-4f)
        val still = CardSwipeConfig.clampedDragTranslation(Offset(0f, 20f), canGoNext = true, canGoPrev = true)
        assertEquals(0f, still.x, 0f)
        assertEquals(3f, still.y, 1e-4f)
    }

    @Test
    fun submitResultsRoundTripWithIosKindCodes() {
        val result = SubmitResult(
            listOf(DiffWord("a", DiffWord.Kind.correct), DiffWord("b", DiffWord.Kind.wrong, "c")),
            listOf(DiffWord("d", DiffWord.Kind.missing), DiffWord("e", DiffWord.Kind.extra)),
        )
        val stored = SubmitResultPersistence.encodeToMap(mapOf(7 to result))
        assertEquals(listOf("c", "w"), stored.getValue("7").titleDiffs.map { it.kind })
        assertEquals(listOf("m", "e"), stored.getValue("7").verseDiffs.map { it.kind })
        assertEquals(mapOf(7 to result), SubmitResultPersistence.decodeFromMap(stored, setOf(7)))
    }

    @Test
    fun submitResultsDropUnknownVersesKeysAndKinds() {
        val word = SubmitResultPersistence.StoredWord("a", "c")
        val bad = SubmitResultPersistence.StoredWord("a", "?")
        val stored = mapOf(
            "1" to SubmitResultPersistence.StoredResult(listOf(word), listOf(word)),
            "2" to SubmitResultPersistence.StoredResult(listOf(word), listOf(bad)),
            "9" to SubmitResultPersistence.StoredResult(listOf(word), listOf(word)),
            "x" to SubmitResultPersistence.StoredResult(listOf(word), listOf(word)),
        )
        assertEquals(setOf(1), SubmitResultPersistence.decodeFromMap(stored, setOf(1, 2)).keys)
        assertEquals(emptyMap<Int, SubmitResult>(), SubmitResultPersistence.decodeFromMap(null, setOf(1)))
    }
}
