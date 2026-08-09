package com.mindhunter.g_recovery.recovery

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Environment
import android.provider.Settings

/**
 * The All Files Access gate.
 *
 * This is the single most consequential permission in the app and the reason it
 * exists is narrow: on Android 11 and above, a MediaStore query with
 * MATCH_INCLUDE returns only the items THIS app trashed. Another app's deleted
 * photo is invisible without it. A freshly installed G Recovery has trashed
 * nothing, so without the grant the ledger is empty on every device forever.
 *
 * minSdk is 30, so there is no legacy storage path to maintain and no version
 * branch here.
 */
internal class Access(private val context: Context) {

    fun isGranted(): Boolean = try {
        Environment.isExternalStorageManager()
    } catch (_: Throwable) {
        false
    }

    /**
     * Whether anything on this device can show the grant screen.
     *
     * Checked rather than assumed because a handful of stripped-down ROMs ship
     * without the settings activity, and a button that opens nothing is worse
     * than a button that is absent. Requires the targeted `<intent>` entry in
     * the manifest `<queries>` block, or the resolve comes back empty on
     * Android 11+ even where the activity exists.
     */
    fun isSettingsAvailable(): Boolean =
        settingsIntent().resolveActivity(context.packageManager) != null

    fun openSettings(): Boolean {
        val intent = settingsIntent().apply {
            // Started from the application context, so the flag is mandatory.
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        return try {
            context.startActivity(intent)
            true
        } catch (_: Throwable) {
            false
        }
    }

    /**
     * The per-app screen, not the global list.
     *
     * ACTION_MANAGE_ALL_FILES_ACCESS_PERMISSION drops the user into a list of
     * every app on the device and expects them to find ours. The per-app variant
     * with a package URI lands on one toggle.
     */
    private fun settingsIntent(): Intent = Intent(
        Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION,
        Uri.parse("package:${context.packageName}"),
    )
}
