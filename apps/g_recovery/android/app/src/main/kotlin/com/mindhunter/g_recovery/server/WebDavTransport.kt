package com.mindhunter.g_recovery.server

import android.util.Xml
import okhttp3.HttpUrl
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody
import okhttp3.RequestBody.Companion.toRequestBody
import okio.BufferedSink
import org.xmlpull.v1.XmlPullParser
import java.io.InputStream
import java.io.StringReader
import java.security.KeyStore
import java.security.MessageDigest
import java.security.SecureRandom
import java.security.cert.CertificateException
import java.security.cert.X509Certificate
import java.util.concurrent.TimeUnit
import javax.net.ssl.HttpsURLConnection
import javax.net.ssl.SSLContext
import javax.net.ssl.SSLException
import javax.net.ssl.TrustManager
import javax.net.ssl.TrustManagerFactory
import javax.net.ssl.X509TrustManager

/**
 * TALKING TO A SELF HOSTED DRIVE.
 *
 * ─── THE FIRST TRANSPORT THAT WORKS OUTSIDE THE HOUSE ────────────────────────
 *
 * SMB is a local protocol in practice. Nobody should expose port 445 to the
 * internet and almost nobody does, so a scheduled backup over SMB only runs
 * while the phone is home. That is fine for a nightly run and useless for
 * everything else.
 *
 * WebDAV is HTTP, so it crosses the internet the way everything else does, and
 * it is what Nextcloud, ownCloud and Synology Drive already speak. No new
 * software on the server, and no new dependency here beyond an HTTP client.
 *
 * ─── WHY OkHttp AND NOT HttpURLConnection ────────────────────────────────────
 *
 * HttpURLConnection validates the method name against a fixed list and throws
 * on PROPFIND, which is the one request WebDAV cannot do without. The known
 * workaround is reflection into a private field, and a backup path is the last
 * place to put something that breaks on a platform update.
 *
 * ─── ONE WAY, STILL ──────────────────────────────────────────────────────────
 *
 * [RemoteTransport] has no download and no delete, and this class adds neither.
 * DELETE appears exactly once below, on the probe file this class wrote one
 * line earlier, and GET appears exactly once, feeding a digest that returns a
 * hex string. No caller can reach either with a path of its own.
 */
internal class WebDavTransport(
    private val config: ServerConfig,
    password: String,
) : RemoteTransport {

    /** Null means HTTPS. Only an explicit false sends credentials in the clear. */
    private val secure: Boolean = config.secure ?: true

    private val pin: String? = config.certPin?.takeIf { it.isNotBlank() }

    /**
     * NOT `import okhttp3.Credentials`.
     *
     * This package already has a class called Credentials, the one holding the
     * password in the keystore. Importing OkHttp's would shadow it inside this
     * file, and the collision would surface as an error somewhere unrelated.
     */
    private val authorization: String =
        okhttp3.Credentials.basic(config.username, password)

    private val client: OkHttpClient = buildClient(pin)

    // ─────────────────────────────────────────────────────────────────────────
    // Probe
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * Four questions, in the order that makes a failure mean something.
     *
     * Is this WebDAV at all, will it take this password, will it accept a file,
     * and how much room is left. Asking them separately is why the screen can
     * say "sign in failed" rather than "backup failed", and why the certificate
     * case can offer a button instead of a shrug.
     */
    override fun probe(): ServerProbe {
        var serverName: String? = null

        // 1. Is there a WebDAV server here, and will it have us.
        val options = runCatching {
            client.newCall(
                headers(absolute(directory = true)).method("OPTIONS", null).build(),
            ).execute()
        }.getOrElse { error ->
            return failure(error)
        }

        options.use {
            serverName = it.header("Server")

            if (it.code == 401 || it.code == 403) {
                return ServerProbe(
                    reachable = true,
                    writable = false,
                    detail = "The server did not accept that user name and " +
                        "password. If two-step sign in is turned on, only an " +
                        "app password will work.",
                    freeBytes = null,
                    code = CODE_AUTH,
                    certFingerprint = null,
                    serverName = serverName,
                )
            }

            // The DAV header is the protocol's own answer to "are you WebDAV".
            // A web server with no DAV module returns a perfectly good 200 and
            // then refuses every PROPFIND, which without this check reads as a
            // broken app rather than a wrong address.
            if (it.header("DAV") == null) {
                return ServerProbe(
                    reachable = true,
                    writable = false,
                    detail = "Something answered, but it does not speak " +
                        "WebDAV. The part of the address after the host name " +
                        "is usually wrong.",
                    freeBytes = null,
                    code = CODE_NOT_DAV,
                    certFingerprint = null,
                    serverName = serverName,
                )
            }
        }

        // 2. The destination folder. Created rather than demanded: a person
        //    naming a folder is saying where they want it.
        if (!makeDirectories(config.remotePath)) {
            return ServerProbe(
                reachable = true,
                writable = false,
                detail = "Signed in, but the folder could not be created. " +
                    "Check the account is allowed to write here.",
                freeBytes = null,
                code = CODE_PATH,
                certFingerprint = null,
                serverName = serverName,
            )
        }

        // 3. An actual write. An account that looks right and a folder that
        //    refuses a file is the commonest misconfiguration there is, and
        //    finding out during the first scheduled run is far too late.
        val probeName = ".g_recovery_write_test"
        val wrote = runCatching {
            client.newCall(
                headers(under(probeName))
                    .put(byteArrayOf(1).toRequestBody(OCTET))
                    .build(),
            ).execute().use { it.isSuccessful }
        }.getOrDefault(false)

        if (wrote) {
            // The only DELETE in this class, on the file it wrote four lines
            // above. Nothing reaches it with a path of its own.
            runCatching {
                client.newCall(headers(under(probeName)).delete().build())
                    .execute().close()
            }
        }

        return ServerProbe(
            reachable = true,
            writable = wrote,
            detail = if (wrote) {
                ""
            } else {
                "Signed in, but the server would not accept a file. Check the " +
                    "account has permission to write to this folder."
            },
            freeBytes = quota(),
            code = if (wrote) CODE_OK else CODE_PATH,
            certFingerprint = null,
            serverName = serverName,
        )
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Transfer
    // ─────────────────────────────────────────────────────────────────────────

    override fun put(
        relativePath: String,
        source: InputStream,
        sizeBytes: Long,
        onBytes: (Long) -> Unit,
    ): Boolean = runCatching {
        // Parent collections first. MKCOL makes one level at a time and returns
        // 409 when the parent is missing, so the walk is ours to do.
        relativePath.substringBeforeLast('/', "").takeIf { it.isNotEmpty() }
            ?.let { makeDirectories("${config.remotePath}/$it") }

        client.newCall(
            headers(under(relativePath))
                .put(StreamBody(source, sizeBytes, onBytes))
                .build(),
        ).execute().use {
            // 507 is the server saying it is full, and it is counted as a
            // failure like any other. Interpreting it here would duplicate what
            // the next probe reports as free space.
            it.isSuccessful
        }
    }.getOrDefault(false)

    override fun sizeOf(relativePath: String): Long? = runCatching {
        client.newCall(
            headers(under(relativePath))
                .header("Depth", "0")
                .method("PROPFIND", PROP_SIZE.toRequestBody(XML))
                .build(),
        ).execute().use {
            if (!it.isSuccessful) {
                null
            } else {
                firstValue(it.body?.string().orEmpty(), "getcontentlength")
                    ?.toLongOrNull()
            }
        }
    }.getOrNull()

    /**
     * Hashes the remote copy, without giving anything a way to download it.
     *
     * ─── THE ONE READ, AND IT LEAKS NOTHING ──────────────────────────────────
     *
     * This is a GET, so the bytes do cross the network, but they go straight
     * into a digest and what comes back is sixty-four hex characters. There is
     * no overload that returns content, and no caller could obtain it by
     * accident.
     *
     * ─── AND IT COSTS SOMETHING HERE THAT IT DID NOT OVER SMB ────────────────
     *
     * On a LAN this read is nearly free. Against a server across the internet
     * it is a full download of every file being reclaimed, which is the same
     * volume as the space about to be freed. The transport still does it,
     * because the alternative is deleting an original on a promise, but the
     * screen has to say so before the user taps.
     */
    override fun sha256Of(relativePath: String): String? = runCatching {
        client.newCall(headers(under(relativePath)).get().build())
            .execute().use { response ->
                if (!response.isSuccessful) return null
                val stream = response.body?.byteStream() ?: return null

                val digest = MessageDigest.getInstance("SHA-256")
                val buffer = ByteArray(BUFFER)
                while (true) {
                    val read = stream.read(buffer)
                    if (read <= 0) break
                    digest.update(buffer, 0, read)
                }
                digest.digest().joinToString("") { "%02x".format(it) }
            }
    }.getOrNull()

    override fun close() {
        // Both halves. Evicting the pool closes the sockets; shutting the
        // dispatcher down releases the threads that held them. Leaving either
        // behind is a leak that only shows after a few hundred scheduled runs,
        // which is exactly when nobody is watching.
        runCatching { client.connectionPool.evictAll() }
        runCatching { client.dispatcher.executorService.shutdown() }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Plumbing
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * Headers only, never a method.
     *
     * The method has to be set by the caller together with its body, because
     * OkHttp rejects `method("PUT", null)` at once: PUT is on its list of verbs
     * that require one. A helper that guessed a method here would throw before
     * the body could be attached.
     */
    private fun headers(url: HttpUrl): Request.Builder =
        Request.Builder()
            .url(url)
            // Sent up front rather than waiting for a challenge.
            //
            // OkHttp's Authenticator only reacts to a 401, which costs a round
            // trip on every one of four thousand uploads. Worse, some servers
            // answer an unauthenticated request with a redirect to a login page
            // instead of a 401, and then the challenge never arrives at all.
            .header("Authorization", authorization)
            .header("User-Agent", USER_AGENT)

    /** A path under the user's chosen folder. */
    private fun under(relativePath: String): HttpUrl =
        absolute(
            listOf(config.remotePath, relativePath)
                .joinToString("/") { it.trim('/') },
        )

    /**
     * A path under the DAV root.
     *
     * ─── SEGMENT BY SEGMENT, NEVER STRING CONCATENATION ──────────────────────
     *
     * addPathSegments percent-encodes each piece. Building this by hand would
     * work until the first photo with a space, a hash or a plus in its name,
     * and a file called "1 + 1.jpg" would land on the server under a different
     * name or fail outright.
     */
    private fun absolute(path: String = "", directory: Boolean = false): HttpUrl {
        val builder = HttpUrl.Builder()
            .scheme(if (secure) "https" else "http")
            .host(config.host.trim())

        val port = config.port.toInt()
        if (port in 1..65535) builder.port(port)

        config.basePath?.trim('/')?.takeIf { it.isNotEmpty() }
            ?.let { builder.addPathSegments(it) }

        path.trim('/').takeIf { it.isNotEmpty() }
            ?.let { builder.addPathSegments(it) }

        // WebDAV tells a collection from a file by the trailing slash, and an
        // empty final segment is how HttpUrl expresses one. MKCOL and PROPFIND
        // against a collection without it get a redirect from a lenient server
        // and a 404 from a strict one.
        if (directory) builder.addPathSegment("")

        return builder.build()
    }

    /**
     * MKCOL, one level at a time, treating "already there" as success.
     *
     * WebDAV has no create-with-parents. 405 means the collection exists, which
     * is all anyone here wanted; 409 means the parent does not, which the walk
     * has already dealt with by the time it could matter.
     */
    private fun makeDirectories(path: String): Boolean {
        val segments = path.trim('/').split('/').filter { it.isNotEmpty() }
        if (segments.isEmpty()) return true

        var walked = ""
        for (segment in segments) {
            walked = if (walked.isEmpty()) segment else "$walked/$segment"
            val made = runCatching {
                client.newCall(
                    headers(absolute(walked, directory = true))
                        .method("MKCOL", null)
                        .build(),
                ).execute().use { it.isSuccessful || it.code == 405 }
            }.getOrDefault(false)
            if (!made) return false
        }
        return true
    }

    /** Free space, when the server reports a quota. Absent rather than zero. */
    private fun quota(): Long? = runCatching {
        client.newCall(
            headers(absolute(config.remotePath, directory = true))
                .header("Depth", "0")
                .method("PROPFIND", PROP_QUOTA.toRequestBody(XML))
                .build(),
        ).execute().use {
            if (!it.isSuccessful) {
                null
            } else {
                firstValue(it.body?.string().orEmpty(), "quota-available-bytes")
                    ?.toLongOrNull()
                    // A server with no quota configured reports a negative
                    // sentinel rather than omitting the property, and
                    // "-3 bytes free" is worse than saying nothing.
                    ?.takeIf { bytes -> bytes >= 0 }
            }
        }
    }.getOrNull()

    /**
     * Turns a thrown request into something a person can act on.
     *
     * The certificate branch is the one that matters. It is the only failure
     * here the user can resolve themselves, so rather than reporting it and
     * stopping, this reconnects purely to read the certificate's fingerprint
     * and hands it back for them to check.
     */
    private fun failure(error: Throwable): ServerProbe {
        val text = (error.message ?: error.toString()).lowercase()
        val tls = error is SSLException ||
            error is CertificateException ||
            text.contains("certificate") ||
            text.contains("trust anchor") ||
            text.contains("hostname")

        if (tls) {
            val fingerprint = inspectCertificate()
            return ServerProbe(
                reachable = true,
                writable = false,
                detail = if (fingerprint == null) {
                    "The secure connection was refused and the server's " +
                        "certificate could not be read."
                } else {
                    "This server presented its own certificate rather than " +
                        "one signed by a public authority. For a server you " +
                        "run yourself that is normal. Check the fingerprint " +
                        "against your server before you continue."
                },
                freeBytes = null,
                code = if (fingerprint == null) CODE_NETWORK else CODE_CERT,
                certFingerprint = fingerprint,
                serverName = null,
            )
        }

        return ServerProbe(
            reachable = false,
            writable = false,
            detail = when {
                text.contains("unable to resolve") || text.contains("unknown host") ->
                    "That address could not be found. Check the host name."

                text.contains("refused") ->
                    "Nothing answered on port ${config.port}. Check the " +
                        "server is running."

                text.contains("timeout") || text.contains("timed out") ->
                    "The server did not answer in time. Check it is reachable " +
                        "from this network."

                else -> "Could not reach the server. Check the address and " +
                    "that this phone has a connection."
            },
            freeBytes = null,
            code = CODE_NETWORK,
            certFingerprint = null,
            serverName = null,
        )
    }

    /**
     * Reads the certificate the server offered, and does nothing else with it.
     *
     * ─── A DELIBERATELY UNSAFE CLIENT, FOR ONE ANONYMOUS REQUEST ─────────────
     *
     * This client accepts any certificate, which is precisely what the rest of
     * this class refuses to do. It is confined to this method, it carries no
     * Authorization header so no password crosses it, and it throws the
     * response away. The only thing that escapes is a fingerprint for the user
     * to compare, and nothing is trusted until they say so.
     */
    private fun inspectCertificate(): String? = runCatching {
        val capture = CapturingTrust()
        val context = SSLContext.getInstance("TLS").apply {
            init(null, arrayOf<TrustManager>(capture), SecureRandom())
        }
        val inspector = OkHttpClient.Builder()
            .connectTimeout(10, TimeUnit.SECONDS)
            .readTimeout(10, TimeUnit.SECONDS)
            .sslSocketFactory(context.socketFactory, capture)
            .hostnameVerifier { _, _ -> true }
            .build()

        runCatching {
            inspector.newCall(
                Request.Builder()
                    .url(absolute(directory = true))
                    .method("OPTIONS", null)
                    .build(),
            ).execute().close()
        }

        inspector.connectionPool.evictAll()
        inspector.dispatcher.executorService.shutdown()

        capture.leaf?.let { fingerprintOf(it) }
    }.getOrNull()

    private fun buildClient(pinned: String?): OkHttpClient {
        val builder = OkHttpClient.Builder()
            .connectTimeout(15, TimeUnit.SECONDS)
            .readTimeout(30, TimeUnit.SECONDS)
            // Per write, not per upload. A two gigabyte video over a slow link
            // is a long call made of short writes, and a whole-call timeout
            // would kill it for being large rather than for being stuck.
            .writeTimeout(60, TimeUnit.SECONDS)
            .retryOnConnectionFailure(true)

        if (pinned != null) {
            val system = systemTrust()
            val trust = PinnedTrust(pinned, system)
            val context = SSLContext.getInstance("TLS").apply {
                init(null, arrayOf<TrustManager>(trust), SecureRandom())
            }
            builder.sslSocketFactory(context.socketFactory, trust)

            // Relaxed for the pinned certificate, and only for it.
            //
            // A self-signed certificate on a home server is usually issued to a
            // name that does not match how the phone reaches it. Once that
            // exact certificate has been checked by fingerprint, the host name
            // adds nothing: it is a weaker identity test than the one that has
            // already passed. Every other certificate still faces the normal
            // check, so this is not a hole anything else can climb through.
            val default = HttpsURLConnection.getDefaultHostnameVerifier()
            builder.hostnameVerifier { hostname, session ->
                default.verify(hostname, session) || runCatching {
                    val leaf = session.peerCertificates.firstOrNull()
                    leaf is X509Certificate &&
                        fingerprintOf(leaf).equals(pinned, ignoreCase = true)
                }.getOrDefault(false)
            }
        }

        return builder.build()
    }

    /**
     * A body that streams a file up while reporting progress.
     *
     * ─── isOneShot IS THE LOAD BEARING LINE ──────────────────────────────────
     *
     * OkHttp replays a request body on a retry, and an InputStream that has
     * already been read returns nothing the second time. Without this the
     * failure is not an error: it is a zero byte file on the server, the ledger
     * recording a successful upload, and reclaim later offering to delete the
     * original because both sides agree it is there.
     *
     * Declaring the body unrepeatable makes OkHttp fail the call instead, which
     * the caller counts and retries tomorrow.
     */
    private class StreamBody(
        private val source: InputStream,
        private val length: Long,
        private val onBytes: (Long) -> Unit,
    ) : RequestBody() {

        override fun contentType() = OCTET

        /**
         * The real length, so the request carries Content-Length.
         *
         * Returning -1 would make OkHttp use chunked encoding, which some
         * WebDAV servers reject outright and which stops any server from
         * refusing an oversized file up front with 507.
         */
        override fun contentLength(): Long = length

        override fun isOneShot(): Boolean = true

        override fun writeTo(sink: BufferedSink) {
            val buffer = ByteArray(BUFFER)
            var total = 0L
            while (true) {
                val read = source.read(buffer)
                if (read <= 0) break
                sink.write(buffer, 0, read)
                total += read
                onBytes(total)
            }
        }
    }

    /** Accepts the one certificate the user pinned, and otherwise defers. */
    private class PinnedTrust(
        private val pinned: String,
        private val system: X509TrustManager,
    ) : X509TrustManager {

        override fun checkClientTrusted(
            chain: Array<out X509Certificate>?,
            authType: String?,
        ) = system.checkClientTrusted(chain, authType)

        override fun checkServerTrusted(
            chain: Array<out X509Certificate>?,
            authType: String?,
        ) {
            val leaf = chain?.firstOrNull()
                ?: throw CertificateException("The server offered no certificate.")

            if (fingerprintOf(leaf).equals(pinned, ignoreCase = true)) return

            // Not the pinned one, so it faces the ordinary check. This is what
            // keeps working the day the user puts a real certificate on their
            // server: the pin stops matching, normal validation passes, and
            // nobody has to go and clear a setting to make it work again.
            system.checkServerTrusted(chain, authType)
        }

        override fun getAcceptedIssuers(): Array<X509Certificate> =
            system.acceptedIssuers
    }

    /** Records what was offered and judges nothing. Inspection only. */
    private class CapturingTrust : X509TrustManager {
        var leaf: X509Certificate? = null

        override fun checkClientTrusted(
            chain: Array<out X509Certificate>?,
            authType: String?,
        ) = Unit

        override fun checkServerTrusted(
            chain: Array<out X509Certificate>?,
            authType: String?,
        ) {
            leaf = chain?.firstOrNull()
        }

        override fun getAcceptedIssuers(): Array<X509Certificate> = emptyArray()
    }

    private companion object {
        const val BUFFER = 64 * 1024
        const val USER_AGENT = "GRecovery"

        const val CODE_OK = "ok"
        const val CODE_AUTH = "auth"
        const val CODE_CERT = "cert"
        const val CODE_NOT_DAV = "not_dav"
        const val CODE_PATH = "path"
        const val CODE_NETWORK = "network"

        val XML = "application/xml; charset=utf-8".toMediaType()
        val OCTET = "application/octet-stream".toMediaType()

        const val PROP_SIZE =
            """<?xml version="1.0" encoding="utf-8"?>""" +
                """<d:propfind xmlns:d="DAV:"><d:prop>""" +
                """<d:getcontentlength/></d:prop></d:propfind>"""

        const val PROP_QUOTA =
            """<?xml version="1.0" encoding="utf-8"?>""" +
                """<d:propfind xmlns:d="DAV:"><d:prop>""" +
                """<d:quota-available-bytes/></d:prop></d:propfind>"""

        /**
         * SHA-256 over the certificate's DER bytes, in hex.
         *
         * The same number `openssl x509 -fingerprint -sha256` prints, and that
         * is the whole point: a fingerprint the user cannot reproduce on their
         * own server is a fingerprint nobody will check.
         */
        fun fingerprintOf(certificate: X509Certificate): String =
            MessageDigest.getInstance("SHA-256")
                .digest(certificate.encoded)
                .joinToString("") { "%02x".format(it) }

        fun systemTrust(): X509TrustManager {
            val factory = TrustManagerFactory.getInstance(
                TrustManagerFactory.getDefaultAlgorithm(),
            )
            factory.init(null as KeyStore?)
            return factory.trustManagers.filterIsInstance<X509TrustManager>().first()
        }

        /**
         * The text of the first element with this local name.
         *
         * A pull parser rather than a regular expression, because the namespace
         * prefix is the server's own choice: Nextcloud writes d:, Apache writes
         * D:, and some write none at all. Matching the local name with
         * namespace processing on is the only approach that holds for all of
         * them.
         */
        fun firstValue(xml: String, localName: String): String? = runCatching {
            val parser = Xml.newPullParser().apply {
                setFeature(XmlPullParser.FEATURE_PROCESS_NAMESPACES, true)
                setInput(StringReader(xml))
            }

            var found: String? = null
            var inside = false
            var event = parser.eventType

            while (event != XmlPullParser.END_DOCUMENT && found == null) {
                when (event) {
                    XmlPullParser.START_TAG ->
                        inside = parser.name.equals(localName, ignoreCase = true)

                    XmlPullParser.TEXT ->
                        if (inside) {
                            found = parser.text?.trim()?.takeIf { it.isNotEmpty() }
                        }

                    XmlPullParser.END_TAG -> inside = false
                }
                if (found == null) event = parser.next()
            }
            found
        }.getOrNull()
    }
}
