package com.mindhunter.g_launcher.system

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.provider.MediaStore
import android.util.Log

/**
 * The user's own photos, for the wallpaper page's Gallery strip.
 *
 * ─── THREE STATES, BECAUSE ANDROID 14 MADE PARTIAL THE DEFAULT ─────────────
 *
 * The system dialog's primary button is "Select photos", not "Allow all", so a
 * partial grant is what most people give. Treating that as a denial would hide
 * the strip for the majority and make the feature look broken; treating it as
 * full access would show a handful of photos with no explanation of why the
 * rest are missing.
 *
 * So it is its own state, and the UI says which one it is.
 *
 * ─── AND WHY THIS DOES NOT REQUEST ANYTHING BACK ───────────────────────────
 *
 * [request] fires the dialog and returns. Nothing here waits for a result and
 * no `onRequestPermissionsResult` is plumbed through: the dialog resumes the
 * activity when it closes, and the page re-reads [state] then. That is the same
 * reasoning `RoleRequester` gives for avoiding activity-result plumbing, and it
 * holds harder here because the answer can also change from the Settings app
 * while this process is asleep.
 */
class GalleryReader(context: Context) {

    companion object {
        private const val TAG = "GLauncherGallery"

        const val DENIED = "denied"
        const val PARTIAL = "partial"
        const val GRANTED = "granted"
    }

    private val appContext = context.applicationContext

    /** [DENIED], [PARTIAL] or [GRANTED]. */
    fun state(): String {
        // Below Android 13 there is one broad storage permission and no partial
        // grant to distinguish, so the answer is binary.
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            return if (granted(Manifest.permission.READ_EXTERNAL_STORAGE)) {
                GRANTED
            } else {
                DENIED
            }
        }

        if (granted(Manifest.permission.READ_MEDIA_IMAGES)) return GRANTED

        // Android 14 only. Checked AFTER the full grant, because a phone with
        // both held is fully granted and the narrower one is then noise.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE &&
            granted(Manifest.permission.READ_MEDIA_VISUAL_USER_SELECTED)
        ) {
            return PARTIAL
        }

        return DENIED
    }

    /**
     * Open the system dialog. Returns false when there is no activity to show
     * it from, which happens if the page is somehow alive while the launcher is
     * not resumed.
     */
    fun request(activity: Activity?): Boolean {
        if (activity == null) return false

        val wanted = when {
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE ->
                arrayOf(
                    Manifest.permission.READ_MEDIA_IMAGES,
                    // Asked for TOGETHER, not instead. Android shows one dialog
                    // whose "Select photos" button grants the second and whose
                    // "Allow all" grants the first, so requesting both is what
                    // makes that dialog offer both answers.
                    Manifest.permission.READ_MEDIA_VISUAL_USER_SELECTED,
                )

            Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU ->
                arrayOf(Manifest.permission.READ_MEDIA_IMAGES)

            else -> arrayOf(Manifest.permission.READ_EXTERNAL_STORAGE)
        }

        return try {
            // requestCode 0: nothing reads it back. See the class doc.
            activity.requestPermissions(wanted, 0)
            true
        } catch (e: Exception) {
            Log.w(TAG, "could not open the permission dialog", e)
            false
        }
    }

    /**
     * The most recent images, newest first, as absolute paths.
     *
     * ─── PATHS, NOT URIs ────────────────────────────────────────────────────
     *
     * The caller copies whichever one is picked into app storage, exactly as
     * the photo-picker path already does, and a path is what that copy needs.
     * `DATA` is soft-deprecated and unreliable for anything the app did not
     * write, so a row with no readable path is DROPPED rather than returned as
     * a URI the Dart side has no way to open.
     *
     * Under a partial grant this returns only the photos that were shared,
     * which is the correct and complete answer to "what can this app see".
     */
    fun recent(limit: Long): List<String> {
        if (state() == DENIED) return emptyList()

        val out = mutableListOf<String>()
        try {
            val projection = arrayOf(MediaStore.Images.Media.DATA)
            appContext.contentResolver.query(
                MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
                projection,
                null,
                null,
                "${MediaStore.Images.Media.DATE_ADDED} DESC",
            )?.use { cursor ->
                val col = cursor.getColumnIndex(MediaStore.Images.Media.DATA)
                if (col < 0) return emptyList()
                while (cursor.moveToNext() && out.size < limit) {
                    val path = cursor.getString(col) ?: continue
                    if (path.isNotEmpty()) out.add(path)
                }
            }
        } catch (e: Exception) {
            // A revoked permission mid-query, or an OEM MediaStore that answers
            // differently. An empty strip is a fine outcome; a dead settings
            // page is not.
            Log.w(TAG, "could not read recent images", e)
        }
        return out
    }

    private fun granted(permission: String): Boolean =
        appContext.checkSelfPermission(permission) ==
            PackageManager.PERMISSION_GRANTED
}
