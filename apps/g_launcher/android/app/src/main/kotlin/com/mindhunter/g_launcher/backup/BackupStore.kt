package com.mindhunter.g_launcher.backup

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.provider.DocumentsContract
import androidx.core.content.FileProvider
import java.io.File
import org.json.JSONObject

/**
 * The user's own folder, and everything the launcher does inside it.
 *
 * ─── WHY THIS EXISTS AT ALL ─────────────────────────────────────────────────
 *
 * `FilePicker.saveFile` puts up a dialog every time, so it can never run
 * unattended, and the string it hands back is a one-shot document URI that Dart
 * cannot read again. A scheduled backup and a list of files in a folder both
 * need a grant that outlives the dialog, which is `ACTION_OPEN_DOCUMENT_TREE`
 * plus `takePersistableUriPermission`, and that pair is only reachable from
 * native.
 *
 * ─── NOT MANAGE_EXTERNAL_STORAGE, AND NOT A PATH ────────────────────────────
 *
 * The alternative was all-files access, which is a Play declaration, a review
 * conversation, and a permission a privacy-facing launcher should not want. A
 * tree grant is one folder the user picked, revocable by them, invisible to us
 * otherwise. The cost is that everything here goes through DocumentsContract
 * rather than `java.io.File`, which is why no method in this class takes a path.
 *
 * ─── DocumentsContract, NOT androidx.documentfile ───────────────────────────
 *
 * `DocumentFile` is the friendlier API and it is a dependency this module does
 * not currently carry. The four operations below are one contract call each, so
 * the wrapper would buy convenience at the price of a library in the build for
 * a class with no other user.
 *
 * ─── THE GRANT IS VERIFIED, NEVER ASSUMED ───────────────────────────────────
 *
 * The stored string is checked against `persistedUriPermissions` on every read.
 * A user can revoke a tree from system settings at any time, and a launcher
 * that kept showing the folder name would fail every write with nothing to say
 * about it. A revoked grant drops the string, so the next ask is a fresh pick.
 */
class BackupStore(context: Context) {

    private val appContext = context.applicationContext
    private val resolver get() = appContext.contentResolver

    private val prefs =
        appContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    /** Waiting for the picker to come back. One at a time by construction. */
    private var pending: ((String?) -> Unit)? = null

    // ── THE GRANT ───────────────────────────────────────────────────────────

    /** The tree URI, or null when there is none or the grant was revoked. */
    fun treeUri(): Uri? {
        val saved = prefs.getString(KEY_TREE, null) ?: return null
        val uri = runCatching { Uri.parse(saved) }.getOrNull() ?: return null

        val held = runCatching {
            resolver.persistedUriPermissions.any {
                it.uri == uri && it.isReadPermission && it.isWritePermission
            }
        }.getOrDefault(false)

        if (!held) {
            // Self-healing rather than sticky. Keeping a string whose grant is
            // gone would mean every later call failing for a reason the user
            // cannot see from the settings row.
            prefs.edit().remove(KEY_TREE).apply()
            return null
        }
        return uri
    }

    /** The folder's display name, or null when there is no usable grant. */
    fun label(): String? {
        val tree = treeUri() ?: return null
        val doc = runCatching { documentUri(tree) }.getOrNull() ?: return null
        return runCatching {
            resolver.query(
                doc,
                arrayOf(DocumentsContract.Document.COLUMN_DISPLAY_NAME),
                null,
                null,
                null,
            )?.use { if (it.moveToFirst()) it.getString(0) else null }
        }.getOrNull()
    }

    fun forget() {
        val uri = runCatching { Uri.parse(prefs.getString(KEY_TREE, null) ?: "") }
            .getOrNull()
        prefs.edit().remove(KEY_TREE).apply()
        if (uri == null) return
        // Released as well as forgotten. A grant we no longer use still shows
        // up in the system's list of what this app can reach, and leaving it
        // there contradicts the row the user just switched off.
        runCatching {
            resolver.releasePersistableUriPermission(
                uri,
                Intent.FLAG_GRANT_READ_URI_PERMISSION or
                    Intent.FLAG_GRANT_WRITE_URI_PERMISSION,
            )
        }
    }

    /**
     * Open the system folder picker. [callback] gets the folder's display name,
     * or null when the user backed out, no Activity is attached, or the device
     * has nothing that answers the intent.
     */
    fun choose(activity: Activity?, callback: (String?) -> Unit) {
        if (activity == null) {
            callback(null)
            return
        }

        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
            addFlags(
                Intent.FLAG_GRANT_READ_URI_PERMISSION or
                    Intent.FLAG_GRANT_WRITE_URI_PERMISSION or
                    Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION,
            )
        }

        pending = callback
        // From the ACTIVITY, not the application context, and for the reason
        // `requestUninstall` documents at length: a NEW_TASK start from the
        // application context is not reliably brought to the front over the
        // home task on One UI.
        runCatching { activity.startActivityForResult(intent, REQ_TREE) }
            .onFailure {
                pending = null
                callback(null)
            }
    }

    /** Routed from `LauncherHostApiImpl.onActivityResult`. True if consumed. */
    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != REQ_TREE) return false

        val callback = pending
        pending = null
        // Consumed either way. A result arriving with no callback waiting means
        // the Activity was rebuilt while the picker was up, and passing it on
        // would hand another router a request code it does not own.
        if (callback == null) return true

        val uri = if (resultCode == Activity.RESULT_OK) data?.data else null
        if (uri == null) {
            callback(null)
            return true
        }

        val taken = runCatching {
            // THE line that makes the grant survive a reboot. Without it the
            // URI is valid until the process dies and then silently is not,
            // which reads as backups stopping for no reason.
            resolver.takePersistableUriPermission(
                uri,
                Intent.FLAG_GRANT_READ_URI_PERMISSION or
                    Intent.FLAG_GRANT_WRITE_URI_PERMISSION,
            )
        }.isSuccess

        if (!taken) {
            callback(null)
            return true
        }

        prefs.edit().putString(KEY_TREE, uri.toString()).apply()
        callback(label())
        return true
    }

    // ── FILES ───────────────────────────────────────────────────────────────

    /** Returns the new document URI, or null when nothing could be written. */
    fun write(fileName: String, bytes: ByteArray): String? {
        val tree = treeUri() ?: return null
        return runCatching {
            val parent = documentUri(tree)
            val doc = DocumentsContract.createDocument(
                resolver,
                parent,
                MIME,
                fileName,
            ) ?: return null

            // "w", not "wt". Truncation is meaningless on a document that was
            // created a line ago, and some providers reject the mode.
            resolver.openOutputStream(doc, "w")?.use { it.write(bytes) }
                ?: return null

            doc.toString()
        }.getOrNull()
    }

    /**
     * Everything in the folder that looks like one of ours, newest first.
     *
     * Filtered by extension, not by name. A file the user renamed is still
     * listed and still sniffed on the Dart side, which is the check that
     * decides whether it is really a backup.
     */
    fun list(): List<String> {
        val tree = treeUri() ?: return emptyList()

        return runCatching {
            val children = DocumentsContract.buildChildDocumentsUriUsingTree(
                tree,
                DocumentsContract.getTreeDocumentId(tree),
            )

            val rows = mutableListOf<JSONObject>()
            resolver.query(
                children,
                arrayOf(
                    DocumentsContract.Document.COLUMN_DOCUMENT_ID,
                    DocumentsContract.Document.COLUMN_DISPLAY_NAME,
                    DocumentsContract.Document.COLUMN_SIZE,
                    DocumentsContract.Document.COLUMN_LAST_MODIFIED,
                ),
                null,
                null,
                null,
            )?.use { c ->
                while (c.moveToNext()) {
                    val name = c.getString(1) ?: continue
                    if (EXTENSIONS.none { name.endsWith(it, ignoreCase = true) }) {
                        continue
                    }
                    val doc = DocumentsContract.buildDocumentUriUsingTree(
                        tree,
                        c.getString(0),
                    )
                    rows += JSONObject().apply {
                        put("uri", doc.toString())
                        put("name", name)
                        put("size", if (c.isNull(2)) 0L else c.getLong(2))
                        put("modified", if (c.isNull(3)) 0L else c.getLong(3))
                    }
                }
            }

            rows
                .sortedByDescending { it.optLong("modified") }
                .map { it.toString() }
        }.getOrDefault(emptyList())
    }

    fun read(documentUri: String): ByteArray? = runCatching {
        resolver.openInputStream(Uri.parse(documentUri))?.use { it.readBytes() }
    }.getOrNull()

    fun delete(documentUri: String): Boolean = runCatching {
        DocumentsContract.deleteDocument(resolver, Uri.parse(documentUri))
    }.getOrDefault(false)

    // ── SHARING ─────────────────────────────────────────────────────────────

    /**
     * Write one copy into the cache and return a URI another app can read.
     *
     * ─── THE CACHE, AND ONE FILE AT A TIME ──────────────────────────────────
     *
     * The directory is cleared before each write, so exactly one staged backup
     * exists at a time. A share sheet the user dismissed leaves a file behind
     * with nothing to delete it, and three of those on a phone chosen for being
     * cheap is tens of megabytes of nothing.
     *
     * Clearing on the way IN rather than on the way out, because there is no
     * way out: the receiving app reads the URI after we have stopped caring,
     * and deleting on return would race a Quick Share transfer still in
     * progress.
     */
    fun stageForShare(fileName: String, bytes: ByteArray): Uri? = runCatching {
        val dir = File(appContext.cacheDir, SHARE_DIR)
        if (dir.exists()) dir.listFiles()?.forEach { it.delete() } else dir.mkdirs()

        val file = File(dir, fileName)
        file.writeBytes(bytes)

        FileProvider.getUriForFile(
            appContext,
            "${appContext.packageName}$AUTHORITY_SUFFIX",
            file,
        )
    }.getOrNull()

    /**
     * Put the share sheet up for a staged URI.
     *
     * FLAG_GRANT_READ_URI_PERMISSION is what makes the receiving app able to
     * open it at all; the FileProvider grant is per-intent and does not outlive
     * the transfer.
     *
     * From the ACTIVITY for the same reason `choose` is: a NEW_TASK chooser
     * started from the application context is not reliably brought to the front
     * over the home task.
     */
    fun share(activity: Activity?, uri: Uri): Boolean {
        if (activity == null) return false

        val send = Intent(Intent.ACTION_SEND).apply {
            type = MIME
            putExtra(Intent.EXTRA_STREAM, uri)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }

        return runCatching {
            // createChooser, not the bare intent. Without it Android may apply a
            // default handler the user set for some unrelated file, and a backup
            // silently going to the wrong app is worse than one extra tap.
            activity.startActivity(Intent.createChooser(send, null))
            true
        }.getOrDefault(false)
    }

    /** The tree's own document URI, which is what create and query hang off. */
    private fun documentUri(tree: Uri): Uri =
        DocumentsContract.buildDocumentUriUsingTree(
            tree,
            DocumentsContract.getTreeDocumentId(tree),
        )

    private companion object {
        const val PREFS = "g_launcher_backup"
        const val KEY_TREE = "tree"

        /**
         * Must not collide with WidgetHostController's REQ_BIND (0x0B1D) or
         * REQ_CONFIG (0x0C06), or LauncherHostApiImpl's REQ_SPEECH (0x05EE).
         * Every router sees every result, and two owners claiming one code
         * means whichever is asked first eats the other's answer.
         */
        const val REQ_TREE = 0x0BAC

        /**
         * `application/octet-stream`, not `application/zip`.
         *
         * A provider is allowed to append an extension it derives from the MIME
         * type, and declaring zip is how `g-launcher-2026-09-13.glbak` becomes
         * `g-launcher-2026-09-13.glbak.zip` on some of them. The generic type
         * leaves the name we asked for alone on every provider tested, and the
         * container is identified by its first two bytes anyway.
         */
        const val MIME = "application/octet-stream"

        val EXTENSIONS = listOf(".glbak", ".json")

        /** Under cacheDir, and declared in res/xml/file_paths.xml. */
        const val SHARE_DIR = "shared"

        /**
         * Must match the authority in the manifest's provider block. Suffixed
         * onto the package rather than hardcoded, so the debug build's
         * `.debug` applicationId resolves to its own authority instead of
         * colliding with release on a phone carrying both.
         */
        const val AUTHORITY_SUFFIX = ".files"
    }
}
