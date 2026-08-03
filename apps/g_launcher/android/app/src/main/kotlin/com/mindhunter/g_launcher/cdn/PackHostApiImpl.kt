package com.mindhunter.g_launcher.cdn

import android.content.Context
import android.os.Handler
import android.os.Looper
import com.mindhunter.g_launcher.pack.BundleInfo
import com.mindhunter.g_launcher.pack.PackFlutterApi
import com.mindhunter.g_launcher.pack.PackHostApi
import com.mindhunter.g_launcher.pack.PackInfo
import com.mindhunter.g_launcher.pack.PackProgress
import com.mindhunter.g_launcher.pack.PackResult
import com.mindhunter.g_launcher.theme.PackKeys
import com.mindhunter.g_launcher.theme.PackVerifier
import com.mindhunter.g_launcher.theme.ThemeAssetLoader
import java.io.File
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

/**
 * PHASE C — the storefront's native half.
 *
 * A SEPARATE HOST API FROM `LauncherHostApiImpl`, registered separately. The
 * app list and the icon engine are one concern; downloading and paying for
 * content is another, with a different thread model and a different failure
 * vocabulary. Keeping them apart also meant this could be written without
 * touching a file that already works.
 *
 * THREADING. Every method is `@async` in the schema and every body runs on
 * [io], because `installPack` makes network calls and hashes megabytes. Pigeon
 * callbacks must be invoked on the main thread, so each one hops back through
 * [main] — getting that wrong produces a crash inside Flutter's messenger that
 * points at generated code and tells you nothing about which method did it.
 *
 * ENTITLEMENT. [ownedSkus] is pushed down from Dart, where the Play Billing
 * client lives. Native holds it only to answer `unlocked` and NEVER persists
 * it: a cached entitlement on disk is a claim the device makes about itself,
 * and the point of using Play at all is that the device does not get to decide.
 * A restart starts from empty and re-asks, which fails CLOSED.
 */
private const val PREVIEW_NAME = "preview.png"

class PackHostApiImpl(
    context: Context,
    private val flutterApi: PackFlutterApi,
) : PackHostApi {

    private val appContext = context.applicationContext
    private val main = Handler(Looper.getMainLooper())

    /**
     * One thread. Downloads are serialised deliberately: two packs pulling at
     * once on a 3G connection makes both slower and makes the progress bars
     * lie, and nobody is buying two themes in the same second.
     */
    private val io = Executors.newSingleThreadExecutor()

    /**
     * THE BACKGROUND SYNC'S ONLY ROUTE INTO DART.
     *
     * `PackSyncWorker` installs packs with no UI and no Dart involvement, and
     * announced it by calling [PackChangeNotifier.notifyInstalled] and nothing
     * else. `IconCache` was listening, so a new brand pack hot-swapped
     * correctly; nothing forwarded to Flutter, so a new THEME pack did not.
     *
     * The consequence was narrow and bad. `PackFlutterApiImpl.onPackInstalled`
     * already knows how to handle this: it clears the progress entry, bumps the
     * icon generation, invalidates the catalogue, and invalidates
     * `activeThemeSpecProvider` when the pack that landed is the distro you are
     * currently wearing. Every one of those was reachable only from a
     * foreground store tap. Republish a free distro, let the daily job pick it
     * up, and the corrected pack sat verified on disk while the launcher went
     * on rendering the copy it resolved at startup, until something killed the
     * process. Which is indistinguishable from the publish having failed, and
     * "publish a fix, every device picks it up" is the entire reason the
     * pipeline exists.
     *
     * The VERSION is read back off disk rather than carried through the
     * notifier. Widening `notifyInstalled` to a third parameter would break
     * `IconCache`'s registration, and a cache that does not care about versions
     * would have gained an argument it ignores purely so this could avoid one
     * file read on a background thread.
     *
     * Held as a property so [shutdown] can unregister it: this lambda closes
     * over a Flutter messenger, and a listener list that outlives the engine it
     * posts to is a leak with a crash on the end of it.
     */
    private val onPackChange: (String, String) -> Unit = { _, packId ->
        val version = loader.installedVersion(packId).toLong()
        // Pigeon callbacks must be invoked on the main thread, same rule every
        // other callback in this file follows. This one arrives on a WorkManager
        // worker thread rather than [io], which makes the hop more necessary
        // rather than less.
        main.post { flutterApi.onPackInstalled(packId, version) {} }
    }

    init {
        // The daily schedule is enqueued from HERE, not from an Activity: this
        // object is constructed on every engine bind, the policy is KEEP so the
        // call is idempotent, and therefore the job exists on every device that
        // has ever opened the app - there is no MainActivity wiring to forget,
        // and nothing to audit when the autonomy question comes up again.
        PackSyncWorker.schedule(appContext)

        // Registered here rather than from LauncherApplication, following the
        // rule that file already states about IconCache: the object that knows
        // it must react owns its own registration, because a wiring line in the
        // Application is a line a later refactor deletes with nothing failing.
        PackChangeNotifier.register(onPackChange)
    }

    private val packsRoot: File get() = PackPaths.root(appContext)

    private val verifier by lazy {
        PackVerifier(acceptedKeys = PackKeys.accepted, appVersionCode = appVersionCode())
    }
    private val loader by lazy { ThemeAssetLoader(packsRoot, verifier) }
    private val downloader by lazy {
        PackDownloader(
            client = CdnClient(CdnConfig.baseUrl(packsRoot)),
            loader = loader,
            packsRoot = packsRoot,
            acceptedKeys = PackKeys.accepted,
            verifier = verifier,
        )
    }

    /** Not persisted. See the class doc. */
    @Volatile
    private var ownedSkus: Set<String> = emptySet()

    private companion object {
        /**
         * The one filename a theme pack must contain. Named once rather than
         * inlined: the publish route, the flat-path gate in the panel and this
         * are three places that have to agree on it, and two of them are in
         * another language and another repository.
         */
        const val THEME_FILE = "theme.json"
    }

    /** packId -> cancel flag for an in-flight download. */
    private val inFlight = ConcurrentHashMap<String, AtomicBoolean>()

    // ── catalogue ────────────────────────────────────────────────────────────

    override fun catalogue(callback: (Result<List<PackInfo>>) -> Unit) = onIo(callback) {
        val index = downloader.cachedIndex()
        val installedIds = loader.installedPackIds().toSet()

        // No index yet (first run, or every sync so far has failed). Report what
        // is on disk rather than an empty list: a storefront that renders blank
        // offline is a bug report, and the bundled packs are genuinely there.
        if (index == null) {
            return@onIo PackPaths.bundledPackIds.union(installedIds).sorted().map { id ->
                val v = loader.installedVersion(id)
                PackInfo(
                    packId = id,
                    packType = loader.installedManifest(id)?.packType ?: "unknown",
                    title = id,
                    summary = "",
                    version = v.toLong(),
                    installedVersion = v.toLong(),
                    sizeBytes = 0L,
                    state = if (id in PackPaths.bundledPackIds) "bundled" else "installed",
                    unlocked = true,
                    sku = null,
                )
            }
        }

        index.packs.map { p ->
            val installed = loader.installedVersion(p.packId)
            PackInfo(
                packId = p.packId,
                packType = p.packType,
                title = p.title,
                summary = p.summary,
                version = p.version.toLong(),
                installedVersion = installed.toLong(),
                sizeBytes = p.sizeBytes,
                state = stateOf(p.packId, p.minAppVersion, p.version, installed),
                unlocked = index.isUnlocked(p.packId, ownedSkus),
                sku = p.sku,
            )
        }
    }

    /**
     * The order matters. `requiresAppUpdate` is checked FIRST, before anything
     * about what is installed, because a pack this build cannot run must never
     * present as available or updatable — the only useful action is updating
     * the app, and a Get button there fails in a way the user cannot diagnose.
     */
    private fun stateOf(packId: String, minApp: Int, remote: Int, installed: Int): String = when {
        minApp > verifier.appVersionCode -> "requiresAppUpdate"
        // A bundled pack with nothing installed used to report "bundled" here,
        // which reads as "nothing to do" and hid the one action that matters:
        // this function is only ever called for packs the INDEX advertises, so
        // reaching this line means a CDN copy exists that the device does not
        // hold, and that is an update by definition. The APK seed carries no
        // version number to compare against, so the first pull may re-fetch
        // content the seed already equals; after it, versions track normally.
        installed == 0 && packId in PackPaths.bundledPackIds -> "updateAvailable"
        installed == 0 -> "available"
        remote > installed -> "updateAvailable"
        else -> "installed"
    }

    override fun bundles(callback: (Result<List<BundleInfo>>) -> Unit) = onIo(callback) {
        val index = downloader.cachedIndex() ?: return@onIo emptyList()
        index.entitlements.map { e ->
            val all = com.mindhunter.g_launcher.cdn.CdnIndex.WILDCARD in e.grants
            BundleInfo(
                sku = e.sku,
                title = e.title,
                summary = e.summary,
                grantsAll = all,
                // Empty when it grants everything. Expanding the wildcard here
                // would hand the UI a snapshot that goes stale the moment a new
                // pack ships, and the UI would then draw a "contains 6 packs"
                // label that is quietly wrong forever.
                grantedPackIds = if (all) emptyList() else e.grants.toList(),
                owned = e.sku in ownedSkus,
            )
        }
    }

    override fun refreshCatalogue(callback: (Result<Boolean>) -> Unit) = onIo(callback) {
        when (downloader.refreshIndex()) {
            is IndexResult.Updated -> {
                // The user is looking at the store when this fires, so a new
                // catalogue also triggers an immediate background pass over
                // installed and bundled packs rather than waiting for the
                // daily window. This is the line that makes publishing feel
                // autonomous: index refresh finds the update, the worker
                // installs it, the engine hot-swaps it.
                PackSyncWorker.syncNow(appContext)
                true
            }
            // Unchanged, Stale, Failed and Rejected all mean "the catalogue you
            // already have is the one to show". Only Updated is worth a re-read.
            else -> false
        }
    }

    // ── install ──────────────────────────────────────────────────────────────

    override fun installPack(packId: String, callback: (Result<PackResult>) -> Unit) =
        onIo(callback) {
            val index = downloader.cachedIndex()
                ?: return@onIo result(packId, "failed", "no catalogue; refresh first")

            // RE-CHECKED HERE, immediately before the transfer. The UI already
            // knows the answer, but its copy can be minutes old, and a wrongly
            // permitted download is a refund conversation while a redundant
            // check is a microsecond.
            if (!index.isUnlocked(packId, ownedSkus)) {
                return@onIo result(packId, "notEntitled", "not owned")
            }

            val cancel = AtomicBoolean(false)
            // putIfAbsent, not put: a double-tap on Get must not start a second
            // download that races the first into the same staging directory.
            if (inFlight.putIfAbsent(packId, cancel) != null) {
                return@onIo result(packId, "failed", "already downloading")
            }

            try {
                val sync = downloader.syncPack(packId, index, cancel) { done, total ->
                    postProgress(packId, done, total)
                }

                when (sync) {
                    is SyncResult.Installed -> {
                        // The hot-swap. Without this the pack sits on disk,
                        // verified, doing nothing until the process restarts,
                        // and that looks identical to the download failing.
                        //
                        // ONE ANNOUNCEMENT, not two. This used to post
                        // `onPackInstalled` to Dart directly on the line below,
                        // which was the only reason a foreground install
                        // reached Flutter at all. Now that [onPackChange]
                        // bridges the notifier, keeping the direct post would
                        // fire every Dart-side consequence twice: two catalogue
                        // invalidations, two icon-generation bumps, and two
                        // rebuilds of the active theme, the last of which is a
                        // visible hitch on the home screen.
                        PackChangeNotifier.notifyInstalled(sync.manifest.packType, packId)
                        result(packId, "installed", "", sync.manifest.version)
                    }
                    is SyncResult.UpToDate -> result(packId, "upToDate", "", sync.version)
                    is SyncResult.NotOffered -> result(packId, "notOffered", "not in the catalogue")
                    is SyncResult.AppTooOld ->
                        result(packId, "appTooOld", "needs app version ${sync.required}")
                    is SyncResult.NoSpace ->
                        result(packId, "noSpace", "needs ${sync.needed} bytes, ${sync.usable} free")
                    SyncResult.Cancelled -> result(packId, "cancelled", "")
                    is SyncResult.Rejected ->
                        result(packId, "rejected", sync.reason.toString())
                    is SyncResult.Failed -> result(packId, "failed", sync.detail)
                }
            } finally {
                inFlight.remove(packId)
            }
        }

    override fun cancelInstall(packId: String, callback: (Result<Unit>) -> Unit) {
        // NOT on [io]. That executor is single-threaded and currently occupied
        // by the very download this is meant to interrupt, so queueing the
        // cancel behind it would deliver it after the thing it cancels has
        // finished. Setting a flag is cheap and thread-safe.
        inFlight[packId]?.set(true)
        callback(Result.success(Unit))
    }

    override fun uninstallPack(packId: String, callback: (Result<Boolean>) -> Unit) =
        onIo(callback) {
            // Refusing to remove a bundled pack is not a permission check, it is
            // arithmetic: the bundled copy lives in the APK and cannot be
            // deleted, so removing the downloaded one reverts to the seed set
            // rather than removing anything. That is a legitimate action, so it
            // is allowed; the caller decides whether to offer it.
            loader.uninstall(packId)
        }

    // ── from Dart ────────────────────────────────────────────────────────────

    override fun setOwnedSkus(skus: List<String>, callback: (Result<Unit>) -> Unit) {
        ownedSkus = skus.toSet()
        callback(Result.success(Unit))
    }

    override fun setCdnBaseUrl(url: String, callback: (Result<Unit>) -> Unit) = onIo(callback) {
        packsRoot.mkdirs()
        CdnConfig.writeOverride(packsRoot, url)
        Unit
    }

    // ── the render bridge ────────────────────────────────────────────────────
    //
    // Everything above this line gets content ONTO the device. These two read it
    // back, and without them the entire pipeline was a no-op from the user's
    // side: `activeThemeSpecProvider` in Dart only ever knew how to open a
    // BUNDLED asset, so a theme pack could be authored, signed, uploaded,
    // downloaded, verified and installed, and the phone would still render
    // Ubuntu. Nothing reported it, because nothing was wrong; Dart simply never
    // asked what was on disk.

    /**
     * The raw `theme.json` of an installed theme pack, or null.
     *
     * TEXT, NOT A PARSED OBJECT. `ThemeSpec.fromJson` already exists in Dart and
     * is the contract; a second parser here would be a second thing to keep in
     * step with the schema, which is exactly how `IconRenderer.IconStyle` ended
     * up a hand-written twin of the Pigeon one. Every field this returns is one
     * Dart already knows how to read, including fields added after this build
     * shipped.
     *
     * NOT RE-VERIFIED, deliberately. `ThemeAssetLoader` checks the signature
     * once, at install, and only writes into the packs root after it passes.
     * Re-verifying here would put an ed25519 check on the home screen's resolve
     * path on every theme switch, for a file in app-private storage that nothing
     * else can write, buying no additional guarantee.
     *
     * Null covers every failure without distinguishing them, and that is right:
     * not installed, uninstalled since, files swept, unreadable. Dart falls back
     * to bundled Ubuntu in all four cases, which is the launcher's absolute rule
     * that it must always render.
     */
    override fun readInstalledTheme(themeId: String, callback: (Result<String?>) -> Unit) =
        onIo(callback) {
            // If ThemeAssetLoader ever grows a theme-reading accessor, delegate
            // to it rather than keeping this. PackPaths is the documented single
            // owner of on-disk layout, so going through it is correct today.
            PackPaths.installedFile(appContext, themeId, THEME_FILE)
                ?.let { runCatching { it.readText() }.getOrNull() }
        }

    /**
     * Where an installed pack's files are, or null.
     *
     * A theme's wallpapers and logo are FILES once downloaded, and Dart cannot
     * open them without this. Pack contents are flat BARE FILENAMES by
     * construction (see [PackPaths.installedFile], which refuses separators), so
     * Dart joins with one slash and can never produce a traversal from a
     * theme.json path.
     *
     * ON [io] rather than answered inline, even though it is one `isDirectory`.
     * That call is a stat, this executor is where every other disk touch in this
     * class lives, and a "cheap" main-thread stat on a cold filesystem is the
     * kind of thing that shows up as jank on a Tecno and nowhere else.
     */
    override fun installedPackDir(packId: String, callback: (Result<String?>) -> Unit) =
        onIo(callback) {
            PackPaths.installedDir(appContext, packId)?.absolutePath
        }

    override fun packPreviewUrl(packId: String, callback: (Result<String?>) -> Unit) =
        onIo(callback) {
            // Installed wins: local file, works offline, and it is the version
            // the device is actually holding rather than whatever the CDN has.
            val local = PackPaths.installedFile(appContext, packId, PREVIEW_NAME)
            if (local != null) {
                "file://" + local.absolutePath
            } else {
                // Not installed: the CDN copy, display-only, cached by
                // Flutter's image cache. A pack published before previews
                // existed 404s there, which the card treats as "no preview"
                // rather than as an error.
                val remote = downloader.cachedIndex()?.pack(packId)
                if (remote == null) {
                    null
                } else {
                    CdnConfig.baseUrl(packsRoot).trimEnd('/') +
                        "/g-launcher/" + remote.path + "/" + PREVIEW_NAME
                }
            }
        }

    fun shutdown() {
        // Before the executor, because the listener posts to a messenger this
        // object no longer intends to serve.
        PackChangeNotifier.unregister(onPackChange)
        io.shutdown()
    }

    // ── internals ────────────────────────────────────────────────────────────

    /**
     * Progress is THROTTLED. `CdnClient` calls back per 64KB chunk, so a 3.5MB
     * brand pack is ~55 platform-channel messages, each one a main-thread post.
     * On a Tecno that is visible jank on a screen whose only job is to animate a
     * progress bar. One message per 2% is plenty for a bar nobody measures.
     */
    private val lastPct = ConcurrentHashMap<String, Int>()

    private fun postProgress(packId: String, done: Long, total: Long) {
        if (total <= 0) return
        val pct = ((done * 100) / total).toInt()
        val prev = lastPct[packId] ?: -1
        if (pct != 100 && pct - prev < 2) return
        lastPct[packId] = pct
        main.post {
            flutterApi.onPackProgress(PackProgress(packId, done, total)) {}
        }
        if (pct == 100) lastPct.remove(packId)
    }

    private fun result(
        packId: String,
        status: String,
        detail: String,
        version: Int = 0,
    ) = PackResult(
        packId = packId,
        status = status,
        detail = detail,
        installedVersion = version.toLong(),
    )

    /**
     * Run on [io], deliver on main, and never let an exception escape into the
     * Pigeon machinery — an uncaught throw there surfaces in Dart as a
     * PlatformException with a stack trace pointing at generated code, which
     * tells you nothing about which call failed or why.
     */
    private fun <T> onIo(callback: (Result<T>) -> Unit, body: () -> T) {
        io.execute {
            val r = try {
                Result.success(body())
            } catch (e: Throwable) {
                Result.failure<T>(e)
            }
            main.post { callback(r) }
        }
    }

    private fun appVersionCode(): Int = try {
        val info = appContext.packageManager.getPackageInfo(appContext.packageName, 0)
        @Suppress("DEPRECATION")
        info.versionCode
    } catch (_: Exception) {
        0
    }
}
