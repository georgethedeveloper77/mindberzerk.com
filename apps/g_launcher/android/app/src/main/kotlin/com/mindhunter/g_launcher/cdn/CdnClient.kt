package com.mindhunter.g_launcher.cdn

import java.io.File
import java.io.InputStream
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.atomic.AtomicBoolean

/**
 * PHASE C2 - the only thing in this app that opens a socket.
 *
 * `HttpURLConnection`, not OkHttp or Ktor. Nothing here needs connection
 * pooling, interceptors or a coroutine client: it is a handful of GETs of
 * static objects from a CDN edge. Adding an HTTP stack to a launcher APK to
 * fetch one JSON file a day is the kind of dependency that is invisible on a
 * Pixel and measurable on a Tecno.
 *
 * THREE PROPERTIES THIS CLASS EXISTS TO GUARANTEE, none of which the signature
 * check covers:
 *
 *  1. HTTPS ONLY. The payload is signed, so plaintext could not be tampered
 *     with undetected - but it would still leak which themes a user browses to
 *     anyone on the same cafe wifi, and a launcher that positions itself
 *     alongside a data-guardian app does not get to be sloppy about that.
 *  2. EVERY READ IS CAPPED. A signature is checked AFTER the bytes are on disk,
 *     so a hostile or broken origin can fill the device before verification
 *     ever runs. The cap is enforced while streaming, not from Content-Length,
 *     because Content-Length is attacker-controlled and may simply be a lie.
 *  3. EVERY READ IS CANCELLABLE AND TIMED OUT. This runs on a device whose
 *     network drops in a lift. A download that hangs holding a wake lock is
 *     worse than one that fails.
 *
 * NO `android.*` IMPORTS, same rule as the rest of this pipeline, so the whole
 * thing is testable against a local JDK HttpServer with no emulator.
 */
class CdnClient(
    /** e.g. "https://cdn.mindberzerk.com". No trailing slash required. */
    private val baseUrl: String,
    private val connectTimeoutMs: Int = 15_000,
    private val readTimeoutMs: Int = 30_000,
) {

    companion object {
        private const val CHUNK = 64 * 1024

        /** Tests point this at a local http server; production must be https. */
        var allowInsecureForTests: Boolean = false
    }

    /** Result of a conditional fetch. */
    sealed class Fetch {
        /** Body written; [etag] is null when the origin sent none. */
        data class Body(val bytes: ByteArray, val etag: String?) : Fetch()

        /** 304: what we have is current. The single cheapest possible sync. */
        object NotModified : Fetch()

        data class Failed(val detail: String) : Fetch()
    }

    /**
     * Fetch a small document into memory.
     *
     * [maxBytes] is a hard stop, enforced mid-stream. [etag] sends
     * If-None-Match, which turns the common case - nothing changed since
     * yesterday - into a 304 with no body. That matters for cost as well as
     * speed: R2 bills Class B operations, and a daily sync across a large
     * install base is a lot of them.
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
                    val out = java.io.ByteArrayOutputStream()
                    val copied = copyCapped(conn.inputStream, out, maxBytes.toLong(), cancelled)
                    if (copied < 0) return Fetch.Failed("'$path' exceeded $maxBytes bytes or was cancelled")
                    Fetch.Body(out.toByteArray(), conn.getHeaderField("ETag"))
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
     * [exactBytes] is the size the SIGNED manifest promised, so it is both the
     * cap and the expectation: too many bytes is an attack, too few is a
     * truncated transfer, and either way the file is deleted rather than left
     * as a plausible-looking partial. Nothing is buffered in memory, which is
     * the whole reason this is separate from [fetch].
     */
    fun download(
        path: String,
        target: File,
        exactBytes: Long,
        cancelled: AtomicBoolean = AtomicBoolean(false),
        onProgress: ((Long) -> Unit)? = null,
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
                val copied = copyCapped(conn.inputStream, out, exactBytes, cancelled, onProgress)
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

    // ── internals ────────────────────────────────────────────────────────────

    private fun open(url: URL): HttpURLConnection {
        val conn = url.openConnection() as HttpURLConnection
        conn.requestMethod = "GET"
        conn.connectTimeout = connectTimeoutMs
        conn.readTimeout = readTimeoutMs
        conn.instanceFollowRedirects = true
        conn.useCaches = false
        // A real UA so a future WAF rule or an R2 access log can distinguish
        // launcher traffic from a scraper.
        conn.setRequestProperty("User-Agent", "GLauncher/pack-sync")
        conn.setRequestProperty("Accept-Encoding", "identity")
        return conn
    }

    /**
     * Build the absolute URL, refusing anything that is not plain https on the
     * configured host.
     *
     * `cdn_base_url` comes from Remote Config, so it is a value someone with
     * console access can change without a release. That is the point of it - it
     * is also why it gets validated here rather than trusted. A base of
     * "http://..." or a path containing ".." must not survive this method.
     */
    private fun resolve(path: String): URL? {
        if (path.startsWith("/") || path.contains("..") || path.contains("//")) return null
        val base = baseUrl.trimEnd('/')
        if (!base.startsWith("https://") && !(allowInsecureForTests && base.startsWith("http://"))) {
            return null
        }
        return try {
            val url = URL("$base/$path")
            if (url.protocol != "https" && !(allowInsecureForTests && url.protocol == "http")) null
            else url
        } catch (_: Exception) {
            null
        }
    }

    /**
     * Copy at most [limit] bytes. Returns the count, or -1 when the limit was
     * exceeded or the transfer was cancelled.
     *
     * The read of `limit + 1` is deliberate: stopping exactly at the limit
     * cannot tell "exactly the right size" from "the first N bytes of something
     * much larger", and those need different answers.
     */
    private fun copyCapped(
        input: InputStream,
        output: java.io.OutputStream,
        limit: Long,
        cancelled: AtomicBoolean,
        onProgress: ((Long) -> Unit)? = null,
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
                onProgress?.invoke(total)
            }
        }
        output.flush()
        return total
    }
}
