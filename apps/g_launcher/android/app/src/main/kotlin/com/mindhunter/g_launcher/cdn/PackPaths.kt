package com.mindhunter.g_launcher.cdn

import android.content.Context
import com.mindhunter.g_launcher.theme.PackManifest
import java.io.File

/**
 * PHASE C2 - the ONE place that knows where a verified pack lives on disk.
 *
 * IT REPLACES `filesDir/brandpacks` AND `filesDir/heropacks`, and that is a
 * correctness fix, not tidying.
 *
 * Those two directories were read paths with no writer. Nothing populated them,
 * so nothing was wrong today, but the moment C2 gave the app a downloader they
 * would have become a second way for content to reach the icon pipeline - one
 * that never passes through PackVerifier. A resolver reading
 * `filesDir/brandpacks/simple-icons/pack.json` cannot tell a verified pack from
 * a file dropped there by anything else that can write the app's data
 * directory, and "content that drives UI is code-adjacent" applies to a brand
 * glyph exactly as much as to a theme.
 *
 * So there is now exactly one installed location, `filesDir/packs/<packId>`,
 * written only by ThemeAssetLoader after a signature check. The pack TYPE
 * (theme, brand, hero, icon) is metadata inside the manifest, not a directory.
 * Flat is right here: pack ids are globally unique by construction, and a
 * per-type root would mean four staging areas, four rollback floors and four
 * chances to get one of them wrong.
 *
 * The bundled copies in `flutter_assets/assets/{brandpacks,heropacks}/…` stay
 * exactly as they are. They are inside the APK, so they carry Play's signature
 * and need none of their own. Downloaded beats bundled for the same id, which
 * is what lets the brand map grow as new apps appear without a Play release.
 */
object PackPaths {

    /** Everything verified lives under here. Created lazily by the loader. */
    fun root(context: Context): File = File(context.applicationContext.filesDir, "packs")

    /**
     * A file inside an INSTALLED pack, or null when it is not there.
     *
     * The packId is re-checked even though it comes from a verified manifest,
     * because callers pass ids from theme JSON and Remote Config too, and this
     * method joins them into a path. Cheap, and the alternative is a traversal
     * primitive sitting in the icon pipeline.
     */
    fun installedFile(context: Context, packId: String, filename: String): File? {
        if (!PackManifest.isSafePackId(packId)) return null
        if (filename.contains('/') || filename.contains('\\') || filename.contains("..")) return null
        val f = File(File(root(context), packId), filename)
        return if (f.isFile) f else null
    }

    /**
     * An INSTALLED pack's directory, or null when nothing is installed there.
     *
     * The companion to [installedFile], and it exists for the render bridge:
     * Dart needs the directory itself, not a file inside it, because a
     * downloaded theme's wallpapers and logo are FILES rather than bundled
     * assets. `AssetImage("wall.jpg")` against an installed theme resolves to
     * nothing and paints an empty box with no error, so `ThemeSource` needs a
     * real path to build a `FileImage` from.
     *
     * Same packId re-check as [installedFile] and for the same reason: this
     * joins a caller-supplied id into a path, and the caller here is a theme id
     * that arrived from Dart prefs. Handing an unchecked id to `File(root, id)`
     * would put a traversal primitive in the one object whose entire job is
     * knowing where verified content lives.
     *
     * Returns null rather than a non-existent File, so "not installed" and
     * "installed" are distinguishable without a second `isDirectory` call at
     * every call site.
     */
    fun installedDir(context: Context, packId: String): File? {
        if (!PackManifest.isSafePackId(packId)) return null
        val d = File(root(context), packId)
        return if (d.isDirectory) d else null
    }

    /**
     * Pack ids that ship inside the APK and whose CDN copy supersedes them.
     *
     * THE FIRST-UPGRADE PROBLEM THIS SOLVES: `PackSyncWorker` only updates what
     * is already installed, deliberately, so a background job can never
     * silently spend a user's storage on something they did not ask for. But a
     * BUNDLED pack is never "installed" by that definition, so `simple-icons`
     * would sit at its 39-entry seed set forever and the CDN pipeline would
     * quietly do nothing on every device.
     *
     * These ids are the exception, and it is a narrow one: the pack is already
     * on the device, already in use, and the download only makes an existing
     * feature more complete. Anything not listed here still requires a user
     * action in the storefront.
     */
    val bundledPackIds: Set<String> = setOf("simple-icons", "yaru")
}
