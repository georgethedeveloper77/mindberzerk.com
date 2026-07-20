package com.mindhunter.g_launcher.cdn

import java.io.File

/**
 * PHASE C2 - where the CDN base URL comes from.
 *
 * Order: an override file, then the compiled-in default.
 *
 * `cdn_base_url` lives in Firebase Remote Config, which is the right call and
 * stays the right call: it makes the host swappable without a Play release, so
 * a bucket migration or a Cloudflare outage is a console change rather than a
 * three-day review. But Remote Config is read by the FLUTTER side, and
 * [PackSyncWorker] runs headless with no Dart engine attached. So Dart writes
 * the resolved value here, as a plain file next to the index it configures, and
 * native reads it with no Firebase dependency of its own.
 *
 * A FILE, NOT SHARED PREFERENCES, on purpose. Reaching into the
 * `FlutterSharedPreferences` store from Kotlin works right up until the
 * shared_preferences plugin changes its backing store, and then it fails
 * silently by returning the default - which here means quietly pointing every
 * device at the wrong host and looking exactly like a CDN outage.
 *
 * THE HOST IS SWAPPABLE, THE TRUST ANCHOR IS NOT. Nothing about this file can
 * weaken verification: the keys are in `PackKeys` inside the APK, and a base
 * URL pointed at a hostile origin still cannot produce a pack that verifies.
 * That is the whole reason it is safe to make this remotely configurable.
 */
object CdnConfig {

    /** Shipped default. Also the answer when the override file is absent. */
    const val DEFAULT_BASE_URL = "https://cdn.mindberzerk.com"

    private const val OVERRIDE_NAME = "base_url"
    private const val INDEX_DIR = ".index"

    fun baseUrl(packsRoot: File): String {
        val f = File(File(packsRoot, INDEX_DIR), OVERRIDE_NAME)
        if (!f.isFile) return DEFAULT_BASE_URL
        val raw = try {
            f.readText().trim()
        } catch (_: Exception) {
            return DEFAULT_BASE_URL
        }
        // Anything not plainly https is ignored rather than honoured. CdnClient
        // would refuse it anyway; failing here means the symptom is "still using
        // the default" rather than "every fetch fails for no visible reason".
        return if (raw.startsWith("https://") && raw.length in 12..200) raw else DEFAULT_BASE_URL
    }

    /** Called from the Dart side once Remote Config has resolved. */
    fun writeOverride(packsRoot: File, url: String): Boolean = try {
        val dir = File(packsRoot, INDEX_DIR)
        dir.mkdirs()
        File(dir, OVERRIDE_NAME).writeText(url.trim())
        true
    } catch (_: Exception) {
        false
    }
}

/**
 * PHASE C2 - fires when a pack lands, so caches built from pack contents can
 * drop what they hold.
 *
 * THIS IS THE HOT-SWAP SEAM, and it is the difference between a brand pack
 * that updates and a brand pack that updates after the user force-stops the
 * launcher. `BrandIconResolver` parses `pack.json` once and `IconCache` holds
 * rendered bitmaps keyed by a fingerprint that knows nothing about pack
 * VERSIONS - so a newly installed pack with 400 more brand glyphs would keep
 * serving generated icons indefinitely, and the symptom is indistinguishable
 * from the download having failed.
 *
 * Deliberately a bare listener list and not LiveData/Flow/a broadcast: it is
 * called from a Worker thread, has one or two subscribers that live for the
 * process, and every heavier option drags a lifecycle in.
 */
object PackChangeNotifier {

    private val listeners = java.util.concurrent.CopyOnWriteArrayList<(String, String) -> Unit>()

    /** [listener] receives (packType, packId). Register once, at process start. */
    fun register(listener: (String, String) -> Unit) {
        listeners.add(listener)
    }

    /**
     * Called by the sync after a successful install. Never throws: a listener
     * that blows up must not roll back an install that already happened, and
     * this runs on a background thread where an exception is a silent process
     * death.
     */
    fun notifyInstalled(packType: String, packId: String) {
        for (l in listeners) {
            try {
                l(packType, packId)
            } catch (_: Exception) {
                // Intentionally swallowed. See above.
            }
        }
    }
}
