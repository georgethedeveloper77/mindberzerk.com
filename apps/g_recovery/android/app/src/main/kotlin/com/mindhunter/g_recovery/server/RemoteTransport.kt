package com.mindhunter.g_recovery.server

import java.io.InputStream

/**
 * WHAT A SERVER HAS TO BE ABLE TO DO.
 *
 * ─── FOUR METHODS, AND THE ABSENCES ARE THE DESIGN ───────────────────────────
 *
 * There is no download, no delete and no rename here, exactly as there was none
 * in SmbTransport. That was a promise made by one class; now it is a promise
 * made by the type, and a second transport cannot quietly break it by adding a
 * method the engine happens to call.
 *
 * A file removed on the server must never affect the phone. Nothing that
 * implements this interface has any way to express that idea.
 *
 * ─── WHY THIS EXISTS BEFORE THE SECOND TRANSPORT, NOT AFTER ──────────────────
 *
 * TransferEngine named SmbTransport in four places. Writing WebDAV first would
 * have meant either a second engine or a `when (protocol)` at each of those
 * four sites, and the second one is how a copy loop ends up subtly different
 * per protocol. Extracting first costs one commit and makes the WebDAV commit
 * touch no shared code at all.
 *
 * ─── PATHS ARE RELATIVE, ALWAYS ──────────────────────────────────────────────
 *
 * Every path here is relative to `config.remotePath`. Joining it to whatever
 * the protocol calls a root is the implementation's job, because SMB wants a
 * share and a UNC path while WebDAV wants a URL and percent encoding, and the
 * engine should know about neither.
 */
internal interface RemoteTransport {

    /**
     * Reachable, and writable, tested separately.
     *
     * Both halves matter. A server that accepts the login and refuses a write
     * is the commonest misconfiguration there is, and every implementation has
     * to actually attempt a write rather than infer it from permissions.
     *
     * Also creates the destination folder when it is missing. A person naming a
     * folder is saying where they want it, not asserting it is already there.
     */
    fun probe(): ServerProbe

    /**
     * Sends one file. Returns false rather than throwing.
     *
     * A run of four thousand files will meet one that fails, and one failure
     * must not end the run. The caller counts them and reports the count, so an
     * implementation that throws here would turn a counted failure into an
     * abandoned backup.
     *
     * [onBytes] receives the running total for this file, not a delta.
     *
     * ─── [sizeBytes] IS A CORRECTION TO THIS INTERFACE, NOT AN EXTRA ─────────
     *
     * The first version of this interface passed only the stream, because that
     * is all SMB needs: jcifs writes until the stream ends and the length is
     * never stated. HTTP is not like that. Without a length OkHttp falls back
     * to chunked encoding, which some WebDAV servers reject outright, and no
     * server can refuse an oversized file up front with 507 because none of
     * them know how large it is until it arrives.
     *
     * The caller has the size already, from the same MediaStore row it used to
     * open the stream. SMB ignores it.
     */
    fun put(
        relativePath: String,
        source: InputStream,
        sizeBytes: Long,
        onBytes: (Long) -> Unit,
    ): Boolean

    /** Size of a file already there, or null when it is not. */
    fun sizeOf(relativePath: String): Long?

    /**
     * Hashes the remote copy without giving anyone a way to download it.
     *
     * The one read in a one way interface, and it does not break the rule: the
     * bytes go through a digest and a hex string comes out, so no caller can
     * obtain the content even by accident.
     *
     * Null when the file is missing or unreadable, which the caller must treat
     * as do not delete the local copy.
     */
    fun sha256Of(relativePath: String): String?

    /**
     * Releases whatever the protocol holds open.
     *
     * A no-op is a valid implementation. It exists because a transport built on
     * a connection pool needs somewhere to let go of it, and adding that later
     * would mean revisiting every call site again.
     */
    fun close()
}

/**
 * Builds the transport for a server.
 *
 * ─── THE ONLY PLACE protocol IS READ ─────────────────────────────────────────
 *
 * One `when`, here. Any other switch on the protocol string anywhere in this
 * package is a bug: it means some behaviour differs per protocol outside the
 * class that owns the protocol.
 */
internal fun openTransport(config: ServerConfig, password: String): RemoteTransport =
    when (config.protocol) {
        "smb" -> SmbTransport(config, password)
        "webdav" -> WebDavTransport(config, password)
        else -> UnsupportedTransport(config.protocol)
    }

/**
 * A server saved by a newer version of the app than the one now running.
 *
 * Unreachable today, since setup only writes "smb". It exists because the
 * alternative is falling back to SMB for an unknown protocol, which would try
 * to open an SMB connection to a WebDAV URL and report a network error for what
 * is actually a downgrade. Saying so is better than guessing wrong.
 *
 * Refuses rather than throws, so a scheduled run against one of these records a
 * clear reason instead of retrying all night.
 */
private class UnsupportedTransport(private val protocol: String) : RemoteTransport {

    override fun probe(): ServerProbe = ServerProbe(
        reachable = false,
        writable = false,
        detail = "This server uses $protocol, which this version of the app " +
            "cannot open. Update the app, or set the server up again.",
        freeBytes = null,
    )

    override fun put(
        relativePath: String,
        source: InputStream,
        sizeBytes: Long,
        onBytes: (Long) -> Unit,
    ): Boolean = false

    override fun sizeOf(relativePath: String): Long? = null

    override fun sha256Of(relativePath: String): String? = null

    override fun close() = Unit
}
