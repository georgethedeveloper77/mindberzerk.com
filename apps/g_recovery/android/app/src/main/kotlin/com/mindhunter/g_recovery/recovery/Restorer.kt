package com.mindhunter.g_recovery.recovery

import android.content.ContentUris
import android.content.ContentValues
import android.content.Context
import android.os.Environment
import android.provider.MediaStore
import java.io.File

/**
 * Puts things back.
 *
 * Two completely different mechanisms behind one call, which is exactly why the
 * item id is opaque: the UI must not have to know which one it is asking for.
 *
 *  - A MediaStore row is un-trashed IN PLACE. IS_TRASHED goes to 0 and the file
 *    returns to the folder it was deleted from, with its original name. This is
 *    the only true restore in the app.
 *  - A loose file is COPIED into a recovery folder. Its original location was
 *    never recorded anywhere on the device, so putting it "back" is not
 *    something anyone can do, and inventing a destination would scatter files
 *    with confidence. The UI says where it went.
 */
internal class Restorer(private val context: Context) {

    private val collection = MediaStore.Files.getContentUri(MediaStore.VOLUME_EXTERNAL)

    fun restore(record: RecoveryIndex.Record, restoreFolder: String): RestoreOutcome =
        when (record) {
            is RecoveryIndex.Record.Media -> unTrash(record)
            is RecoveryIndex.Record.Loose -> copyOut(record, restoreFolder)
        }

    fun purge(record: RecoveryIndex.Record): RestoreOutcome = when (record) {
        is RecoveryIndex.Record.Media -> deleteMedia(record)
        is RecoveryIndex.Record.Loose -> deleteFile(record)
    }

    private fun unTrash(record: RecoveryIndex.Record.Media): RestoreOutcome {
        val uri = ContentUris.withAppendedId(collection, record.mediaId)
        val values = ContentValues().apply {
            put(MediaStore.Files.FileColumns.IS_TRASHED, 0)
        }
        return try {
            val updated = context.contentResolver.update(uri, values, null)
            if (updated > 0) {
                outcome(record, "restored", "Returned to its original folder", record.item.relativePath)
            } else {
                // Zero rows almost always means the OS already swept it between
                // the scan and the tap. A stale list is not a failure, and the
                // copy has to say so or the user retries forever.
                outcome(record, "expired", "Android already removed this permanently", null)
            }
        } catch (error: SecurityException) {
            // With All Files Access this should not happen. If it does, the
            // system wants explicit per-item consent, which is a different flow
            // and a different message, not a retry.
            outcome(record, "needsConsent", "Android wants you to confirm this one", null)
        } catch (error: Throwable) {
            outcome(record, "failed", error.message ?: "Could not restore", null)
        }
    }

    private fun copyOut(
        record: RecoveryIndex.Record.Loose,
        restoreFolder: String,
    ): RestoreOutcome {
        val source = record.file
        if (!source.exists()) {
            return outcome(record, "notFound", "The file is no longer on the device", null)
        }

        val target = File(Environment.getExternalStorageDirectory(), restoreFolder)
        if (!target.exists() && !target.mkdirs()) {
            return outcome(record, "denied", "Could not create the recovery folder", null)
        }

        // Never overwrite. A thumbnail cache is full of files called 1234, and
        // silently replacing an already-recovered one loses data during an
        // operation whose entire purpose is not losing data.
        val destination = uniqueTarget(target, source.name)

        return try {
            if (source.length() > usableSpace(target)) {
                return outcome(record, "noSpace", "Not enough free space", null)
            }
            source.inputStream().use { input ->
                destination.outputStream().use { output -> input.copyTo(output) }
            }
            outcome(record, "restored", "Saved to $restoreFolder", destination.absolutePath)
        } catch (error: Throwable) {
            destination.delete()
            outcome(record, "failed", error.message ?: "Could not copy the file", null)
        }
    }

    private fun deleteMedia(record: RecoveryIndex.Record.Media): RestoreOutcome {
        val uri = ContentUris.withAppendedId(collection, record.mediaId)
        return try {
            val deleted = context.contentResolver.delete(uri, null)
            if (deleted > 0) {
                outcome(record, "restored", "Deleted permanently", null)
            } else {
                outcome(record, "expired", "Already gone", null)
            }
        } catch (error: SecurityException) {
            outcome(record, "needsConsent", "Android wants you to confirm this one", null)
        } catch (error: Throwable) {
            outcome(record, "failed", error.message ?: "Could not delete", null)
        }
    }

    private fun deleteFile(record: RecoveryIndex.Record.Loose): RestoreOutcome = try {
        if (!record.file.exists()) {
            outcome(record, "notFound", "Already gone", null)
        } else if (record.file.delete()) {
            outcome(record, "restored", "Deleted permanently", null)
        } else {
            outcome(record, "denied", "Android refused the delete", null)
        }
    } catch (error: Throwable) {
        outcome(record, "failed", error.message ?: "Could not delete", null)
    }

    private fun uniqueTarget(dir: File, name: String): File {
        var candidate = File(dir, name)
        if (!candidate.exists()) return candidate
        val stem = name.substringBeforeLast('.', name)
        val extension = name.substringAfterLast('.', "")
        var suffix = 2
        while (candidate.exists() && suffix < 1000) {
            val next = if (extension.isEmpty()) "$stem ($suffix)" else "$stem ($suffix).$extension"
            candidate = File(dir, next)
            suffix++
        }
        return candidate
    }

    private fun usableSpace(dir: File): Long = try {
        dir.usableSpace
    } catch (_: Throwable) {
        Long.MAX_VALUE
    }

    private fun outcome(
        record: RecoveryIndex.Record,
        status: String,
        detail: String,
        path: String?,
    ) = RestoreOutcome(
        itemId = record.item.itemId,
        status = status,
        detail = detail,
        restoredPath = path,
    )
}
