package joel.scripturememory.system

import android.content.ContentResolver
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.OpenableColumns
import java.io.File
import joel.scripturememory.model.AnkiImportException

data class OpenedFile(val uri: Uri, val isNamedAnki: Boolean) {

    companion object {
        private val ankiTypes = setOf("application/apkg", "application/x-apkg", "application/vnd.anki")
        private val ankiExtensions = setOf("apkg", "colpkg")

        fun from(context: Context, intent: Intent): OpenedFile? {
            val uri = when (intent.action) {
                Intent.ACTION_VIEW -> intent.data
                Intent.ACTION_SEND -> stream(intent)
                else -> null
            } ?: return null
            if (uri.scheme != ContentResolver.SCHEME_CONTENT && uri.scheme != ContentResolver.SCHEME_FILE) return null
            val type = (intent.type ?: context.contentResolver.getType(uri))?.lowercase()
            val extension = extension(displayName(context, uri) ?: uri.lastPathSegment)
            return OpenedFile(uri, type in ankiTypes || extension in ankiExtensions)
        }

        fun copyToCache(context: Context, uri: Uri, fallbackExtension: String? = null): File {
            val extension = extension(displayName(context, uri))
                .takeIf { fallbackExtension == null || it in ankiExtensions }
                ?: fallbackExtension.orEmpty()
            val directory = File(context.cacheDir, "anki-import").apply { mkdirs() }
            val file = File(directory, "import-${System.currentTimeMillis()}" + if (extension.isEmpty()) "" else ".$extension")
            val input = try {
                context.contentResolver.openInputStream(uri)
            } catch (_: Exception) {
                null
            } ?: throw AnkiImportException.Unreadable
            input.use { source -> file.outputStream().use { source.copyTo(it) } }
            return file
        }

        private fun stream(intent: Intent): Uri? =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
            } else {
                @Suppress("DEPRECATION")
                intent.getParcelableExtra(Intent.EXTRA_STREAM)
            }

        private fun displayName(context: Context, uri: Uri): String? = try {
            context.contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)
                ?.use { cursor -> if (cursor.moveToFirst()) cursor.getString(0) else null }
        } catch (_: Exception) {
            null
        }

        private fun extension(name: String?): String =
            name?.substringAfterLast('.', "")?.lowercase()?.filter { it.isLetterOrDigit() }.orEmpty()
    }
}
