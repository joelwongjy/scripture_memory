package joel.scripturememory.system

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import joel.scripturememory.widget.WidgetBridge

class ReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        NotificationManager.post(intent)
    }
}

class RearmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val pending = goAsync()
        Background.launch {
            try {
                NotificationManager.refreshFromSettings()
                WidgetBridge.sync().join()
            } finally {
                pending.finish()
            }
        }
    }
}
