package com.mindhunter.g_launcher.terminal

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.database.Cursor
import android.net.Uri
import android.os.Build
import android.provider.DocumentsContract
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.BufferedReader
import java.io.InputStreamReader

/**
 * The storage half of the terminal shell.
 *
 * ─── SAF, NOT ALL FILES ACCESS ──────────────────────────────────────────────
 *
 * One ACTION_OPEN_DOCUMENT_TREE grant, persisted with
 * takePersistableUriPermission, and every path the shell sends is resolved
 * BELOW that tree. A path can therefore never address anything the user did not
 * hand over, which is a stronger guarantee than MANAGE_EXTERNAL_STORAGE gives
 * and needs no Play declaration to obtain.
 *
 * ─── DocumentsContract, NOT androidx.documentfile ───────────────────────────
 *
 * DocumentFile would be friendlier and would add a gradle dependency for what
 * amounts to a wrapper over the queries below. It also does one findFile query
 * per path segment, which is what this does anyway. No new dependency is worth
 * more here than the convenience.
 *
 * ─── A PLAIN CHANNEL, NOT PIGEON ────────────────────────────────────────────
 *
 * Same reason NotificationBadges.kt gives. A file bridge wants a result object
 * with an ok flag and a reason, and launcher_api's codec is one a shipped APK
 * already agrees on. A channel needs no schema and cannot renumber anything.
 */
class FilesBridge(private val context: Context) {

    companion object {
        private const val CHANNEL = "g_launcher/files"
        const val REQUEST_TREE = 4711

        /** Where the persisted tree uri is kept. Its own file, not prefs. */
        private const val STORE = "terminal_files"
        private const val KEY_TREE = "tree_uri"
    }

    private var channel: MethodChannel? = null
    private var activity: Activity? = null
    private var pendingGrant: MethodChannel.Result? = null

    fun attach(engine: FlutterEngine) {
        channel = MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL).also {
            it.setMethodCallHandler(::onCall)
        }
    }

    fun detach() {
        channel?.setMethodCallHandler(null)
        channel = null
        activity = null
    }

    fun bindActivity(activity: Activity?) {
        this.activity = activity
    }

    // ── the tree ────────────────────────────────────────────────────────
    private val prefs by lazy { context.getSharedPreferences(STORE, Context.MODE_PRIVATE) }

    private fun treeUri(): Uri? {
        val stored = prefs.getString(KEY_TREE, null) ?: return null
        val uri = Uri.parse(stored)
        // A grant can be revoked from Settings and we are never told, so the
        // stored value is checked against what we actually still hold rather
        // than trusted. A stale flag would make every verb fail with a
        // permission error instead of asking for the folder again.
        val held = context.contentResolver.persistedUriPermissions.any {
            it.uri == uri && it.isReadPermission
        }
        return if (held) uri else null
    }

    private fun onCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "hasGrant" -> result.success(treeUri() != null)
                "requestGrant" -> requestGrant(result)
                "list" -> result.success(list(segments(call, "segments")))
                "stat" -> result.success(stat(segments(call, "segments")))
                "read" -> result.success(
                    read(segments(call, "segments"), call.argument<Int>("maxLines") ?: 200)
                )
                "size" -> result.success(size(segments(call, "segments")))
                "mkdir" -> result.success(create(segments(call, "segments"), true))
                "create" -> result.success(create(segments(call, "segments"), false))
                "delete" -> result.success(delete(segments(call, "segments")))
                "copy" -> result.success(
                    transfer(segments(call, "from"), segments(call, "to"), false)
                )
                "move" -> result.success(
                    transfer(segments(call, "from"), segments(call, "to"), true)
                )
                "open" -> result.success(open(segments(call, "segments")))
                else -> result.notImplemented()
            }
        } catch (e: Exception) {
            // Every failure is the same answer to the shell: unavailable. A
            // thrown PlatformException would be caught in Dart and turned into
            // null anyway, so failing quietly with a reason is strictly better.
            result.success(fail(e.message ?: "storage error"))
        }
    }

    @Suppress("UNCHECKED_CAST")
    private fun segments(call: MethodCall, key: String): List<String> =
        (call.argument<List<String>>(key) ?: emptyList())

    private fun requestGrant(result: MethodChannel.Result) {
        val current = activity
        if (current == null) {
            result.success(false)
            return
        }
        if (treeUri() != null) {
            result.success(true)
            return
        }
        pendingGrant = result
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
            addFlags(
                Intent.FLAG_GRANT_READ_URI_PERMISSION or
                    Intent.FLAG_GRANT_WRITE_URI_PERMISSION or
                    Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION
            )
        }
        current.startActivityForResult(intent, REQUEST_TREE)
    }

    /** Call from MainActivity.onActivityResult. */
    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != REQUEST_TREE) return false
        val waiting = pendingGrant
        pendingGrant = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            waiting?.success(false)
            return true
        }
        context.contentResolver.takePersistableUriPermission(
            uri,
            Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION
        )
        prefs.edit().putString(KEY_TREE, uri.toString()).apply()
        waiting?.success(true)
        return true
    }

    // ── resolution ──────────────────────────────────────────────────────
    private data class Doc(val uri: Uri, val name: String, val mime: String, val size: Long?, val modified: Long?)

    private val Doc.isDirectory: Boolean
        get() = mime == DocumentsContract.Document.MIME_TYPE_DIR

    private fun root(): Uri? {
        val tree = treeUri() ?: return null
        return DocumentsContract.buildDocumentUriUsingTree(
            tree,
            DocumentsContract.getTreeDocumentId(tree)
        )
    }

    /** Walk the segments one query at a time. Null at the first miss. */
    private fun resolve(segments: List<String>): Doc? {
        val start = root() ?: return null
        var current = docOf(start) ?: return null
        for (segment in segments) {
            current = childNamed(current.uri, segment) ?: return null
        }
        return current
    }

    private fun docOf(uri: Uri): Doc? {
        val projection = arrayOf(
            DocumentsContract.Document.COLUMN_DISPLAY_NAME,
            DocumentsContract.Document.COLUMN_MIME_TYPE,
            DocumentsContract.Document.COLUMN_SIZE,
            DocumentsContract.Document.COLUMN_LAST_MODIFIED
        )
        context.contentResolver.query(uri, projection, null, null, null)?.use { c ->
            if (c.moveToFirst()) return readRow(c, uri)
        }
        return null
    }

    private fun childNamed(parent: Uri, name: String): Doc? {
        for (child in children(parent)) {
            if (child.name == name) return child
        }
        return null
    }

    private fun children(parent: Uri): List<Doc> {
        val tree = treeUri() ?: return emptyList()
        val childrenUri = DocumentsContract.buildChildDocumentsUriUsingTree(
            tree,
            DocumentsContract.getDocumentId(parent)
        )
        val projection = arrayOf(
            DocumentsContract.Document.COLUMN_DOCUMENT_ID,
            DocumentsContract.Document.COLUMN_DISPLAY_NAME,
            DocumentsContract.Document.COLUMN_MIME_TYPE,
            DocumentsContract.Document.COLUMN_SIZE,
            DocumentsContract.Document.COLUMN_LAST_MODIFIED
        )
        val out = ArrayList<Doc>()
        context.contentResolver.query(childrenUri, projection, null, null, null)?.use { c ->
            val idIndex = c.getColumnIndex(DocumentsContract.Document.COLUMN_DOCUMENT_ID)
            while (c.moveToNext()) {
                val id = c.getString(idIndex) ?: continue
                val uri = DocumentsContract.buildDocumentUriUsingTree(tree, id)
                out.add(readRow(c, uri))
            }
        }
        return out
    }

    private fun readRow(c: Cursor, uri: Uri): Doc {
        fun str(column: String): String? {
            val i = c.getColumnIndex(column)
            return if (i < 0 || c.isNull(i)) null else c.getString(i)
        }
        fun long(column: String): Long? {
            val i = c.getColumnIndex(column)
            return if (i < 0 || c.isNull(i)) null else c.getLong(i)
        }
        return Doc(
            uri = uri,
            name = str(DocumentsContract.Document.COLUMN_DISPLAY_NAME) ?: "",
            mime = str(DocumentsContract.Document.COLUMN_MIME_TYPE) ?: "",
            // NULL, not zero. A provider that does not report a size is a
            // provider that does not know one, and the shell prints no row
            // rather than a fabricated 0B.
            size = long(DocumentsContract.Document.COLUMN_SIZE),
            modified = long(DocumentsContract.Document.COLUMN_LAST_MODIFIED)
        )
    }

    // ── the verbs ───────────────────────────────────────────────────────
    private fun entry(doc: Doc): Map<String, Any?> = mapOf(
        "name" to doc.name,
        "dir" to doc.isDirectory,
        "size" to doc.size?.toInt(),
        "modified" to doc.modified
    )

    private fun list(segments: List<String>): List<Map<String, Any?>>? {
        val doc = resolve(segments) ?: return null
        if (!doc.isDirectory) return null
        return children(doc.uri).map(::entry)
    }

    private fun stat(segments: List<String>): Map<String, Any?>? =
        resolve(segments)?.let(::entry)

    private fun read(segments: List<String>, maxLines: Int): List<String>? {
        val doc = resolve(segments) ?: return null
        if (doc.isDirectory) return null
        // Text only. A binary read would come back as replacement characters,
        // which looks like a corrupt file rather than the wrong verb, so the
        // shell is told null and prints its "open hands it to an app" line.
        if (!doc.mime.startsWith("text/") &&
            doc.mime != "application/json" &&
            doc.mime != "application/xml"
        ) {
            return null
        }
        val out = ArrayList<String>()
        context.contentResolver.openInputStream(doc.uri)?.use { stream ->
            BufferedReader(InputStreamReader(stream)).use { reader ->
                while (out.size < maxLines) {
                    val line = reader.readLine() ?: break
                    out.add(line)
                }
            }
        } ?: return null
        return out
    }

    private fun size(segments: List<String>): Int? {
        val doc = resolve(segments) ?: return null
        if (!doc.isDirectory) return doc.size?.toInt()
        // Recursive, bounded. A tree walk over a whole SD card would hang the
        // shell, and a partial figure presented as a total is exactly the kind
        // of number this project refuses to print, so the walk stops and the
        // reading becomes unavailable rather than wrong.
        var total = 0L
        var visited = 0
        val stack = ArrayDeque<Uri>()
        stack.addLast(doc.uri)
        while (stack.isNotEmpty()) {
            if (visited > 4000) return null
            val next = stack.removeLast()
            for (child in children(next)) {
                visited++
                if (child.isDirectory) stack.addLast(child.uri) else total += child.size ?: 0L
            }
        }
        return total.toInt()
    }

    private fun create(segments: List<String>, directory: Boolean): Map<String, Any?> {
        if (segments.isEmpty()) return fail("nothing to create")
        val parent = resolve(segments.dropLast(1)) ?: return fail("no parent folder")
        val name = segments.last()
        if (childNamed(parent.uri, name) != null) return fail("$name already exists")
        val mime = if (directory) {
            DocumentsContract.Document.MIME_TYPE_DIR
        } else {
            "application/octet-stream"
        }
        DocumentsContract.createDocument(
            context.contentResolver, parent.uri, mime, name
        ) ?: return fail("the folder refused to create it")
        return ok("created ${segments.joinToString("/")}")
    }

    private fun delete(segments: List<String>): Map<String, Any?> {
        val doc = resolve(segments) ?: return fail("no such file")
        // SAF deletes a directory and its contents in one call, so the
        // recursive flag is enforced in Dart where the user's intent is known
        // rather than here where it cannot be.
        val gone = DocumentsContract.deleteDocument(context.contentResolver, doc.uri)
        return if (gone) ok() else fail("the folder refused to delete it")
    }

    private fun transfer(from: List<String>, to: List<String>, move: Boolean): Map<String, Any?> {
        val source = resolve(from) ?: return fail("no such file")
        val sourceParent = resolve(from.dropLast(1)) ?: return fail("no parent folder")
        val target = resolve(to) ?: return fail("no such destination")
        val destination = if (target.isDirectory) target else return fail("destination is not a folder")

        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N) {
            return fail("this Android version cannot move documents")
        }
        return try {
            val moved = if (move) {
                DocumentsContract.moveDocument(
                    context.contentResolver, source.uri, sourceParent.uri, destination.uri
                )
            } else {
                DocumentsContract.copyDocument(
                    context.contentResolver, source.uri, destination.uri
                )
            }
            if (moved != null) ok() else fail("the provider refused")
        } catch (e: UnsupportedOperationException) {
            // Not every document provider implements copy or move, and the ones
            // that do not throw rather than return null.
            fail("this folder's provider does not support ${if (move) "move" else "copy"}")
        }
    }

    private fun open(segments: List<String>): Map<String, Any?> {
        val doc = resolve(segments) ?: return fail("no such file")
        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(doc.uri, doc.mime)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        return try {
            context.startActivity(intent)
            ok("opening ${doc.name}")
        } catch (e: Exception) {
            fail("no app on this device opens ${doc.mime}")
        }
    }

    private fun ok(message: String? = null): Map<String, Any?> =
        mapOf("ok" to true, "message" to message)

    private fun fail(message: String): Map<String, Any?> =
        mapOf("ok" to false, "message" to message)
}
