package joel.scripturememory.model

import androidx.compose.runtime.snapshots.Snapshot
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.launch
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

class StoreTests {

    private lateinit var clock: TestClock
    private lateinit var store: InMemoryStore
    private val storage get() = ProgressStorage.shared

    @Before
    fun setUp() {
        clock = TestClock(Date.fromTimeIntervalSince1970(1_800_000_000.0))
        store = InMemoryStore()
        installModel(clock, store)
    }

    private fun reads(block: () -> Unit): Set<Any> {
        val seen = HashSet<Any>()
        Snapshot.observe(readObserver = { seen.add(it) }, block = block)
        return seen
    }

    @Test
    fun progressStorageRoundTripsStringsAndArrays() {
        storage.set("value", "key")
        assertEquals("value", storage.string("key"))
        storage.set(listOf("a", "b"), "array")
        assertEquals(listOf("a", "b"), storage.stringArray("array"))
        storage.set(null as String?, "key")
        assertNull(storage.string("key"))
        storage.removeObject("array")
        assertNull(storage.stringArray("array"))
    }

    @Test
    fun progressStorageTreatsBadJsonAsAbsent() {
        store.putString("array", "not json")
        assertNull(storage.stringArray("array"))
        assertNull(storage.decode<Map<String, Int>>("array"))
    }

    @Test
    fun progressStorageLeavesTheStoredValueWhenEncodingFails() {
        storage.set("kept", "key")
        storage.encode(Double.NaN, "key")
        assertEquals("kept", storage.string("key"))
    }

    @Test
    fun appDefaultsNotifiesOnlyReadersOfTheChangedKey() {
        val defaults = AppDefaults.standard
        val studyReads = reads { defaults.getString("studyMode") }
        val versionReads = reads { defaults.getString("bibleVersion") }
        assertTrue(studyReads.isNotEmpty())
        assertTrue(studyReads.intersect(versionReads).isEmpty())
    }

    @Test
    fun learningCursorIsTheFirstUnlearntVerse() {
        val learning = LearningStore.shared
        val verses = listOf(verse(1), verse(2), verse(3))
        learning.markLearnt(verses[0])
        assertEquals(LearningStore.CurrentVerse(verses[1], 1), learning.current(verses))
        verses.forEach(learning::markLearnt)
        assertNull(learning.current(verses))
    }

    @Test
    fun markLearntSchedulesAndRecordsTheDay() {
        val v = verse(1)
        LearningStore.shared.markLearnt(v)
        assertTrue(SRSStore.shared.state(v)!!.isUngraded)
        assertTrue(StreakStore.shared.isTodayDone)
    }

    @Test
    fun unmarkLearntDropsAnUngradedSchedule() {
        val v = verse(1)
        LearningStore.shared.markLearnt(v)
        LearningStore.shared.unmarkLearnt(v)
        assertFalse(LearningStore.shared.isLearnt(v))
        assertNull(SRSStore.shared.state(v))
    }

    @Test
    fun unmarkLearntKeepsARealSchedule() {
        val v = verse(1)
        LearningStore.shared.markLearnt(v)
        SRSStore.shared.grade(v, SRSGrade.good)
        LearningStore.shared.unmarkLearnt(v)
        assertNotNull(SRSStore.shared.state(v))
    }

    @Test
    fun setProgressLearnsEverythingBeforeAndForgetsTheRest() {
        val learning = LearningStore.shared
        val verses = listOf(verse(1), verse(2), verse(3))
        learning.markLearnt(verses[2])
        learning.setProgress(verses[1], verses)
        assertEquals(setOf("uid-1"), learning.learntKeys)
        assertEquals(verses[1], learning.current(verses)?.verse)
    }

    @Test
    fun setProgressIgnoresAVerseOutsideTheList() {
        val learning = LearningStore.shared
        learning.markLearnt(verse(1))
        learning.setProgress(verse(9), listOf(verse(1), verse(2)))
        assertEquals(setOf("uid-1"), learning.learntKeys)
    }

    @Test
    fun pinOverridesTheCursorUntilItLeavesTheList() {
        val learning = LearningStore.shared
        val verses = listOf(verse(1), verse(2))
        learning.pin(verses[1])
        assertEquals(LearningStore.DisplayedVerse(verses[1], true), learning.displayed(verses))
        assertEquals(LearningStore.DisplayedVerse(verses[0], false), learning.displayed(verses.take(1)))
        assertEquals(setOf<String>(), learning.learntKeys)
        learning.unpin()
        assertEquals(LearningStore.DisplayedVerse(verses[0], false), learning.displayed(verses))
    }

    @OptIn(ExperimentalCoroutinesApi::class)
    @Test
    fun pinAndUnpinAnnounceTheChange() = runTest(UnconfinedTestDispatcher()) {
        val learning = LearningStore.shared
        var count = 0
        val job = launch { learning.featuredVerseDidChange.collect { count += 1 } }
        learning.pin(verse(1))
        learning.unpin()
        learning.unpin()
        job.cancel()
        assertEquals(2, count)
    }

    @Test
    fun learningSurvivesAReload() {
        val learning = LearningStore.shared
        learning.markLearnt(verse(1))
        learning.pin(verse(2))
        val fresh = LearningStore(ProgressStorage(store))
        assertEquals(setOf("uid-1"), fresh.learntKeys)
        assertEquals("uid-2", fresh.pinnedKey)
    }

    @Test
    fun currentVerseFollowsMarkingAndHiddenPacks() {
        val learning = LearningStore.shared
        val first = packsNIV84[0].verses[0]
        assertEquals(first.srsKey, learning.currentKey)
        assertTrue(learning.isCurrent(first))

        learning.markLearnt(first)
        assertEquals(packsNIV84[0].verses[1].srsKey, learning.currentKey)

        PackPreferencesStore.shared.setHidden(packsNIV84[0].name, true)
        assertEquals(packsNIV84[1].verses[0].srsKey, learning.currentKey)
    }

    @Test
    fun cachedCurrentVerseStillReportsItsSnapshotReads() {
        val learning = LearningStore.shared
        learning.currentVerse
        val firstRead = reads { learning.currentVerse }
        val cachedRead = reads { learning.currentVerse }
        assertEquals(firstRead, cachedRead)
        assertTrue(cachedRead.isNotEmpty())
    }

    @Test
    fun switchingToNiv11KeepsTheCursorOnTheSameCard() {
        val learning = LearningStore.shared
        val before = learning.currentKey
        AppDefaults.standard.putString(BibleVersion.storageKey, BibleVersion.niv11.rawValue)
        assertEquals(before, learning.currentKey)
    }

    @Test
    fun favoritesToggleAndSurviveAReload() {
        val favorites = FavoritesStore.shared
        favorites.toggle(verse(1))
        assertTrue(favorites.isFavorite(verse(1)))
        assertEquals(setOf("uid-1"), FavoritesStore(ProgressStorage(store)).keys)
        favorites.toggle(verse(1))
        assertFalse(favorites.isFavorite(verse(1)))
    }

    @Test
    fun favoritesAreReturnedInCatalogueOrderAndFollowTheCatalogue() {
        val favorites = FavoritesStore.shared
        val packs = listOf(pack("A", 1, 2), pack("B", 3))
        favorites.toggle(packs[1].verses[0])
        favorites.toggle(packs[0].verses[0])
        assertEquals(listOf(1, 3), favorites.verses(packs).map { it.id })
        assertSame(favorites.verses(packs), favorites.verses(packs))

        val corrected = listOf(pack("B", 3), pack("A", 1, 2))
        assertEquals(listOf(3, 1), favorites.verses(corrected).map { it.id })
    }

    @Test
    fun favoritesPackAppearsOnlyWhenSomethingIsStarred() {
        val favorites = FavoritesStore.shared
        val packs = listOf(pack("A", 1))
        assertNull(favorites.pack(packs))
        favorites.toggle(packs[0].verses[0])
        val pack = favorites.pack(packs)!!
        assertEquals("Favourites", pack.name)
        assertEquals("#E5A50A", pack.color)
        assertEquals("★", pack.accentText)
    }

    @Test
    fun packPreferencesReorderHideAndReset() {
        val prefs = PackPreferencesStore.shared
        val packs = listOf(pack("A", 1), pack("B", 2), pack("C", 3))
        assertFalse(prefs.hasCustomization)

        prefs.move(prefs.arranged(packs), setOf(2), 0)
        assertEquals(listOf("C", "A", "B"), prefs.arranged(packs).map { it.name })

        prefs.setHidden("A", true)
        assertEquals(listOf("C", "B"), prefs.visible(packs).map { it.name })
        assertEquals(listOf("C", "A", "B"), prefs.arranged(packs).map { it.name })

        val fresh = PackPreferencesStore(ProgressStorage(store))
        assertEquals(prefs.order, fresh.order)
        assertEquals(prefs.hidden, fresh.hidden)

        prefs.reset()
        assertFalse(prefs.hasCustomization)
        assertEquals(listOf("A", "B", "C"), prefs.visible(packs).map { it.name })
        assertNull(store.getString("packs.order.v1"))
        assertNull(store.getString("packs.hidden.v1"))
    }

    @Test
    fun packPositionsPreferWhereYouLeftThenTheCursorThenTheStart() {
        val a = pack("A", 1, 2, 3)
        assertEquals(0, PackPositions.startIndex(a, null))
        assertEquals(1, PackPositions.startIndex(a, "uid-2"))
        PackPositions.save(a.verses[2], "A")
        assertEquals(2, PackPositions.startIndex(a, "uid-2"))
        assertEquals(1, PackPositions.startIndex(pack("A", 4, 5), "uid-5"))
    }

    @Test
    fun newCardCapDefaultsToTwoAWeek() {
        assertEquals(NewCardCap(2, NewCapUnit.week), NewCardCap.current())
    }

    @Test
    fun legacyDailyCapMigratesOnlyWhenChosen() {
        val fresh = InMemoryStore()
        NewCardCap.migrateIfNeeded(fresh)
        assertEquals(NewCardCap(2, NewCapUnit.week), NewCardCap.current(fresh))

        val chosen = InMemoryStore()
        chosen.putInt(NewCardCap.legacyDailyKey, 5)
        NewCardCap.migrateIfNeeded(chosen)
        assertEquals(NewCardCap(5, NewCapUnit.day), NewCardCap.current(chosen))
    }

    @Test
    fun legacyCapNeverOverwritesTheNewSetting() {
        val store = InMemoryStore()
        store.putInt(NewCardCap.amountKey, 3)
        store.putInt(NewCardCap.legacyDailyKey, 5)
        NewCardCap.migrateIfNeeded(store)
        assertEquals(3, store.getInt(NewCardCap.amountKey))
        assertNull(store.getString(NewCardCap.unitKey))
    }

    @Test
    fun savedSettingsFallBackOnUnknownValues() {
        val store = InMemoryStore()
        assertEquals(StudyMode.firstLetter, StudyMode.saved(store))
        assertEquals(BibleVersion.niv84, BibleVersion.saved(store))
        store.putString(StudyMode.storageKey, "nonsense")
        store.putString(BibleVersion.storageKey, "nonsense")
        assertEquals(StudyMode.firstLetter, StudyMode.saved(store))
        assertEquals(BibleVersion.niv84, BibleVersion.saved(store))
        store.putString(StudyMode.storageKey, "submit")
        store.putString(BibleVersion.storageKey, "NIV11")
        assertEquals(StudyMode.submit, StudyMode.saved(store))
        assertEquals(BibleVersion.niv11, BibleVersion.saved(store))
    }

    @Test
    fun identityMigrationOnlyRecordsCompletionOnAFreshInstall() {
        assertEquals(true, store.getBool("identity.cardUidMigration.v1"))
    }
}
