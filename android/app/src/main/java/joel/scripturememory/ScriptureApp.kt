package joel.scripturememory

import android.app.Application
import joel.scripturememory.model.ScriptureModel
import joel.scripturememory.model.SharedPrefsStore
import joel.scripturememory.system.HapticEngine

class ScriptureApp : Application() {
    override fun onCreate() {
        super.onCreate()
        ScriptureModel.initialize(SharedPrefsStore(this), assets::open, filesDir)
        HapticEngine.start(this)
    }
}
