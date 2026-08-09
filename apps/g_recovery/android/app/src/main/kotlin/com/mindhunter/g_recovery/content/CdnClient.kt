package com.mindhunter.g_recovery.content

import java.io.ByteArrayOutputStream
import java.io.File
import java.io.InputStream
import java.io.OutputStream
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.atomic.AtomicBoolean

/**
 * PORT OF `g_launcher/cdn/CdnClient.kt`. The only thing in this app that opens
 * a socket.
 *
 * `HttpURLConnection`, not OkHttp or Ktor. Nothing here needs connection
 * pooling or interceptors: it is a handful of GETs of static objects from a CDN
 * edge. Adding an HTTP stack to fetch one JSON file a day is the kind of
 * dependency that is invisible on a Pixel and measurable on a Tecno.
 *
 * THREE PROPERTIES THE SIGNATURE CHECK DOES NOT COVER:
 *
 *  1. HTTPS ONLY. The payload is signed, so plaintext could not be tampered
 *     with undetected, but it would still leak what a user is doing to anyone
 *     on the same cafe wifi. An app that sells itself on data control does not
 *     get to be sloppy about that.
 *  2. EVERY READ IS CAPPED, mid stream, not from Content-Length. The signature
 *     is checked AFTER bytes are on disk, so a hostile or broken origin can
 *     fill the device before verification runs, and Content-Length is a value
 *     the origin chooses.
 *  3. EVERY READ IS CANCELLABLE AND TIMED OUT. A download that hangs holding a
 *     wake lock is worse than one that fails.
 */
internal class CdnClient(
    private val baseUrl: String,
    private val connectTimeoutMs: Int = 15_000,
    private val readTimeoutMs: Int = 30_000,
) {

    companion object {
        private const val CHUNK = 64 * 1024
        var allowInsecureForTests: Boolean = false
    }

    sealed class Fetch {
        data class Body(val bytes: ByteArray, val etag: String?) : Fetch()

        /** 304. What we have is current, and the cheapest possible sync. */
        object NotModified : Fetch()

        data class Failed(val detail: String) : Fetch()
    }

    /**
     * Fetch a small document into memory.
     *
     * [etag] sends If-None-Match, which turns the common case, nothing changed
     * since yesterday, into a 304 with no body. That matters for cost as well
     * as speed: R2 bills Class B operations and a daily sync across an install
     * base is a lot of them.
     */
    fun fetch(
        path: String,
        maxBytes: Int,
        etag: String? = null,
        cancelled: AtomicBoolean = AtomicBoolean(false),
    ): Fetch {
        val url = resolve(path) ?: return Fetch.Failed("bad url for '$path'")
        var conn: HttpURLConnection? = null
        return try {
            conn = open(url)
            if (etag != null) conn.setRequestProperty("If-None-Match", etag)
            conn.connect()

            when (val code = conn.responseCode) {
                HttpURLConnection.HTTP_NOT_MODIFIED -> Fetch.NotModified
                HttpURLConnection.HTTP_OK -> {
                    val out = ByteArrayOutputStream()
                    val copied = copyCapped(conn.inputStream, out, maxBytes.toLong(), cancelled)
                    if (copied < 0) {
                        Fetch.Failed("'$path' exceeded $maxBytes bytes or was cancelled")
                    } else {
                        Fetch.Body(out.toByteArray(), conn.getHeaderField("ETag"))
                    }
                }
                else -> Fetch.Failed("HTTP $code for '$path'")
            }
        } catch (e: Exception) {
            Fetch.Failed("${e.javaClass.simpleName} for '$path': ${e.message}")
        } finally {
            conn?.disconnect()
        }
    }

    /**
     * Stream a payload file straight to disk.
     *
     * [exactBytes] is the size the SIGNED manifest promised, so it is both cap
     * and expectation: too many bytes is an attack, too few is a truncated
     * transfer, and either way the file is deleted rather than left as a
     * plausible looking partial.
     */
    fun download(
        path: String,
        target: File,
        exactBytes: Long,
        cancelled: AtomicBoolean = AtomicBoolean(false),
    ): String? {
        val url = resolve(path) ?: return "bad url for '$path'"
        target.parentFile?.mkdirs()

        var conn: HttpURLConnection? = null
        try {
            conn = open(url)
            conn.connect()
            if (conn.responseCode != HttpURLConnection.HTTP_OK) {
                return "HTTP ${conn.responseCode} for '$path'"
            }
            target.outputStream().use { out ->
                val copied = copyCapped(conn.inputStream, out, exactBytes, cancelled)
                if (copied < 0) {
                    target.delete()
                    return "'$path' overran its signed size or was cancelled"
                }
                if (copied != exactBytes) {
                    target.delete()
                    return "'$path' was $copied bytes, signed manifest says $exactBytes"
                }
            }
            return null
        } catch (e: Exception) {
            target.delete()
            return "${e.javaClass.simpleName} for '$path': ${e.message}"
        } finally {
            conn?.disconnect()
        }
    }

    private fun open(url: URL): HttpURLConnection {
        val conn = url.openConnection() as HttpURLConnection
        conn.requestMethod = "GET"
        conn.connectTimeout = connectTimeoutMs
        conn.readTimeout = readTimeoutMs
        conn.instanceFollowRedirects = true
        conn.useCaches = false
        // A real UA so an R2 access log can distinguish this app's traffic from
        // the launcher's and from a scraper.
        conn.setRequestProperty("User-Agent", "GRecovery/content-sync")
        conn.setRequestProperty("Accept-Encoding", "identity")
        return conn
    }

    /**
     * Build the absolute URL, refusing anything that is not plain https.
     *
     * The base is pushed in from Dart, so it is a value someone could change
     * without a release. That is the point of it, and also why it is validated
     * here rather than trusted.
     */
    private fun resolve(path: String): URL? {
        if (path.startsWith("/") || path.contains("..") || path.contains("//")) return null
        val base = baseUrl.trimEnd('/')
        if (!base.startsWith("https://") && !(allowInsecureForTests && base.startsWith("http://"))) {
            return null
        }
        return try {
            val url = URL("$base/$path")
            if (url.protocol != "https" && !(allowInsecureForTests && url.protocol == "http")) {
                null
            } else {
                url
            }
        } catch (_: Exception) {
            null
        }
    }

    /**
     * Copy at most [limit] bytes. Returns the count, or -1 when the limit was
     * exceeded or the transfer cancelled.
     *
     * Reading past the limit is deliberate: stopping exactly at it cannot tell
     * "exactly the right size" from "the first N bytes of something much
     * larger", and those need different answers.
     */
    private fun copyCapped(
        input: InputStream,
        output: OutputStream,
        limit: Long,
        cancelled: AtomicBoolean,
    ): Long {
        val buf = ByteArray(CHUNK)
        var total = 0L
        input.use { stream ->
            while (true) {
                if (cancelled.get()) return -1
                val n = stream.read(buf)
                if (n <= 0) break
                total += n
                if (total > limit) return -1
                output.write(buf, 0, n)
            }
        }
        output.flush()
        return total
    }
}
