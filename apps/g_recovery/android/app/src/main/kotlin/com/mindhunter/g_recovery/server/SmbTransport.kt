package com.mindhunter.g_recovery.server

import jcifs.CIFSContext
import jcifs.config.PropertyConfiguration
import jcifs.context.BaseContext
import jcifs.smb.NtlmPasswordAuthenticator
import jcifs.smb.SmbFile
import jcifs.smb.SmbFileOutputStream
import java.io.InputStream
import java.util.Properties

/**
 * TALKING TO A NETWORK DRIVE.
 *
 * ─── jcifs-ng, NOT THE ORIGINAL jcifs ────────────────────────────────────────
 *
 * The original speaks SMB1 only, which every current version of Windows ships
 * with disabled and which most NAS firmware now refuses outright. jcifs-ng does
 * SMB2 and SMB3, which is what "network drive" means in 2026.
 *
 * ─── ONE WAY, ALWAYS ─────────────────────────────────────────────────────────
 *
 * There is no delete, no rename and no download here, and their absence is the
 * design rather than an omission. Files go up. A file removed on the server must
 * never affect the phone, and the simplest way to guarantee that is to give this
 * class no way to express it.
 *
 * That promise now lives in [RemoteTransport] rather than in this file, so it
 * survives the arrival of a second protocol.
 */
internal class SmbTransport(
    private val config: ServerConfig,
    password: String,
) : RemoteTransport {

    private val context: CIFSContext = run {
        val props = Properties().apply {
            // SMB1 off. It is unauthenticated in practice, disabled on every
            // modern server, and leaving it on means falling back to it against
            // something pretending to be a NAS.
            setProperty("jcifs.smb.client.minVersion", "SMB202")
            setProperty("jcifs.smb.client.maxVersion", "SMB311")

            // A phone changes networks constantly. A long timeout means a backup
            // that appears to hang for a minute after the user walks out of
            // range, rather than failing and reporting it.
            setProperty("jcifs.smb.client.responseTimeout", "15000")
            setProperty("jcifs.smb.client.soTimeout", "20000")
            setProperty("jcifs.smb.client.connTimeout", "8000")
        }
        BaseContext(PropertyConfiguration(props)).withCredentials(
            NtlmPasswordAuthenticator(null, config.username, password),
        )
    }

    /**
     * Reachable, and writable, tested separately.
     *
     * A share that authenticates and then refuses a write is the commonest
     * misconfiguration there is, and finding out during the first scheduled run
     * at 2am is far too late. This writes a small file and removes it, which is
     * the only honest way to know.
     */
    override fun probe(): ServerProbe {
        val root = runCatching {
            open(config.remotePath, directory = true)
        }.getOrNull()
            ?: return ServerProbe(
                reachable = false,
                writable = false,
                detail = detailFor(null),
                freeBytes = null,
            )

        val reachable = runCatching { root.exists() }.getOrElse { error ->
            return ServerProbe(
                reachable = false,
                writable = false,
                detail = detailFor(error),
                freeBytes = null,
            )
        }

        if (!reachable) {
            // Create the folder rather than refusing. A person typing
            // /GRecovery is telling us where they want it, not asserting it is
            // already there.
            val made = runCatching { root.mkdirs(); true }.getOrDefault(false)
            if (!made) {
                return ServerProbe(
                    reachable = true,
                    writable = false,
                    detail = "Signed in, but the folder could not be created. " +
                        "Check the share allows writing.",
                    freeBytes = null,
                )
            }
        }

        val probeName = ".g_recovery_write_test"
        val writable = runCatching {
            // Two arguments, not three. When the parent is an SmbResource it
            // already carries the CIFSContext, and the (parent, name, context)
            // overload does not exist.
            val file = SmbFile(root, probeName)
            SmbFileOutputStream(file).use { it.write(byteArrayOf(1)) }
            file.delete()
            true
        }.getOrDefault(false)

        return ServerProbe(
            reachable = true,
            writable = writable,
            detail = if (writable) {
                ""
            } else {
                "Signed in, but this share will not accept a file. Check the " +
                    "user has write permission."
            },
            freeBytes = runCatching { root.diskFreeSpace }.getOrNull(),
        )
    }

    /**
     * Sends one file. Returns false rather than throwing.
     *
     * A backup of four thousand files will meet one that fails, and one failure
     * must not end the run. The caller counts them and reports the count.
     */
    override fun put(
        relativePath: String,
        source: InputStream,
        // Unused here, and it stays in the signature anyway. SMB writes until
        // the stream ends and never states a length; HTTP cannot work without
        // one. A transport that does not need a parameter is not a reason for
        // the interface to omit it.
        sizeBytes: Long,
        onBytes: (Long) -> Unit,
    ): Boolean =
        runCatching {
            val target = open("${config.remotePath}/$relativePath")

            // Parent folders first. SMB has no create-with-parents.
            runCatching { target.parent?.let { SmbFile(it, context).mkdirs() } }

            SmbFileOutputStream(target).use { out ->
                val buffer = ByteArray(BUFFER)
                var total = 0L
                while (true) {
                    val read = source.read(buffer)
                    if (read <= 0) break
                    out.write(buffer, 0, read)
                    total += read
                    onBytes(total)
                }
            }
            true
        }.getOrDefault(false)

    /** Size of a file already there, or null when it is not. */
    override fun sizeOf(relativePath: String): Long? = runCatching {
        val file = open("${config.remotePath}/$relativePath")
        if (file.exists()) file.length() else null
    }.getOrNull()

    /**
     * Hashes the remote copy, without giving anything a way to download it.
     *
     * ─── THE ONE READ IN A ONE WAY CLASS ─────────────────────────────────────
     *
     * This class has no download for a reason: nothing on the server should be
     * able to change anything on the phone. This does not break that. It streams
     * the remote bytes through a digest and returns a hex string, so the only
     * thing that crosses is a fingerprint, and no caller can obtain the content
     * even by accident.
     *
     * Null when the file is missing or unreadable, which the caller must treat
     * as "do not delete the local copy".
     */
    override fun sha256Of(relativePath: String): String? = runCatching {
        val file = open("${config.remotePath}/$relativePath")
        if (!file.exists()) return null

        val digest = java.security.MessageDigest.getInstance("SHA-256")
        jcifs.smb.SmbFileInputStream(file).use { stream ->
            val buffer = ByteArray(BUFFER)
            while (true) {
                val read = stream.read(buffer)
                if (read <= 0) break
                digest.update(buffer, 0, read)
            }
        }
        digest.digest().joinToString("") { "%02x".format(it) }
    }.getOrNull()

    /**
     * Deliberately does nothing, for now.
     *
     * jcifs-ng's CIFSContext is closeable and each instance of this class builds
     * its own, so closing it here would release a transport pool that is
     * currently held until garbage collection. That is a real improvement and it
     * is not in this commit.
     *
     * The reason is verification. This commit exists to move SmbTransport behind
     * an interface without altering a single thing it does, so that if SMB
     * misbehaves on the phone afterwards the cause cannot be in here. Closing a
     * connection pool is a change to socket lifetime, and bundling it would make
     * that test mean nothing.
     */
    override fun close() = Unit

    /**
     * A path on the share.
     *
     * ─── THE TRAILING SLASH IS LOAD BEARING ──────────────────────────────────
     *
     * jcifs decides whether a URL names a file or a directory from the slash,
     * not from what is actually on the server. A directory needs one and a file
     * must not have one: address a file with a trailing slash and every write
     * fails, because the library is trying to open a folder.
     */
    private fun open(path: String, directory: Boolean = false): SmbFile {
        val share = config.share.orEmpty()
        val clean = path.trim('/')
        val suffix = if (directory) "/" else ""
        return SmbFile("smb://${config.host}/$share/$clean$suffix", context)
    }

    /**
     * A message someone can act on.
     *
     * Never the raw exception. "Connection refused" tells a person nothing about
     * what to do next; naming the port and suggesting the server may be off
     * tells them exactly where to look.
     */
    private fun detailFor(error: Throwable?): String {
        val text = error?.message.orEmpty().lowercase()
        return when {
            text.contains("logon") || text.contains("credential") ||
                text.contains("access is denied") ->
                "The username or password was not accepted."

            text.contains("unknown host") || text.contains("resolve") ->
                "That address could not be found on this network."

            text.contains("refused") || text.contains("timed out") ||
                text.contains("timeout") ->
                "Nothing answered on port ${config.port}. Check the server is " +
                    "on and sharing is enabled."

            text.contains("share") ->
                "That share name does not exist on the server."

            else -> "Could not reach the server. Check the address and that " +
                "this phone is on the same network."
        }
    }

    private companion object {
        /**
         * 64 KB. Larger buffers stop helping over Wi-Fi well before this, and
         * smaller ones cost a round trip per chunk on a protocol that is already
         * chatty.
         */
        const val BUFFER = 64 * 1024
    }
}
