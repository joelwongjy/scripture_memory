package joel.scripturememory.model

import kotlinx.serialization.json.Json
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

class UserPackStoreTests {

    private lateinit var store: InMemoryStore
    private val packs get() = UserPackStore.shared

    @Before
    fun setUp() {
        store = InMemoryStore()
        installModel(store = store)
    }

    @Test
    fun savesTheSameJsonShapeAsSwift() {
        val pack = packs.createPack("Romans", UserPack.colors[1])
        packs.addVerse(UserVerse("u1", "Grace", "For it is by grace", "Ephesians", "2:8", null), pack.id)
        val saved = Json.parseToJsonElement(store.getString("userPacks.v1")!!).jsonArray
        val first = saved.single().jsonObject
        assertEquals(setOf("id", "name", "color", "verses"), first.keys)
        assertEquals(setOf("id", "title", "text", "book", "reference"), first.getValue("verses").jsonArray.single().jsonObject.keys)

        installModel(store = store)
        assertEquals(listOf("Romans"), UserPackStore.packs.map { it.name })
        assertTrue(BibleVersion.niv84.packs.last().isUserMade)
        assertEquals("u1", UserPackStore.packs.single().verses.single().srsKey)
    }

    @Test
    fun namesStayClearOfBundledPacksAndEachOther() {
        assertEquals("OYO", packs.availableName("  "))
        assertEquals("tms 60 2", packs.availableName("tms 60"))
        assertEquals("Favourites 2", packs.availableName("Favourites"))
        val first = packs.createPack("OYO", UserPack.colors[0])
        assertEquals("oyo 2", packs.createPack("oyo", UserPack.colors[0]).name)
        assertEquals("OYO", packs.availableName("OYO", excluding = first.id))
    }

    @Test
    fun renamingCarriesOrderHiddenInactiveAndPosition() {
        val pack = packs.createPack("Mine", UserPack.colors[0])
        PackPreferencesStore.shared.move(PackPreferencesStore.shared.arranged(BibleVersion.niv84.packs), setOf(0), 2)
        PackPreferencesStore.shared.setHidden("Mine", true)
        SRSStore.shared.setActive("Mine", false)
        val verse = UserVerse("u2", "", "Text", "John", "1:1")
        packs.addVerse(verse, pack.id)
        PackPositions.save(UserPackStore.packs.single().verses.single(), "Mine")

        packs.updatePack(pack.id, "Yours", UserPack.colors[2])

        assertTrue("Yours" in PackPreferencesStore.shared.order && "Mine" !in PackPreferencesStore.shared.order)
        assertTrue(PackPreferencesStore.shared.isHidden("Yours"))
        assertFalse(PackPreferencesStore.shared.isHidden("Mine"))
        assertFalse(SRSStore.shared.isActive("Yours"))
        assertTrue(SRSStore.shared.isActive("Mine"))
        assertEquals(0, PackPositions.startIndex(UserPackStore.packs.single(), null))
        assertEquals(UserPack.colors[2], packs.pack(pack.id)?.color)
    }

    @Test
    fun movesVersesLikeSwiftUIOnMove() {
        val pack = packs.createPack("Order", UserPack.colors[0], listOf("a", "b", "c", "d").map {
            UserVerse(it, "", it, "John", "1:1")
        })
        packs.moveVerses(pack.id, setOf(0), 3)
        assertEquals(listOf("b", "c", "a", "d"), packs.pack(pack.id)?.verses?.map { it.id })
        packs.moveVerses(pack.id, setOf(3), 0)
        assertEquals(listOf("d", "b", "c", "a"), packs.pack(pack.id)?.verses?.map { it.id })
        packs.deleteVerses(setOf("b"), pack.id)
        assertEquals(listOf("d", "c", "a"), packs.pack(pack.id)?.verses?.map { it.id })
        packs.deletePack(pack.id)
        assertNull(packs.pack(pack.id))
    }

    @Test
    fun userPacksChangeTheCatalogueFingerprint() {
        val before = Catalogue.fingerprint(BibleVersion.niv84.packs)
        val pack = packs.createPack("Mine", UserPack.colors[0])
        packs.addVerse(UserVerse("u3", "", "Text", "John", "1:1"), pack.id)
        assertTrue(before != Catalogue.fingerprint(BibleVersion.niv84.packs))
    }

    @Test
    fun nivVersionIsLeftUnpinned() {
        val pack = UserPack("p", "P", "#000000", listOf(
            UserVerse("a", "", "x", "John", "1:1", "NIV"),
            UserVerse("b", "", "x", "John", "1:2", "ESV"),
        )).pack
        assertEquals(listOf(null, "ESV"), pack.verses.map { it.version })
        assertTrue(pack.verses.all { it.id >= 1_000_000 })
    }

    @Test
    fun ankiImportKeepsTheNewerScheduleAndMarksLearnt() {
        val now = Date.now()
        val key = packsNIV84.first().verses.first().srsKey
        val newer = SRSCardState(key, SRSPhase.review, 9.0, 2.5, 3, 0, 0, now, now)
        SRSStore.shared.importStates(listOf(newer))
        val older = newer.copy(interval = 40.0, lastReviewed = now.addingTimeInterval(-86_400.0))
        SRSStore.shared.importStates(listOf(older))
        assertEquals(9.0, SRSStore.shared.states.getValue(key).interval, 0.0)

        LearningStore.shared.markLearnt(setOf(key, ""))
        assertEquals(setOf(key), LearningStore.shared.learntKeys)
    }

    @Test
    fun sharedVersesGoToTheChosenPackOrOneNamedOYO() {
        fun draft(packID: String?, reference: String) =
            SharedVerseDraft(packID, if (packID == null) "OYO" else null, "", "Text", "John", reference, "NIV")

        packs.addShared(draft(null, "1:1"))
        val oyo = packs.userPacks.single()
        assertEquals("OYO", oyo.name)
        assertEquals(UserPack.colors[0], oyo.color)

        packs.addShared(draft(null, "1:2"))
        val romans = packs.createPack("Romans", UserPack.colors[1])
        packs.addShared(draft(romans.id, "8:28"))
        packs.addShared(draft("gone", "1:3"))

        assertEquals(listOf("1:1", "1:2", "1:3"), packs.pack(oyo.id)!!.verses.map { it.reference })
        assertEquals(listOf("8:28"), packs.pack(romans.id)!!.verses.map { it.reference })
        assertEquals(2, packs.userPacks.size)
    }
}
