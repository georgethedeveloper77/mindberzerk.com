package com.mindhunter.g_recovery.content

import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

/**
 * The content bridge.
 *
 * Same threading contract as the other two: one worker, every Pigeon callback
 * posted back to the main looper. A sync opens sockets and hashes files, so it
 * has no business anywhere near the platform thread.
 */
internal class ContentHostApiImpl(context: Context) : ContentHostApi {

    private val app: Context = context.applicationContext
    private val worker: ExecutorService = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())

    private val verifier = ContentVerifier(ContentKeys.accepted, appVersionCode())
    private val sync = ContentSync(app, verifier)

    /** Empty until Dart pushes one. A sync before that returns offline. */
    @Volatile
    private var baseUrl: String = ""

    fun dispose() {
        sync.cancel()
        worker.shutdownNow()
    }

    override fun setBaseUrl(url: String, callback: (Result<Unit>) -> Unit) {
        baseUrl = url
        reply(callback, Unit)
    }

    override fun sync(callback: (Result<ContentSyncResult>) -> Unit) {
        val url = baseUrl
        worker.execute {
            if (url.isEmpty()) {
                reply(
                    callback,
                    ContentSyncResult(
                        status = "offline",
                        detail = "no content host configured",
                        changed = false,
                        packs = sync.installedPacks(),
                    ),
                )
            } else {
                reply(callback, sync.sync(url))
            }
        }
    }

    override fun readContent(packId: String, callback: (Result<String?>) -> Unit) {
        worker.execute { reply(callback, sync.read(packId)) }
    }

    override fun packs(callback: (Result<List<ContentPackInfo>>) -> Unit) {
        worker.execute { reply(callback, sync.installedPacks()) }
    }

    /**
     * This build's versionCode, checked against every pack's minAppVersion.
     *
     * Read from PackageManager rather than a constant, because a constant
     * copied out of the gradle file drifts the first time someone bumps one and
     * the symptom is packs being accepted on a build too old to render them.
     */
    private fun appVersionCode(): Int = try {
        val info = app.packageManager.getPackageInfo(app.packageName, 0)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            info.longVersionCode.toInt()
        } else {
            @Suppress("DEPRECATION")
            info.versionCode
        }
    } catch (_: PackageManager.NameNotFoundException) {
        0
    }

    private fun <T> reply(callback: (Result<T>) -> Unit, value: T) {
        main.post { callback(Result.success(value)) }
    }
}
