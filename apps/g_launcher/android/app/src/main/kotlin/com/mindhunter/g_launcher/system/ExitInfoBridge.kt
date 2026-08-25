package com.mindhunter.g_launcher.system

import android.app.ActivityManager
import android.app.ApplicationExitInfo
import android.content.Context
import android.os.Build
import android.util.Log
import androidx.annotation.RequiresApi
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/**
 * Why the PREVIOUS process died, read once on startup and handed to Dart.
 *
 * ─── THE GAP THIS CLOSES, AND WHY CRASHLYTICS ALONE NEVER SAW IT ────────────
 *
 * `freeze_watchdog.dart` reasoned correctly that a freeze is not a crash and
 * built its own detector. The gap turned out to be one layer further out than
 * it guessed. The launcher was not freezing and it was not filing ANRs. It was
 * being KILLED, six times in fourteen hours, with `reason=3 (LOW_MEMORY)`.
 *
 * A kill is not a crash and not an ANR. Nothing throws, no stack unwinds, no
 * signal is delivered that the process can catch, and the watchdog's own timer
 * dies with the isolate. Crashlytics reported nothing, correctly, and the only
 * reason we know it happened at all is that someone ran
 * `dumpsys activity exit-info` by hand.
 *
 * `ActivityManager.getHistoricalProcessExitReasons` is the one API that
 * survives the kill, because the SYSTEM keeps the record rather than the
 * process. It is API 30+, which is the same floor Crashlytics uses for its own
 * ANR collection, and below that this whole class is a no-op that reports an
 * empty list.
 *
 * ─── WHY A MethodChannel AND NOT PIGEON ─────────────────────────────────────
 *
 * Same reasoning as `NotificationBadges.kt`. Adding a class to the launcher
 * schema renumbers codec ids, and a shipped APK already agrees on the current
 * numbering. Diagnostics must not be able to break the wire format of the app
 * they are diagnosing.
 *
 * ─── WHY DART AND NOT THE FIREBASE ANDROID SDK ──────────────────────────────
 *
 * `Crash` in `lib/core/crash.dart` already owns every path into Crashlytics: it
 * buffers reports raised before Firebase is up, it no-ops cleanly on de-Googled
 * ROMs where `FirebaseCrashlytics.instance` throws, and it holds the custom-key
 * vocabulary. Reporting from Kotlin would mean a second, unguarded door into
 * the same service, on exactly the devices the guard exists for.
 */
object ExitInfoBridge {

    private const val TAG = "GLauncherExitInfo"
    private const val CHANNEL = "g_launcher/exit_info"

    /** Its own file. Nothing else has any business reading this watermark. */
    private const val PREFS = "g_launcher_exit_info"
    private const val KEY_WATERMARK = "lastReportedTimestampMs"

    /**
     * The system itself keeps at most 16 per package by default, so asking for
     * more returns the same list. Asking for fewer would silently drop exits on
     * a device that is churning, which is the device we most want to hear from.
     */
    private const val MAX_RECORDS = 16

    /** Enough of an ANR trace to name the blocking frame. The full dump is MBs. */
    private const val TRACE_BYTES = 16 * 1024

    fun setUp(context: Context, messenger: BinaryMessenger) {
        val appContext = context.applicationContext
        MethodChannel(messenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                // `commit` defaults TRUE, so an older Dart side that sends no
                // argument keeps the original behaviour rather than silently
                // re-reporting the same exits on every launch forever.
                "drain" -> {
                    val commit = (call.argument<Boolean>("commit")) ?: true
                    result.success(drain(appContext, commit))
                }

                else -> result.notImplemented()
            }
        }
    }

    /**
     * Every reportable exit newer than the watermark, oldest first, and then
     * the watermark moves.
     *
     * ─── THE WATERMARK IS THE WHOLE DESIGN ──────────────────────────────────
     *
     * The system's list is a rolling window that does not clear when read, so
     * without one, every cold start would re-report the same sixteen exits. A
     * launcher cold-starts many times a day. Within a week the dashboard would
     * hold thousands of copies of one bad night and nobody would ever read it
     * again.
     *
     * It advances on DRAIN rather than on successful report, which loses at
     * most one batch if the process dies between this call and Crashlytics
     * accepting it. That is the correct trade: the alternative is a second
     * round trip whose failure mode is duplicate reporting, which is the thing
     * the watermark exists to prevent.
     *
     * ─── AND WHY [commit] IS FALSE IN DEBUG ─────────────────────────────────
     *
     * `Crash.enable` turns Crashlytics COLLECTION off in debug while still
     * setting `_live`, so a debug run would drain these records, advance the
     * watermark, and hand them to a reporter that discards them. The system's
     * ring buffer holds sixteen exits and does not refill on demand, so one
     * `flutter run` would consume the whole history of a bad night and the
     * release build afterwards would find nothing.
     *
     * A read with `commit = false` sees exactly what a committing read would
     * see, which is what makes it useful for verifying the bridge on a debug
     * build without spending the evidence.
     */
    private fun drain(context: Context, commit: Boolean): List<Map<String, Any?>> {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) return emptyList()
        return runCatching { drainR(context, commit) }
            .onFailure { Log.w(TAG, "drain failed", it) }
            .getOrDefault(emptyList())
    }

    @RequiresApi(Build.VERSION_CODES.R)
    private fun drainR(context: Context, commit: Boolean): List<Map<String, Any?>> {
        val am = context.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val watermark = prefs.getLong(KEY_WATERMARK, 0L)

        val all = am.getHistoricalProcessExitReasons(context.packageName, 0, MAX_RECORDS)

        // Oldest first. Crashlytics shows breadcrumbs in the order they arrive,
        // and a night that degraded from EXCESSIVE_CPU into repeated LOW_MEMORY
        // reads as a story in that order and as noise in the other.
        val fresh = all
            .filter { it.timestamp > watermark }
            .filter { isReportable(it.reason) }
            .sortedBy { it.timestamp }

        val newest = all.maxOfOrNull { it.timestamp } ?: watermark
        if (commit && newest > watermark) {
            prefs.edit().putLong(KEY_WATERMARK, newest).apply()
        }

        Log.i(TAG, "drain commit=$commit fresh=${fresh.size} of ${all.size}")
        return fresh.map { describe(it) }
    }

    /**
     * The exits worth a report, and nothing else.
     *
     * USER_REQUESTED, PACKAGE_UPDATED, EXIT_SELF, PERMISSION_CHANGE and
     * PACKAGE_STATE_CHANGE are all excluded because they are the OS working
     * correctly. On the sample that motivated this file, nine of sixteen exits
     * were force-stops and reinstalls from a developer's own `flutter run`, and
     * reporting those would have buried the six that mattered.
     *
     * SIGNALED is in, because a launcher does not normally get signalled and
     * when it does we want to know. FREEZER is in for the same reason and is
     * API 31, but the constant is a compile-time `static final int` so it
     * inlines and this set is safe to build on API 30.
     */
    @RequiresApi(Build.VERSION_CODES.R)
    private fun isReportable(reason: Int): Boolean = when (reason) {
        ApplicationExitInfo.REASON_LOW_MEMORY,
        ApplicationExitInfo.REASON_CRASH_NATIVE,
        ApplicationExitInfo.REASON_ANR,
        ApplicationExitInfo.REASON_EXCESSIVE_RESOURCE_USAGE,
        ApplicationExitInfo.REASON_SIGNALED,
        ApplicationExitInfo.REASON_FREEZER,
        -> true

        else -> false
    }

    @RequiresApi(Build.VERSION_CODES.R)
    private fun describe(info: ApplicationExitInfo): Map<String, Any?> = mapOf(
        "reason" to info.reason,
        "reasonName" to reasonName(info.reason),
        "status" to info.status,
        "importance" to info.importance,
        // BYTES here, not the KB the platform returns. Every other size in this
        // codebase is bytes and one field in KB is a unit bug waiting to be
        // written into a dashboard filter.
        "pssBytes" to info.pss * 1024L,
        "rssBytes" to info.rss * 1024L,
        "timestampMs" to info.timestamp,
        "description" to info.description,
        "processName" to info.processName,
        "trace" to trace(info),
    )

    /**
     * The Dart-side trace for an ANR, truncated.
     *
     * `getTraceInputStream` is non-null ONLY for REASON_ANR and native crashes,
     * and even then only while the system still holds the file. A null here is
     * the normal case, not a failure.
     */
    @RequiresApi(Build.VERSION_CODES.R)
    private fun trace(info: ApplicationExitInfo): String? = runCatching {
        info.traceInputStream?.use { stream ->
            val buffer = ByteArray(TRACE_BYTES)
            val read = stream.read(buffer)
            if (read <= 0) null else String(buffer, 0, read, Charsets.UTF_8)
        }
    }.getOrNull()

    /**
     * Stable snake_case names, because these become the Crashlytics ISSUE TITLE
     * on the Dart side and a raw integer groups fine but reads as nothing. Kept
     * as a `when` rather than a map so a reason the platform adds later falls
     * through to a name that still says the number.
     */
    @RequiresApi(Build.VERSION_CODES.R)
    private fun reasonName(reason: Int): String = when (reason) {
        ApplicationExitInfo.REASON_LOW_MEMORY -> "low_memory"
        ApplicationExitInfo.REASON_CRASH_NATIVE -> "crash_native"
        ApplicationExitInfo.REASON_ANR -> "anr"
        ApplicationExitInfo.REASON_EXCESSIVE_RESOURCE_USAGE -> "excessive_resource_usage"
        ApplicationExitInfo.REASON_SIGNALED -> "signaled"
        ApplicationExitInfo.REASON_FREEZER -> "freezer"
        else -> "reason_$reason"
    }
}
