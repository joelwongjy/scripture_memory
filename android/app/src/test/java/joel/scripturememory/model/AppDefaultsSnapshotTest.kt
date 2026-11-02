package joel.scripturememory.model

import androidx.compose.runtime.snapshots.Snapshot
import org.junit.Assert.assertEquals
import org.junit.Test

class AppDefaultsSnapshotTest {

    @Test
    fun aKeyFirstReadOutsideASnapshotIsStillReadableInsideIt() {
        val defaults = AppDefaults(InMemoryStore())
        val snapshot = Snapshot.takeSnapshot()
        defaults.putString("first.read", "value")
        val read = snapshot.enter { defaults.getString("first.read") }
        snapshot.dispose()
        assertEquals("value", read)
    }
}
