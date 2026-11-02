package joel.scripturememory

import android.app.Application
import joel.scripturememory.model.ScriptureModel
import joel.scripturememory.model.SharedPrefsStore
import joel.scripturememory.system.Analytics
import joel.scripturememory.system.HapticEngine
import joel.scripturememory.system.NotificationManager
import joel.scripturememory.widget.WidgetBridge

class ScriptureApp : Application() {
    override fun onCreate() {
        super.onCreate()
        ScriptureModel.initialize(SharedPrefsStore(this), assets::open, filesDir)
        HapticEngine.start(this)
        Analytics.configure(this)
        NotificationManager.configure(this)
        WidgetBridge.configure(this)
    }
}
