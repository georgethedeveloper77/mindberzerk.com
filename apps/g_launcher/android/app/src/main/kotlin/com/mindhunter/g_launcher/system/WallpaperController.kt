package com.mindhunter.g_launcher.system

import android.app.WallpaperManager
import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import android.os.Build
import android.util.Log
import java.io.File
import java.io.FileInputStream
import java.io.InputStream
import java.net.HttpURLConnection
import java.net.URL
import java.security.MessageDigest

/**
 * Sets the REAL system wallpaper, rather than the launcher painting its own.
 *
 * Why it matters: if the shell draws its own Image over an opaque window, the
 * wallpaper does not appear in Recents, does not appear behind the app grid,
 * and live wallpapers do not work at all. Users cannot articulate why it feels
 * wrong, but they feel it. Setting the actual system wallpaper — with
 * windowShowWallpaper=true and a transparent window — is what makes the desktop
 * illusion hold together.
 *
 * SET_WALLPAPER is a normal permission: auto-granted, no prompt.
 */
class WallpaperController(context: Context) {

    private companion object {
        const val TAG = "GLauncherWallpaper"
    }

    private val appContext = context.applicationContext
    private val manager = WallpaperManager.getInstance(appContext)

    /**
     * Three schemes, one entry point — so the rotation worker never has to care
     * where a wallpaper came from:
     *
     *   asset:<path>   bundled in the APK
     *   https://…      CDN. Downloaded once, cached, then treated as local.
     *   content:// …   a photo the user picked
     *
     * The CDN case is what lets a new distro ship wallpapers without a Play
     * release — the same property themes and hero icon packs have.
     */
    fun setWallpaper(source: String, applyToLock: Boolean): Boolean {
        val bitmap = decodeSampled(source) ?: return false

        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                manager.setBitmap(bitmap, null, true, WallpaperManager.FLAG_SYSTEM)
                if (applyToLock) {
                    manager.setBitmap(bitmap, null, true, WallpaperManager.FLAG_LOCK)
                }
            } else {
                @Suppress("DEPRECATION")
                manager.setBitmap(bitmap)
            }
            true
        } catch (e: Exception) {
            // A failed wallpaper set must never take the launcher down. Worst
            // case the user keeps the wallpaper they already had.
            Log.w(TAG, "setWallpaper failed for $source", e)
            false
        } finally {
            bitmap.recycle()
        }
    }

    // ---- stash / restore -------------------------------------------------
    //
    // A theme replacing your wallpaper is fine. A theme replacing your wallpaper
    // with no way back is not — the wallpaper is often a photo of someone's kid,
    // and "I tried a theme and lost it" is unforgivable in a way a wrong colour
    // never is.

    /**
     * Copies the current system wallpaper aside, ONCE.
     *
     * Once is the whole contract: called before every theme apply, but it
     * refuses to overwrite an existing stash. Otherwise the second theme switch
     * would stash the FIRST theme's wallpaper as "yours", and the original would
     * be gone for good.
     *
     * Best effort, and honestly so. Reading the wallpaper back has been
     * progressively restricted — Android 13+ limits getWallpaperFile for apps
     * that did not set it, and a device whose wallpaper is a live wallpaper or
     * an OEM default has no file to hand over at all. Any of those return false,
     * the Dart side hides its restore option, and nothing pretends otherwise.
     */
    fun stashWallpaper(): Boolean {
        val stash = stashFile()
        if (stash.exists() && stash.length() > 0) return true

        return try {
            val fd = manager.getWallpaperFile(WallpaperManager.FLAG_SYSTEM)
                ?: return false // live wallpaper, OEM default, or not readable

            fd.use { descriptor ->
                FileInputStream(descriptor.fileDescriptor).use { input ->
                    // Temp-then-rename, same as the CDN cache: a half-written
                    // stash that we later trust is worse than no stash.
                    val tmp = File(stash.parentFile, "${stash.name}.tmp")
                    tmp.outputStream().use { input.copyTo(it) }
                    tmp.renameTo(stash)
                }
            }
            stash.exists() && stash.length() > 0
        } catch (e: Exception) {
            Log.w(TAG, "could not stash the current wallpaper", e)
            false
        }
    }

    fun hasStashedWallpaper(): Boolean =
        stashFile().let { it.exists() && it.length() > 0 }

    /**
     * Puts the stashed wallpaper back on home AND lock, then deletes the stash.
     *
     * Deleting is deliberate: after a restore the user is back where they
     * started, so the next theme apply should stash afresh. Keeping the old copy
     * would pin "restore" to a wallpaper from months ago.
     */
    fun restoreWallpaper(): Boolean {
        val stash = stashFile()
        if (!stash.exists() || stash.length() == 0L) return false

        val ok = setWallpaper(stash.absolutePath.let { "file://$it" }, true)
        if (ok) stash.delete()
        return ok
    }

    /**
     * Lives in filesDir, not cacheDir. The CDN cache is disposable by design and
     * the OS may clear it whenever it likes; the one copy of the user's own
     * wallpaper must not evaporate because storage got tight.
     */
    private fun stashFile(): File =
        File(appContext.filesDir, "wallpaper_stash.img")

    /**
     * Decoding a full-res wallpaper straight into memory is a reliable OOM on a
     * 4GB Tecno — a 4000x3000 JPEG is ~48MB as ARGB_8888. Sample it down to the
     * screen first.
     */
    private fun decodeSampled(source: String): Bitmap? {
        val metrics = appContext.resources.displayMetrics
        // Wallpapers scroll horizontally, so the system wants roughly 2x width.
        val targetW = metrics.widthPixels * 2
        val targetH = metrics.heightPixels

        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        open(source)?.use { BitmapFactory.decodeStream(it, null, bounds) }
        if (bounds.outWidth <= 0) return null

        val opts = BitmapFactory.Options().apply {
            inSampleSize = sampleSize(bounds.outWidth, bounds.outHeight, targetW, targetH)
            inPreferredConfig = Bitmap.Config.ARGB_8888
        }

        return open(source)?.use { BitmapFactory.decodeStream(it, null, opts) }
    }

    private fun sampleSize(w: Int, h: Int, reqW: Int, reqH: Int): Int {
        var sample = 1
        var halfW = w / 2
        var halfH = h / 2
        while (halfW / sample >= reqW && halfH / sample >= reqH) {
            sample *= 2
        }
        return sample
    }

    private fun open(source: String): InputStream? = try {
        when {
            source.startsWith("asset:") -> {
                // Flutter bundles declared assets under flutter_assets/.
                appContext.assets.open("flutter_assets/${source.removePrefix("asset:")}")
            }

            source.startsWith("http://") || source.startsWith("https://") -> {
                cached(source)?.inputStream()
            }

            // The stash is written by us, so it is a plain path rather than a
            // content URI — contentResolver would refuse it.
            source.startsWith("file://") ->
                File(source.removePrefix("file://")).inputStream()

            else -> appContext.contentResolver.openInputStream(Uri.parse(source))
        }
    } catch (e: Exception) {
        Log.w(TAG, "cannot open $source", e)
        null
    }

    /**
     * Downloads a CDN wallpaper once, then serves it from disk forever.
     *
     * Note this is called TWICE per set — once to read the bounds, once to
     * decode — which is exactly why it must hit disk on the second call rather
     * than re-download. It is also why the download must not happen on the main
     * thread: the host API already routes setWallpaper through an IO executor,
     * and WallpaperWorker is a background worker by definition.
     */
    private fun cached(url: String): File? {
        val dir = File(appContext.cacheDir, "wallpapers").apply { mkdirs() }
        val file = File(dir, hash(url))
        if (file.exists() && file.length() > 0) return file

        return try {
            val connection = (URL(url).openConnection() as HttpURLConnection).apply {
                connectTimeout = 15_000
                readTimeout = 30_000
                instanceFollowRedirects = true
            }

            connection.inputStream.use { input ->
                // Temp-then-rename: a half-downloaded wallpaper left in the cache
                // is a permanently corrupt wallpaper, since we would then treat
                // it as already-fetched.
                val tmp = File(dir, "${file.name}.tmp")
                tmp.outputStream().use { input.copyTo(it) }
                tmp.renameTo(file)
            }

            if (file.exists()) file else null
        } catch (e: Exception) {
            // Offline, or the CDN is down. The user keeps the wallpaper they
            // have; the rotation worker moves on to the next source.
            Log.w(TAG, "download failed: $url", e)
            null
        }
    }

    private fun hash(url: String): String {
        val digest = MessageDigest.getInstance("SHA-1").digest(url.toByteArray())
        return digest.joinToString("") { "%02x".format(it) }
    }
}
