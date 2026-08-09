package com.mindberzerk.device_probe

import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Environment

/**
 * WHICH STORAGE MODEL THIS DEVICE IS ON, and what it has actually granted.
 *
 * ─── TWO QUESTIONS, ASKED TOGETHER ON PURPOSE ────────────────────────────────
 *
 * The API level says which permissions EXIST. It says nothing about which were
 * given. Deciding what to offer from the level alone produces a screen that
 * offers a restore and then fails on the last step, which is the worst place to
 * discover a permission problem. Both halves are read here and returned in one
 * object so no caller can accidentally use one without the other.
 *
 * ─── NOTHING IS CACHED ───────────────────────────────────────────────────────
 *
 * [ProbeCapabilities] is probed once and held for the process, because a kernel
 * does not change its mind about sysfs. All Files Access is different: it is a
 * toggle in Settings the user can flip while this app is in the background. A
 * cached answer would have the app refusing work the system would now allow, or
 * offering work it would now refuse. Every field here is read on every call, and
 * all of them are cheap.
 *
 * ─── OLD DEVICES HAVE MORE ACCESS, NOT LESS ──────────────────────────────────
 *
 * Worth stating where the code lives, because the shape is counterintuitive and
 * someone will eventually try to "fix" it. Android 11 is what closed per app
 * storage to outside readers. On API 24 to 28 a plain storage permission walks
 * the whole volume, including the per app trash folders the map points at. On
 * 30 and up nothing reaches those directly, at any permission level. The old
 * tier loses the platform's blessed route and gains the filesystem.
 */
internal class StorageAccessProbe(context: Context) {

    private val app: Context = context.applicationContext

    fun read(): StorageAccess {
        val sdk = Build.VERSION.SDK_INT

        val tier = when {
            sdk >= Build.VERSION_CODES.R -> "managed"
            sdk == Build.VERSION_CODES.Q -> "scoped"
            else -> "legacy"
        }

        val legacyGranted = sdk <= Build.VERSION_CODES.P && hasLegacyStorage()

        // The grant, not the possibility. Guarded rather than caught: the method
        // does not exist below R and calling it there is a hard failure rather
        // than a false.
        val allFilesGranted =
            sdk >= Build.VERSION_CODES.R && Environment.isExternalStorageManager()

        // Whether the settings screen would actually open. Several ROMs ship
        // without it, and sending someone to an intent that resolves to nothing
        // is worse than telling them the device will not do this.
        val allFilesPossible = sdk >= Build.VERSION_CODES.R && settingsScreenExists()

        return StorageAccess(
            sdkInt = sdk.toLong(),
            tier = tier,
            osTrashBin = sdk >= Build.VERSION_CODES.R,
            allFilesAccessPossible = allFilesPossible,
            allFilesAccessGranted = allFilesGranted,
            legacyStorageGranted = legacyGranted,
            // THE FIELD THAT DECIDES WHETHER A SCAN IS WORTH RUNNING. Per app
            // storage is walkable only on the legacy tier, and only once the
            // permission is held. No amount of granting reopens it from 29.
            appDataReadable = legacyGranted,
            // Everything else falls back to MediaStore plus whatever a document
            // tree grant provides.
            mediaStoreOnly = !legacyGranted && !allFilesGranted,
        )
    }

    /**
     * Read and write to shared storage, on the tier where those still mean
     * something.
     *
     * Both are checked. The pair is what the legacy tier needs: read to find a
     * deleted file and write to put it back, and a restore that discovers the
     * second half is missing has already shown the user a result it cannot
     * deliver.
     */
    private fun hasLegacyStorage(): Boolean {
        val read = app.checkSelfPermission(android.Manifest.permission.READ_EXTERNAL_STORAGE)
        val write = app.checkSelfPermission(android.Manifest.permission.WRITE_EXTERNAL_STORAGE)
        return read == PackageManager.PERMISSION_GRANTED &&
            write == PackageManager.PERMISSION_GRANTED
    }

    /**
     * Does the All Files Access screen resolve.
     *
     * Needs the matching entry in the manifest's queries block, or this comes
     * back empty on Android 11 and up and the app reports the grant as
     * unavailable on a device where it works fine.
     */
    private fun settingsScreenExists(): Boolean {
        val intent = Intent(android.provider.Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION)
        return intent.resolveActivity(app.packageManager) != null
    }
}
