package com.mindhunter.g_launcher.cdn

import android.content.Context
import androidx.work.Constraints
import androidx.work.Data
import androidx.work.OutOfQuotaPolicy
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.ExistingWorkPolicy
import androidx.work.NetworkType
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.Worker
import androidx.work.WorkerParameters
import com.mindhunter.g_launcher.theme.PackKeys
import com.mindhunter.g_launcher.theme.PackVerifier
import com.mindhunter.g_launcher.theme.ThemeAssetLoader
import java.io.File
import java.util.concurrent.TimeUnit

/**
 * PHASE C2 - keeps installed packs current, in the background, with no UI.
 *
 * The brand pack is the first payload through this pipeline on purpose. It is
 * one JSON file that has to grow forever as new apps appear, it exercises the
 * whole chain (fetch, verify, cache, hot-swap without a restart), and if it
 * fails the worst outcome is a few apps keep their generated icons for another
 * day. A theme pack, by contrast, can take the home screen down. Themes second.
 *
 * WHY A WORKER AND NOT A COROUTINE AT APP START. A launcher process is killed
 * constantly - it is the thing the OS reclaims first when a game wants memory -
 * so anything started in `onCreate` gets roughly as long as the user stays on
 * the home screen, which on a phone is seconds. WorkManager owns the schedule,
 * survives the process, and honours Doze and the metered-network constraint
 * that keeps this off a user's data bundle.
 *
 * ONLY UPDATES WHAT IS ALREADY INSTALLED, plus [PackPaths.bundledPackIds] and
 * THE ACTIVE THEME. A background job that silently adds packs is a background
 * job that silently uses someone's storage, so new installs stay a user action
 * in the storefront.
 *
 * The bundled exception is narrow and necessary. `simple-icons` ships in the
 * APK, so it is not "installed" by the loader's definition, so without this it
 * would sit at its 39-entry seed set on every device forever and the entire CDN
 * pipeline would quietly do nothing. Those packs are already on the device and
 * already in use; the download only makes an existing feature more complete.
 *
 * ─── AND THE ACTIVE THEME, WHICH IS THE SAME ARGUMENT ───────────────────────
 *
 * A bundled distro is in exactly the position `simple-icons` was in. Select
 * Ubuntu and it renders from the APK: nothing is "installed" under that id, so
 * `installedPackIds` never names it, so a corrected Ubuntu published over the
 * CDN was downloaded by nobody. The pipeline worked end to end and had no
 * effect on the one distro most people are actually looking at.
 *
 * `theme_engine` was already ready for this. It resolves INSTALLED before
 * BUNDLED precisely so a republished free distro can supersede the APK copy,
 * and its comment says as much. What was missing was anything that fetched the
 * pack, so the superseding branch could never be reached without a trip to the
 * storefront and a deliberate tap.
 *
 * This does not weaken the no-silent-installs rule. The active theme is a
 * distro the user CHOSE and is looking at right now; updating it is the same
 * category as updating something already installed, not the same category as
 * adding something they never asked for. Nothing else in the catalogue is
 * touched.
 */
class PackSyncWorker(context: Context, params: WorkerParameters) : Worker(context, params) {

    override fun doWork(): Result {
        // ── A TARGETED INSTALL IS A DIFFERENT JOB IN THE SAME WORKER ─────────
        //
        // Everything below this line follows one rule: ONLY UPDATE WHAT IS
        // ALREADY INSTALLED. That rule exists so a background job can never
        // spend someone's storage on packs they did not ask for, and it is
        // exactly wrong for the case this branch serves, where a user has just
        // PAID for a pack that is by definition not installed yet.
        //
        // So it is a branch rather than a parameter. Same worker, because
        // WorkManager is already the thing that survives the process being
        // killed, and a second worker would be a second lifecycle to keep in
        // step with this one.
        val targets = inputData.getStringArray(KEY_TARGETS)
        if (targets != null && targets.isNotEmpty()) {
            return installTargets(targets.toList())
        }

        val packsRoot = File(applicationContext.filesDir, "packs")
        packsRoot.mkdirs()

        val verifier = PackVerifier(
            acceptedKeys = PackKeys.accepted,
            appVersionCode = appVersionCode(),
        )
        val loader = ThemeAssetLoader(packsRoot, verifier)
        val downloader = PackDownloader(
            client = CdnClient(CdnConfig.baseUrl(packsRoot)),
            loader = loader,
            packsRoot = packsRoot,
            acceptedKeys = PackKeys.accepted,
            verifier = verifier,
        )

        val index = when (val r = downloader.refreshIndex()) {
            is IndexResult.Updated -> r.index
            is IndexResult.Unchanged -> r.index
            is IndexResult.Stale -> r.kept
            // A transport failure is the normal case on a phone: retry with
            // WorkManager's backoff. A REJECTED index is not - it means the
            // signature failed, and retrying a bad signature just burns battery
            // producing the same answer.
            is IndexResult.Failed -> return Result.retry()
            is IndexResult.Rejected -> return Result.failure()
        }

        var installedAnything = false
        val toSync = LinkedHashSet<String>().apply {
            addAll(loader.installedPackIds())
            addAll(PackPaths.bundledPackIds)
            // ORDERED LAST, and the set is a LinkedHashSet, so an active theme
            // that is also installed keeps its earlier position rather than
            // being queued twice. On a metered connection the order decides who
            // gets the budget, and something already installed is the safer
            // first spend.
            activeThemeId()?.let(::add)
        }

        // ── THE DATA BUNDLE RULE, NOW A SIZE TEST RATHER THAN A BLANKET NO ───
        //
        // This job used to require an UNMETERED network for everything, with a
        // good argument on it about not spending someone's data. That argument
        // was written for a 3.5MB brand pack and then applied to a 140KB distro,
        // and it aged badly against the audience: on a budget phone in Nairobi
        // or Lagos wifi is not the default state, so "wait for wifi" often means
        // "never", and a device that never syncs is a device the whole pipeline
        // does nothing for.
        //
        // So the constraint moved from the schedule to the payload. The index is
        // a couple of KB behind an ETag and is now fetched on any connection,
        // which is what makes a device aware there is anything to get. A pack
        // over [METERED_MAX_BYTES] still waits, because the original argument is
        // right about big payloads and only wrong about small ones.
        //
        // `sizeBytes` here is the INDEX's advisory copy, used to decide whether
        // to start; the signed manifest's total is what the free-space check and
        // the per-file caps use. An index that lies about a size cannot get a
        // byte past `CdnClient.download`, which caps every file at its exact
        // signed length.
        val metered = isMetered()
        for (packId in toSync) {
            if (metered) {
                val size = index.pack(packId)?.sizeBytes ?: 0L
                if (size > METERED_MAX_BYTES) continue
            }
            when (val r = downloader.syncPack(packId, index)) {
                is SyncResult.Installed -> {
                    installedAnything = true
                    val type = index.pack(packId)?.packType ?: "unknown"
                    // The hot-swap. Without this the new pack sits on disk,
                    // fully verified, doing nothing until the process restarts.
                    PackChangeNotifier.notifyInstalled(type, packId)
                }
                // Everything else is either normal (UpToDate, NotOffered) or
                // not fixable by retrying the whole job right now. One pack
                // failing must not stop the others syncing.
                else -> Unit
            }
        }

        // Success either way. There is nothing to retry: every pack was either
        // current, absent from the index, or failed for a reason retrying in
        // thirty seconds would reproduce exactly. The periodic schedule is the
        // retry.
        if (installedAnything) {
            // Nothing to do here today. The hot-swap already happened via
            // PackChangeNotifier, synchronously, inside the loop.
        }
        return Result.success()
    }

    /**
     * The distro the user currently has selected, or null.
     *
     * ─── READ STRAIGHT OUT OF FLUTTER'S PREFS FILE ──────────────────────────
     *
     * This worker runs with no Flutter engine. WorkManager wakes the process for
     * a job, not for a launcher, so there is no Dart isolate to ask and starting
     * one to read a single string would cost more than the sync it is deciding
     * about.
     *
     * `shared_preferences` on Android is a plain SharedPreferences file named
     * `FlutterSharedPreferences` with every key prefixed `flutter.`, which is a
     * stable, documented part of that plugin rather than an implementation
     * detail. The key itself is `selectedThemeKey` in prefs_repository.dart and
     * the two must agree; there is no way to share the constant across the
     * language boundary, so it is written down in both places and named here so
     * a grep for either finds the other.
     *
     * Null on ANY failure, including the perfectly ordinary case of a first run
     * where nothing has been selected yet. Null simply means this pass syncs
     * what it already would have.
     */
    private fun activeThemeId(): String? = try {
        applicationContext
            .getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            .getString("flutter.selectedThemeId.v1", null)
            ?.takeIf { it.isNotBlank() }
    } catch (_: Exception) {
        null
    }

    /**
     * Is the active connection metered?
     *
     * Defaults to TRUE on any failure, which is the cautious direction: an
     * unknown network treated as unmetered would spend a data bundle on the
     * strength of an exception, while an unmetered one treated as metered only
     * delays a large pack until the next pass.
     */
    private fun isMetered(): Boolean = try {
        val cm = applicationContext.getSystemService(android.net.ConnectivityManager::class.java)
        cm?.isActiveNetworkMetered ?: true
    } catch (_: Exception) {
        true
    }

    /**
     * Must match `_appVersionCode` in theme_engine.dart and the versionCode in
     * the manifest. Read from PackageManager rather than hardcoded so a release
     * bump cannot leave this behind - which would silently refuse every pack
     * that targets the new build.
     */
    private fun appVersionCode(): Int = try {
        val pm = applicationContext.packageManager
        val info = pm.getPackageInfo(applicationContext.packageName, 0)
        @Suppress("DEPRECATION")
        info.versionCode
    } catch (_: Exception) {
        0
    }

    /**
     * Install exactly [ids], as soon as WorkManager will run us.
     *
     * ─── WHY THIS RUNS IN A WORKER AT ALL ────────────────────────────────────
     *
     * The purchase path used to call `syncPack` through the Pigeon host API,
     * which runs on the Flutter engine's thread and dies with the process. A
     * launcher is the first thing Android reclaims when a game wants memory, so
     * on the 3GB devices this app targets, opening any app right after buying
     * could kill a half-finished download of something the user had just paid
     * for, with nothing left to resume it. WorkManager is the only thing here
     * that outlives that.
     *
     * ─── AND WHY THERE IS NO NOTIFICATION ────────────────────────────────────
     *
     * `setForeground` would make this start immediately and would stop the OS
     * deprioritising it, but it requires FOREGROUND_SERVICE_DATA_SYNC, a typed
     * service entry and a Play Console declaration that is reviewed. The thing
     * actually worth protecting is that a PAID download is not lost, and
     * ordinary work already gives that: it survives the process, it retries
     * with backoff, and it resumes by itself.
     *
     * What is given up is the guarantee of running RIGHT NOW. WorkManager may
     * defer by seconds or, on an aggressive OEM battery manager, longer. The
     * cost of that is a pack landing quietly some time after the purchase,
     * which is why `installedPackIds` is worth checking at startup: see the
     * note on the resume path in the Dart layer.
     */
    private fun installTargets(ids: List<String>): Result {
        val packsRoot = File(applicationContext.filesDir, "packs")
        packsRoot.mkdirs()

        val verifier = PackVerifier(
            acceptedKeys = PackKeys.accepted,
            appVersionCode = appVersionCode(),
        )
        val loader = ThemeAssetLoader(packsRoot, verifier)
        val downloader = PackDownloader(
            client = CdnClient(CdnConfig.baseUrl(packsRoot)),
            loader = loader,
            packsRoot = packsRoot,
            acceptedKeys = PackKeys.accepted,
            verifier = verifier,
        )

        val index = when (val r = downloader.refreshIndex()) {
            is IndexResult.Updated -> r.index
            is IndexResult.Unchanged -> r.index
            is IndexResult.Stale -> r.kept
            is IndexResult.Failed -> return Result.retry()
            is IndexResult.Rejected -> return Result.failure()
        }

        var failed = false
        for (id in ids) {
            when (downloader.syncPack(id, index)) {
                is SyncResult.Installed, is SyncResult.UpToDate -> Unit
                // ONLY A TRANSPORT FAILURE IS RETRIED, and it is the only
                // member that describes one. `NotOffered` means the index does
                // not carry this pack, which includes the entitlement case
                // because an unowned pack is not offered; `AppTooOld` needs a
                // Play release; `NoSpace` needs the user to free some; a
                // `Rejected` signature is not going to verify on the second
                // attempt. Retrying any of them spends battery and someone's
                // data to arrive at the same answer.
                is SyncResult.NotOffered,
                is SyncResult.AppTooOld,
                is SyncResult.NoSpace,
                is SyncResult.Rejected,
                SyncResult.Cancelled,
                -> Unit
                // Failed, and anything added later. A transport failure is the
                // normal case on a phone and the whole reason this is a worker.
                else -> failed = true
            }
        }

        // RETRY rather than failure. The usual cause of a partial install is
        // the network dropping mid-pass, and the point of routing this through
        // WorkManager is that it comes back on its own. A user must never have
        // to remember that they paid for something.
        return if (failed) Result.retry() else Result.success()
    }

    companion object {
        private const val WORK_NAME = "g_launcher_pack_sync"
        private const val KEY_TARGETS = "targets"

        /**
         * Install [ids], surviving the app being killed.
         *
         * EXPEDITED, with a non-expedited fallback. A purchase is the most
         * user-initiated thing this app does, so it should not sit behind a
         * daily sweep. `RUN_AS_NON_EXPEDITED_WORK_REQUEST` is what makes that
         * safe without a foreground service: an app that has exhausted its
         * expedited quota degrades to ordinary work instead of throwing, which
         * is the difference between "slower" and "the thing they paid for
         * never arrived".
         *
         * UNIQUE PER PACK SET and KEEP, so a double tap, or a second
         * entitlement push for the same purchase, does not download twice.
         */
        fun installNow(context: Context, ids: List<String>) {
            if (ids.isEmpty()) return

            val request = OneTimeWorkRequestBuilder<PackSyncWorker>()
                .setInputData(
                    Data.Builder()
                        .putStringArray(KEY_TARGETS, ids.toTypedArray())
                        .build(),
                )
                .setConstraints(
                    Constraints.Builder()
                        .setRequiredNetworkType(NetworkType.CONNECTED)
                        .build(),
                )
                .setExpedited(OutOfQuotaPolicy.RUN_AS_NON_EXPEDITED_WORK_REQUEST)
                .build()

            WorkManager.getInstance(context).enqueueUniqueWork(
                "$WORK_NAME-install-${ids.sorted().joinToString("+")}",
                ExistingWorkPolicy.KEEP,
                request,
            )
        }

        /**
         * The most this job will pull over someone's mobile data, per pack.
         *
         * 2MB covers a distro comfortably: a full Ubuntu pack with three
         * wallpapers is around 140KB. It does not cover the brand pack, which
         * is megabytes of glyph paths and gains nothing by arriving today
         * rather than the next time the phone sees wifi.
         */
        private const val METERED_MAX_BYTES = 2L * 1024 * 1024

        /**
         * Call once from `LauncherApplication.onCreate`.
         *
         * KEEP is deliberate: REPLACE would reset the interval on every cold
         * start, and a launcher cold-starts many times a day, so the job would
         * effectively never run.
         *
         * Daily, connected, not-low-battery. CONNECTED rather than UNMETERED,
         * with the data-bundle promise kept per PACK instead: see the size test
         * in [doWork]. A launcher spending someone's data on megabytes of icon
         * glyphs is still not a trade this app gets to make, but refusing to
         * spend two kilobytes finding out whether their distro was fixed was
         * the wrong shape of caution.
         */
        fun schedule(context: Context) {
            val request = PeriodicWorkRequestBuilder<PackSyncWorker>(1, TimeUnit.DAYS)
                .setConstraints(
                    Constraints.Builder()
                        .setRequiredNetworkType(NetworkType.CONNECTED)
                        .setRequiresBatteryNotLow(true)
                        .build(),
                )
                .setInitialDelay(2, TimeUnit.HOURS)
                .build()

            WorkManager.getInstance(context).enqueueUniquePeriodicWork(
                WORK_NAME,
                ExistingPeriodicWorkPolicy.KEEP,
                request,
            )
        }

        /**
         * One immediate pass, on top of the daily schedule.
         *
         * Fired when a FOREGROUND refresh sees a new index: the user is looking
         * at the store at that exact moment, so "the catalogue changed" and
         * "nothing happens until tomorrow" cannot both be true. Same CONNECTED
         * constraint as the daily job, and the same per-pack size test inside
         * it: someone standing in the store on mobile data gets their small
         * packs now and their brand pack on the next wifi.
         *
         * KEEP, not REPLACE: several refreshes in one store visit collapse
         * into one pass instead of queueing five identical ones.
         */
        fun syncNow(context: Context) {
            val request = OneTimeWorkRequestBuilder<PackSyncWorker>()
                .setConstraints(
                    Constraints.Builder()
                        .setRequiredNetworkType(NetworkType.CONNECTED)
                        .build(),
                )
                .build()

            WorkManager.getInstance(context).enqueueUniqueWork(
                "$WORK_NAME-now",
                ExistingWorkPolicy.KEEP,
                request,
            )
        }
    }
}
