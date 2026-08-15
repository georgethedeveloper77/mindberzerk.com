package com.mindhunter.g_recovery.apps

import android.app.AppOpsManager
import android.app.usage.StorageStatsManager
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.os.Process
import android.os.storage.StorageManager
import android.provider.Settings
import java.util.concurrent.Executors

/**
 * WHAT EACH APP OCCUPIES.
 *
 * ─── IT CANNOT CLEAR ANYTHING, AND THAT IS NOT AN OVERSIGHT ──────────────────
 *
 * clearApplicationUserData is system only and has been since Android 6. There
 * is no method here that clears a cache because no such method can exist for a
 * third party app. What exists is a route to the settings screen where the
 * button is real.
 *
 * ─── TWO PERMISSIONS, ONLY ONE OF THEM LOAD BEARING ──────────────────────────
 *
 * PACKAGE_USAGE_STATS is required: StorageStatsManager refuses to answer
 * without it, and it is also how the package list is built. It is granted on a
 * settings screen, not through a runtime dialog.
 *
 * QUERY_ALL_PACKAGES only widens the list. Without it this sees the apps the
 * user has actually used, which is the set worth looking at anyway, so the
 * feature degrades rather than breaks if Play refuses the declaration.
 */
internal class AppsReader(context: Context) {

    private val app: Context = context.applicationContext
    private val packages: PackageManager = app.packageManager

    /**
     * How many packages have been sized, and how many there are.
     *
     * ─── READ FROM ANOTHER THREAD WHILE THE LOOP RUNS ────────────────────────
     *
     * The whole point of these two is to be legible from outside the worker
     * thread mid read, so they are volatile and they are plain counters. They
     * are the only honest source for a progress figure: the screen reports what
     * has actually been sized rather than a guess at how long it will take.
     *
     * [total] is zero until the package list exists, which is the first second
     * or so. A caller seeing zero has been told the truth, that the count is
     * not known yet, and should say so rather than invent one.
     */
    @Volatile
    var done: Int = 0
        private set

    @Volatile
    var total: Int = 0
        private set

    /**
     * Whether Usage Access has been granted.
     *
     * Read from AppOpsManager rather than a held flag, because the user can
     * revoke it from a settings screen this app never sees, so any cached
     * answer is a guess.
     */
    fun hasUsageAccess(): Boolean = runCatching {
        val ops = app.getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = ops.unsafeCheckOpNoThrow(
            AppOpsManager.OPSTR_GET_USAGE_STATS,
            Process.myUid(),
            app.packageName,
        )
        mode == AppOpsManager.MODE_ALLOWED
    }.getOrDefault(false)

    fun openUsageAccess(): Boolean = runCatching {
        app.startActivity(
            Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
        )
        true
    }.getOrDefault(false)

    /**
     * The one screen where Clear cache works.
     *
     * ACTION_APPLICATION_DETAILS_SETTINGS rather than the internal storage
     * screen, because the deeper one is not a public action and OEMs move it.
     * This lands one tap away from the button on every device.
     */
    fun openAppSettings(packageName: String): Boolean = runCatching {
        app.startActivity(
            Intent(
                Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                Uri.fromParts("package", packageName, null),
            ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
        )
        true
    }.getOrDefault(false)

    fun read(): List<AppEntry> {
        done = 0
        total = 0

        if (!hasUsageAccess()) return emptyList()

        val stats = app.getSystemService(StorageStatsManager::class.java)
            ?: return emptyList()
        val storage = app.getSystemService(StorageManager::class.java)
            ?: return emptyList()
        val user = Process.myUserHandle()

        // Queried ONCE and handed down.
        //
        // queryUsageStats over a year is one of the two expensive calls in this
        // path, and it used to run twice: once here for the timestamps, and
        // again inside installed() for the package names. Same call, same
        // answer, twice the wait.
        val lastUsed = lastUsedByPackage()

        val infos = installed(lastUsed)
        total = infos.size

        val out = mutableListOf<AppEntry>()

        for (info in infos) {
            // Every package is a separate query into the stats service, and one
            // that throws must not end the loop: a work profile app or a package
            // mid uninstall will refuse, and the other two hundred are fine.
            val entry = runCatching {
                val uuid = info.storageUuid ?: storage.getUuidForPath(
                    app.filesDir,
                )
                val s = stats.queryStatsForPackage(uuid, info.packageName, user)
                AppEntry(
                    packageName = info.packageName,
                    label = packages.getApplicationLabel(info).toString(),
                    appBytes = s.appBytes,
                    dataBytes = s.dataBytes,
                    cacheBytes = s.cacheBytes,
                    system = info.flags and ApplicationInfo.FLAG_SYSTEM != 0,
                    lastUsedMillis = lastUsed[info.packageName],
                )
            }.getOrNull()

            // Counted whether or not it produced a row. The bar measures work
            // done against work to do, and a package that refused to answer
            // still took its turn.
            done++

            if (entry != null) out += entry
        }

        // Largest total first. The question this screen answers is which app is
        // taking the space, so the answer is the top row.
        return out.sortedByDescending { it.appBytes + it.dataBytes + it.cacheBytes }
    }

    /**
     * Every package this app is allowed to see.
     *
     * getInstalledApplications is filtered by package visibility from API 30, so
     * without QUERY_ALL_PACKAGES it returns very little. The usage stats list
     * fills the gap, and the union of the two is what this reports.
     */
    private fun installed(lastUsed: Map<String, Long>): List<ApplicationInfo> {
        val byPm = runCatching {
            packages.getInstalledApplications(0)
        }.getOrDefault(emptyList())

        val seen = byPm.mapTo(mutableSetOf()) { it.packageName }
        val out = byPm.toMutableList()

        for (name in lastUsed.keys) {
            if (!seen.add(name)) continue
            val info = runCatching {
                packages.getApplicationInfo(name, 0)
            }.getOrNull() ?: continue
            out += info
        }
        return out
    }

    /**
     * When each package was last in the foreground, over the last year.
     *
     * Doubles as the package list. A year rather than a month because an app
     * opened twice a year still occupies a gigabyte, and this screen is about
     * space rather than habits.
     */
    private fun lastUsedByPackage(): Map<String, Long> = runCatching {
        val usage = app.getSystemService(Context.USAGE_STATS_SERVICE)
            as UsageStatsManager
        val now = System.currentTimeMillis()
        val year = now - 365L * 24 * 60 * 60 * 1000

        usage.queryUsageStats(UsageStatsManager.INTERVAL_YEARLY, year, now)
            .filter { it.lastTimeUsed > 0 }
            .associate { it.packageName to it.lastTimeUsed }
    }.getOrDefault(emptyMap())
}

/** The bridge for app storage. */
internal class AppsHostApiImpl(context: Context) : AppsHostApi {

    private val reader = AppsReader(context)
    private val worker = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())

    /**
     * Cached for the life of the process.
     *
     * Reading two hundred packages takes seconds, and nothing about it changes
     * between two taps of the same screen. Invalidated by the app restarting,
     * which is also when an install or uninstall would have happened.
     */
    @Volatile
    private var cached: List<AppEntry>? = null

    /** Whether a read is in the loop right now, for the progress poll. */
    @Volatile
    private var reading: Boolean = false

    /**
     * Set when the user is sent to the Usage Access screen, cleared by the next
     * grant check. See [checkAccess].
     */
    @Volatile
    private var awaitingGrant: Boolean = false

    fun dispose() {
        worker.shutdownNow()
    }

    /**
     * Whether Usage Access is on, allowing for the system lying about it once.
     *
     * ─── THE READ RIGHT AFTER THE TOGGLE CAN BE STALE ────────────────────────
     *
     * The grant happens in another task with no result and no callback, so this
     * app learns about it by asking on resume. On several OEM builds the first
     * ask after the toggle still answers with the old value, and a single false
     * there is expensive: the screen settles on the ask-for-permission state
     * that the user has just satisfied, with nothing left to trigger another
     * look.
     *
     * So the one check that follows a trip to the settings screen is allowed a
     * second attempt, and only that one. Every other check answers immediately,
     * including the check for a user who went to the screen and chose not to
     * grant: they pay 400ms once, and then never again.
     */
    private fun checkAccess(): Boolean {
        val first = reader.hasUsageAccess()
        if (first || !awaitingGrant) {
            awaitingGrant = false
            return first
        }

        awaitingGrant = false
        Thread.sleep(400)
        return reader.hasUsageAccess()
    }

    override fun state(callback: (Result<AppsState>) -> Unit) {
        worker.execute {
            val granted = checkAccess()
            val apps = if (granted) (cached ?: load()) else emptyList()

            reply(
                callback,
                AppsState(
                    usageAccess = granted,
                    totalBytes = apps.sumOf {
                        it.appBytes + it.dataBytes + it.cacheBytes
                    },
                    cacheBytes = apps.sumOf { it.cacheBytes },
                    count = apps.size.toLong(),
                ),
            )
        }
    }

    override fun requestUsageAccess(callback: (Result<Boolean>) -> Unit) {
        val ok = reader.openUsageAccess()
        // Dropped, so the next read is fresh. The user is on their way to grant
        // it, and an empty cached list would survive the grant otherwise.
        cached = null
        awaitingGrant = true
        main.post { callback(Result.success(ok)) }
    }

    override fun apps(callback: (Result<List<AppEntry>>) -> Unit) {
        worker.execute {
            reply(callback, cached ?: load())
        }
    }

    /**
     * How far the read has got, answered without touching the worker.
     *
     * ─── IT MUST NOT QUEUE ───────────────────────────────────────────────────
     *
     * The worker is a single thread and the read owns it for the whole of its
     * run. A progress call submitted there would sit behind the very thing it
     * is reporting on and answer once, at the end, which is the one moment
     * nobody needs it. So this reads three volatile fields on the calling
     * thread and replies straight away.
     */
    override fun readProgress(callback: (Result<AppsProgress>) -> Unit) {
        callback(
            Result.success(
                AppsProgress(
                    done = reader.done.toLong(),
                    total = reader.total.toLong(),
                    reading = reading,
                ),
            ),
        )
    }

    override fun openAppSettings(
        packageName: String,
        callback: (Result<Boolean>) -> Unit,
    ) {
        val ok = reader.openAppSettings(packageName)
        // The user may clear a cache while they are there, so the sizes this
        // app holds are stale the moment the settings screen opens.
        cached = null
        main.post { callback(Result.success(ok)) }
    }

    /** The read, with the in-flight flag held around it. */
    private fun load(): List<AppEntry> {
        reading = true
        return try {
            reader.read().also { cached = it }
        } finally {
            reading = false
        }
    }

    private fun <T> reply(callback: (Result<T>) -> Unit, value: T) {
        main.post { callback(Result.success(value)) }
    }
}
