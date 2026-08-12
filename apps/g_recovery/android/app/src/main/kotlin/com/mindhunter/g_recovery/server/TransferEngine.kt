package com.mindhunter.g_recovery.server

import android.content.Context
import android.content.SharedPreferences
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import java.security.MessageDigest
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

/**
 * COPYING FILES TO A MACHINE THE USER OWNS.
 *
 * ─── ONE WAY, AND THE CLASS CANNOT EXPRESS ANYTHING ELSE ─────────────────────
 *
 * Files go up. There is no read from the server here beyond asking whether a
 * file exists and how large it is, and no delete of anything remote. A file
 * removed on the server must never affect the phone, and the guarantee is
 * structural rather than a rule someone has to remember.
 *
 * ─── A LEDGER, SO A SECOND RUN IS CHEAP ──────────────────────────────────────
 *
 * Every successful upload is recorded as media id to size. A later run skips a
 * file whose id is in the ledger AND whose size still matches, so a nightly
 * backup of four thousand photos does almost no work.
 *
 * Size rather than a hash on the fast path. Hashing every file locally each
 * night would read the entire library from disk to answer a question that a
 * changed size answers for nearly every real edit. The checksum is kept for
 * the reclaim flow, which is the one place being wrong destroys something.
 *
 * ─── FAILURES ARE COUNTED, NOT RETRIED FOREVER ───────────────────────────────
 *
 * A run over thousands of files will meet one the server refuses. Stopping would
 * mean one bad file blocks every backup after it; retrying forever is how a
 * backup appears to run all night and achieve nothing. It is counted and
 * reported.
 */
internal class TransferEngine(context: Context) {

    private val app: Context = context.applicationContext
    private val collection =
        MediaStore.Files.getContentUri(MediaStore.VOLUME_EXTERNAL)

    private val ledger: SharedPreferences =
        app.getSharedPreferences(LEDGER, Context.MODE_PRIVATE)

    @Volatile
    private var state = TransferState(
        running = false,
        // L on every one of these. Pigeon maps a Dart int to a Kotlin Long, so
        // a bare 0 here is an Int and will not compile against the generated
        // constructor.
        sent = 0L,
        total = 0L,
        bytesSent = 0L,
        bytesTotal = 0L,
        currentName = null,
        failed = 0L,
        lastRunMillis = null,
        lastError = null,
    )

    fun snapshot(): TransferState = state

    fun run(config: ServerConfig, password: String, cancelled: AtomicBoolean) {
        val transport = openTransport(config, password)
        try {
            runOn(transport, cancelled)
        } finally {
            transport.close()
        }
    }

    /**
     * The copy itself, once a transport is open.
     *
     * Split from [run] only so the transport can be closed in a finally without
     * indenting this entire method. Nothing below here knows which protocol it
     * is talking to.
     */
    private fun runOn(transport: RemoteTransport, cancelled: AtomicBoolean) {
        val probe = transport.probe()
        if (!probe.reachable || !probe.writable) {
            state = state.copy(
                running = false,
                lastRunMillis = System.currentTimeMillis(),
                // The probe already phrased this for a person. Passing it
                // through unchanged beats wrapping it in "backup failed", which
                // says nothing about what to do.
                lastError = probe.detail,
            )
            return
        }

        val rows = candidates()
        state = TransferState(
            running = true,
            sent = 0L,
            total = rows.size.toLong(),
            bytesSent = 0L,
            bytesTotal = rows.sumOf { it.size },
            currentName = null,
            failed = 0L,
            lastRunMillis = state.lastRunMillis,
            lastError = null,
        )

        var sent = 0L
        var failed = 0L
        var bytes = 0L

        for (row in rows) {
            if (cancelled.get()) break

            state = state.copy(currentName = row.name)

            val ok = runCatching {
                app.contentResolver.openInputStream(row.uri)?.use { stream ->
                    transport.put(row.relative, stream, row.size) { soFar ->
                        state = state.copy(bytesSent = bytes + soFar)
                    }
                } ?: false
            }.getOrDefault(false)

            if (ok) {
                sent++
                bytes += row.size
                ledger.edit().putLong(row.mediaId.toString(), row.size).apply()
            } else {
                failed++
            }

            state = state.copy(
                sent = sent,
                failed = failed,
                bytesSent = bytes,
            )
        }

        state = state.copy(
            running = false,
            currentName = null,
            lastRunMillis = System.currentTimeMillis(),
            lastError = if (failed == 0L) {
                null
            } else {
                "$failed ${if (failed == 1L) "file" else "files"} could not be " +
                    "copied. They will be tried again next time."
            },
        )
    }

    /**
     * Local files whose copy on the server has been checked.
     *
     * ─── VERIFIED MEANS VERIFIED NOW, NOT VERIFIED ONCE ──────────────────────
     *
     * The ledger says a file was uploaded. That is not enough to delete an
     * original: the interesting failure is a file that went up months ago and
     * has since been moved, truncated, or lost to a rebuilt array. So this asks
     * the server for the size TODAY and compares it, and anything that does not
     * match comes back unverified and is offered to nobody.
     */
    fun reclaimable(
        config: ServerConfig,
        password: String,
        limit: Int,
    ): List<ReclaimCandidate> {
        val transport = openTransport(config, password)
        return try {
            reclaimableOn(transport, limit)
        } finally {
            transport.close()
        }
    }

    private fun reclaimableOn(
        transport: RemoteTransport,
        limit: Int,
    ): List<ReclaimCandidate> {
        val out = mutableListOf<ReclaimCandidate>()

        for (row in candidates(includeUploaded = true)) {
            if (out.size >= limit) break
            val recorded = ledger.getLong(row.mediaId.toString(), -1L)
            if (recorded < 0) continue

            val remote = transport.sizeOf(row.relative)
            out += ReclaimCandidate(
                fileId = "file:${row.mediaId}",
                name = row.name,
                sizeBytes = row.size,
                verified = remote != null && remote == row.size,
            )
        }
        return out
    }

    /**
     * Hashes both sides of the chosen files and returns the ids that matched.
     *
     * ─── ANYTHING NOT RETURNED MUST NOT BE DELETED ───────────────────────────
     *
     * A file that throws, that is missing on the server, or whose hashes differ
     * is simply absent from the result. The caller deletes only what came back,
     * so a failure here can never cause a loss; it can only cause a file to
     * stay on the phone, which is the safe direction to be wrong in.
     *
     * Slow on purpose. Two full reads per file, one local and one over the
     * network, and the caller shows progress rather than pretending it is
     * instant.
     */
    fun verify(
        config: ServerConfig,
        password: String,
        fileIds: List<String>,
    ): List<String> {
        val transport = openTransport(config, password)
        return try {
            verifyOn(transport, fileIds)
        } finally {
            transport.close()
        }
    }

    private fun verifyOn(
        transport: RemoteTransport,
        fileIds: List<String>,
    ): List<String> {
        val wanted = fileIds.toSet()
        val out = mutableListOf<String>()

        for (row in candidates(includeUploaded = true)) {
            val id = "file:${row.mediaId}"
            if (id !in wanted) continue

            val local = checksum(row.uri) ?: continue
            val remote = transport.sha256Of(row.relative) ?: continue
            if (local == remote) out += id
        }
        return out
    }

    /**
     * What is worth sending.
     *
     * Photos and video only for now. Documents are a setting on the screen and
     * will widen this; the message archive is a single file and goes through a
     * different path entirely.
     */
    private fun candidates(includeUploaded: Boolean = false): List<Row> {
        val out = mutableListOf<Row>()
        val projection = arrayOf(
            MediaStore.Files.FileColumns._ID,
            MediaStore.Files.FileColumns.DISPLAY_NAME,
            MediaStore.Files.FileColumns.SIZE,
            MediaStore.Files.FileColumns.RELATIVE_PATH,
            MediaStore.Files.FileColumns.MEDIA_TYPE,
        )
        val where = "${MediaStore.Files.FileColumns.MEDIA_TYPE} IN (?, ?) AND " +
            "${MediaStore.Files.FileColumns.SIZE} > 0"
        val args = arrayOf(
            MediaStore.Files.FileColumns.MEDIA_TYPE_IMAGE.toString(),
            MediaStore.Files.FileColumns.MEDIA_TYPE_VIDEO.toString(),
        )

        app.contentResolver.query(
            collection,
            projection,
            where,
            args,
            "${MediaStore.Files.FileColumns.DATE_MODIFIED} DESC",
        )?.use { cursor ->
            val idAt = cursor.getColumnIndexOrThrow(MediaStore.Files.FileColumns._ID)
            val nameAt =
                cursor.getColumnIndexOrThrow(MediaStore.Files.FileColumns.DISPLAY_NAME)
            val sizeAt =
                cursor.getColumnIndexOrThrow(MediaStore.Files.FileColumns.SIZE)
            val pathAt =
                cursor.getColumnIndexOrThrow(MediaStore.Files.FileColumns.RELATIVE_PATH)

            while (cursor.moveToNext()) {
                val id = cursor.getLong(idAt)
                val size = cursor.getLong(sizeAt)

                if (!includeUploaded) {
                    // Already up, and unchanged. Size is the cheap test and it
                    // catches nearly every real edit.
                    val recorded = ledger.getLong(id.toString(), -1L)
                    if (recorded == size) continue
                }

                val name = cursor.getString(nameAt) ?: "file_$id"
                val folder = cursor.getString(pathAt).orEmpty().trim('/')

                out += Row(
                    mediaId = id,
                    name = name,
                    size = size,
                    // The phone's own folder structure is preserved on the
                    // server. A backup that flattened everything into one
                    // directory would be a backup nobody could use without this
                    // app, which is the opposite of the point.
                    relative = if (folder.isEmpty()) name else "$folder/$name",
                    uri = android.content.ContentUris.withAppendedId(collection, id),
                )
            }
        }
        return out
    }

    /** Kept for the reclaim flow, where a size match alone is not enough. */
    fun checksum(uri: android.net.Uri): String? = runCatching {
        app.contentResolver.openInputStream(uri)?.use { stream ->
            val md = MessageDigest.getInstance("SHA-256")
            val buffer = ByteArray(64 * 1024)
            while (true) {
                val read = stream.read(buffer)
                if (read <= 0) break
                md.update(buffer, 0, read)
            }
            md.digest().joinToString("") { "%02x".format(it) }
        }
    }.getOrNull()

    fun clearLedger() {
        ledger.edit().clear().apply()
    }

    private data class Row(
        val mediaId: Long,
        val name: String,
        val size: Long,
        val relative: String,
        val uri: android.net.Uri,
    )

    private companion object {
        const val LEDGER = "server_ledger"
    }
}

/** The bridge for the home server. */
internal class ServerHostApiImpl(context: Context) : ServerHostApi {

    private val app: Context = context.applicationContext
    private val worker = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())

    private val credentials = Credentials(app)
    private val engine = TransferEngine(app)
    private val cancelled = AtomicBoolean(false)

    private val settings: SharedPreferences =
        app.getSharedPreferences(SETTINGS, Context.MODE_PRIVATE)

    fun dispose() {
        cancelled.set(true)
        worker.shutdownNow()
    }

    override fun current(callback: (Result<ServerConfig?>) -> Unit) {
        worker.execute { reply(callback, read()) }
    }

    override fun test(
        config: ServerConfig,
        password: String,
        callback: (Result<ServerProbe>) -> Unit,
    ) {
        worker.execute {
            val secret = password.ifEmpty {
                credentials.password(config.id).orEmpty()
            }
            if (secret.isEmpty()) {
                reply(
                    callback,
                    ServerProbe(
                        reachable = false,
                        writable = false,
                        // Names the real cause. This is what a keystore
                        // invalidation looks like from the outside, and without
                        // saying so the user sees an unexplained login failure.
                        detail = if (credentials.wasInvalidated) {
                            "The saved password could not be read after a " +
                                "screen lock change. Please enter it again."
                        } else {
                            "No password saved for this server."
                        },
                        freeBytes = null,
                    ),
                )
                return@execute
            }
            val transport = openTransport(config, secret)
            try {
                reply(callback, transport.probe())
            } finally {
                transport.close()
            }
        }
    }

    override fun save(
        config: ServerConfig,
        password: String,
        callback: (Result<Unit>) -> Unit,
    ) {
        worker.execute {
            if (password.isNotEmpty()) credentials.put(config.id, password)
            credentials.acknowledgeInvalidation()
            write(config)
            reply(callback, Unit)
        }
    }

    override fun forget(callback: (Result<Unit>) -> Unit) {
        worker.execute {
            read()?.let { credentials.clear(it.id) }
            settings.edit().clear().apply()
            // The ledger goes too. It describes what is on a server this app is
            // about to stop knowing about, and keeping it would make a future
            // server appear to already hold four thousand files.
            engine.clearLedger()
            // The job goes with it. A nightly run against a server this app has
            // forgotten would wake the phone to fail, every night, forever.
            BackupWorker.cancel(app)
            reply(callback, Unit)
        }
    }

    override fun setSchedule(enabled: Boolean, callback: (Result<Unit>) -> Unit) {
        worker.execute {
            val config = read()
            if (config == null) {
                reply(callback, Unit)
                return@execute
            }
            // Written first, so the worker reads the same answer the UI shows
            // even if it fires between these two lines.
            write(config.copy(scheduled = enabled))

            if (enabled) {
                BackupWorker.schedule(app, config.wifiOnly, config.whileCharging)
            } else {
                BackupWorker.cancel(app)
            }
            reply(callback, Unit)
        }
    }

    override fun nextRunMillis(callback: (Result<Long?>) -> Unit) {
        worker.execute { reply(callback, BackupWorker.nextRun(app)) }
    }

    override fun startBackup(callback: (Result<Unit>) -> Unit) {
        val config = read()
        if (config == null) {
            main.post { callback(Result.success(Unit)) }
            return
        }
        cancelled.set(false)
        worker.execute {
            engine.run(config, credentials.password(config.id).orEmpty(), cancelled)
        }
        main.post { callback(Result.success(Unit)) }
    }

    override fun cancelBackup(callback: (Result<Unit>) -> Unit) {
        cancelled.set(true)
        main.post { callback(Result.success(Unit)) }
    }

    override fun transferState(callback: (Result<TransferState>) -> Unit) {
        main.post { callback(Result.success(engine.snapshot())) }
    }

    override fun verify(
        fileIds: List<String>,
        callback: (Result<List<String>>) -> Unit,
    ) {
        worker.execute {
            val config = read()
            if (config == null) {
                reply(callback, emptyList())
                return@execute
            }
            reply(
                callback,
                engine.verify(
                    config,
                    credentials.password(config.id).orEmpty(),
                    fileIds,
                ),
            )
        }
    }

    override fun reclaimable(
        limit: Long,
        callback: (Result<List<ReclaimCandidate>>) -> Unit,
    ) {
        worker.execute {
            val config = read()
            if (config == null) {
                reply(callback, emptyList())
                return@execute
            }
            reply(
                callback,
                engine.reclaimable(
                    config,
                    credentials.password(config.id).orEmpty(),
                    limit.toInt(),
                ),
            )
        }
    }

    /**
     * Settings in ordinary preferences, password in the encrypted one.
     *
     * Deliberately split. A keystore invalidation destroys the password file and
     * must not take the host, share and schedule with it: retyping one field is
     * a nuisance, setting the whole thing up again is a reason to give up.
     */
    private fun read(): ServerConfig? {
        val host = settings.getString("host", null) ?: return null
        return ServerConfig(
            id = settings.getString("id", "server") ?: "server",
            protocol = settings.getString("protocol", "smb") ?: "smb",
            label = settings.getString("label", host) ?: host,
            host = host,
            port = settings.getLong("port", 445L),
            share = settings.getString("share", null),
            username = settings.getString("username", "") ?: "",
            remotePath = settings.getString("remotePath", "/GRecovery")
                ?: "/GRecovery",
            encrypt = settings.getBoolean("encrypt", false),
            wifiOnly = settings.getBoolean("wifiOnly", true),
            whileCharging = settings.getBoolean("whileCharging", true),
            scheduled = settings.getBoolean("scheduled", false),
            // Absent rather than defaulted, for all three. A server saved
            // before these existed has no opinion about them, and inventing
            // one here would mean an SMB record claiming a certificate pin.
            secure = if (settings.contains("secure")) {
                settings.getBoolean("secure", true)
            } else {
                null
            },
            basePath = settings.getString("basePath", null),
            certPin = settings.getString("certPin", null),
        )
    }

    private fun write(config: ServerConfig) {
        settings.edit().apply {
            putString("id", config.id)
            putString("protocol", config.protocol)
            putString("label", config.label)
            putString("host", config.host)
            putLong("port", config.port)
            putString("share", config.share)
            putString("username", config.username)
            putString("remotePath", config.remotePath)
            putBoolean("encrypt", config.encrypt)
            putBoolean("wifiOnly", config.wifiOnly)
            putBoolean("whileCharging", config.whileCharging)
            putBoolean("scheduled", config.scheduled)

            // Removed rather than written when null, so `contains` above stays
            // a truthful answer to "did the user ever say". putBoolean has no
            // null to write, which is the whole reason read() asks contains
            // first.
            if (config.secure == null) {
                remove("secure")
            } else {
                putBoolean("secure", config.secure)
            }
            putString("basePath", config.basePath)
            putString("certPin", config.certPin)
        }.apply()
    }

    private fun <T> reply(callback: (Result<T>) -> Unit, value: T) {
        main.post { callback(Result.success(value)) }
    }

    private companion object {
        const val SETTINGS = "server_settings"
    }
}
