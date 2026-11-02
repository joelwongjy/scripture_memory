package joel.scripturememory.system

import android.content.Context
import android.content.Intent
import android.net.Uri
import joel.scripturememory.MainActivity

data class DeepLink(val uri: Uri, val source: String? = null) {

    val isExternal: Boolean get() = source == null

    companion object {
        const val scheme = "scripturememory"
        const val sourceExtra = "source"
        const val reminderSource = "reminder"

        val review: Uri = Uri.Builder().scheme(scheme).authority("review").build()

        fun read(pack: String, book: String, reference: String): Uri =
            Uri.Builder()
                .scheme(scheme)
                .authority("read")
                .appendQueryParameter("pack", pack)
                .appendQueryParameter("book", book)
                .appendQueryParameter("ref", reference)
                .build()

        fun intent(context: Context, uri: Uri, source: String? = null): Intent =
            Intent(Intent.ACTION_VIEW, uri, context, MainActivity::class.java).apply {
                if (source != null) putExtra(sourceExtra, source)
            }

        fun from(intent: Intent): DeepLink? {
            val uri = intent.data ?: return null
            if (uri.scheme != scheme) return null
            return DeepLink(uri, intent.getStringExtra(sourceExtra))
        }
    }
}
