package com.mindhunter.g_launcher.icons

import android.content.Context
import android.content.pm.LauncherApps
import android.content.pm.PackageManager
import android.graphics.Color
import android.graphics.Path
import android.os.UserManager
import android.util.JsonReader
import android.util.JsonToken
import android.util.Log
import androidx.core.graphics.PathParser
import java.io.InputStream
import java.io.InputStreamReader
import com.mindhunter.g_launcher.apps.ComponentKey
import com.mindhunter.g_launcher.cdn.PackPaths

/**
 * The HEAD of the icon pipeline: a brand glyph for the apps everyone recognises.
 *
 * Three layers feed the recipe engine, most specific first:
 *
 *   1. HeroIconResolver — hand-drawn, per distro, ~40-60 icons. Wins.
 *   2. THIS             — CC0 brand glyphs, shared across every theme, thousands.
 *   3. IconExtractor    — the generator, re-masking the app's own icon. Always
 *                         succeeds, so nothing is ever left blank.
 *
 * Hero beats brand deliberately. Hero art is drawn FOR one distro and says
 * "this is Yaru's Firefox"; a brand glyph is the same silhouette under every
 * theme and only says "this is Firefox". When a distro has bothered to draw one,
 * that is the more specific answer.
 *
 * WHY A PATH AND NOT A PICTURE. Every Simple Icon is a single `<path>` in a
 * 24x24 viewBox — not a document, not layers, one string and one brand hex. So
 * the pack ships as JSON path data and is rasterised natively at whatever size
 * is asked for. Roughly 1KB per icon against tens of KB for a PNG that is also
 * locked to one resolution, which is the difference between the full 3,449-icon
 * set being a ~3.5MB CDN file and being impossible.
 *
 * The CC0 licence covers the FILES, not the trademarks. Several major brands
 * (LinkedIn, Amazon, Microsoft, Adobe, Canva) are simply absent from the set for
 * that reason, and they are exactly the apps the hero packs need to cover.
 */

/** How a brand glyph is coloured. Parsed from a string; see the Pigeon schema. */
enum class BrandTreatment {
    /**
     * Plate in the brand's own colour, glyph in whichever of white/near-black
     * reads on it. WhatsApp stays green. Recognisable, slightly less cohesive.
     */
    BRAND_PLATE,

    /**
     * Plate in the theme's own background (flat or graded), glyph in the brand
     * hex. The whole grid reads as one set, at some cost to recognisability.
     */
    THEME_PLATE;

    companion object {
        /** Unknown or absent degrades to BRAND_PLATE rather than throwing. */
        fun parse(raw: String?): BrandTreatment = when (raw) {
            "themePlate" -> THEME_PLATE
            else -> BRAND_PLATE
        }
    }
}

/** One brand glyph: geometry in viewBox units, plus the brand's own colour. */
data class BrandGlyph(
    /**
     * One or more path-data strings, in [BrandIconResolver.viewBox] units.
     *
     * A LIST, because a line drawing is typically one `<path>` plus two or
     * three `<line>` and `<circle>` elements, each of which converts to its own
     * path at build time. Concatenating them into one string works for fills
     * and breaks for strokes: an `M` that opens a new subpath is not the same
     * as a fresh path once round caps are involved, so the joins between
     * unrelated strokes would be drawn as if they were one continuous stroke.
     *
     * A Simple Icons glyph is a list of one, so nothing about the filled path
     * changes.
     */
    val paths: List<String>,

    /**
     * ARGB, or null when the pack publishes no colour of its own.
     *
     * Simple Icons ships a brand colour per glyph. A line set has none: the
     * whole point is that the DISTRO supplies the colour, so the renderer falls
     * back to the theme rather than inventing a grey.
     */
    val color: Int?,
)

class BrandIconResolver(context: Context) {

    private companion object {
        /** Same shape as AppRepository's `GLauncherApps`, so one grep finds both. */
        const val TAG = "GLauncherIcons"
    }

    private val appContext = context.applicationContext

    private data class Pack(
        val id: String,
        val viewBox: Float,
        /** True when the glyphs are outlines rather than solid shapes. */
        val stroked: Boolean,
        /** Stroke weight in viewBox units. Meaningless unless [stroked]. */
        val strokeWidth: Float,
        val glyphs: Map<String, BrandGlyph>,
    )

    private var loadedId: String? = null
    private var pack: Pack? = null

    /** The pack's coordinate space, 24 for Simple Icons, 48 for a line set. */
    val viewBox: Float get() = pack?.viewBox ?: 24f

    /** True when the loaded pack draws outlines rather than solid shapes. */
    val stroked: Boolean get() = pack?.stroked ?: false

    /** Stroke weight in viewBox units. Only meaningful when [stroked]. */
    val strokeWidth: Float get() = pack?.strokeWidth ?: 1f

    /** Cheap and idempotent — safe to call on every theme switch. */
    @Synchronized
    fun load(packId: String?) {
        if (packId == loadedId) return
        loadedId = packId
        pack = packId?.let { runCatching { readPack(it) }.getOrNull() }
        report(packId)
    }

    /**
     * ─── THE ONE LINE THAT MAKES THIS TIER DEBUGGABLE ─────────────────────────
     *
     * Every failure in this class is a null, and every null degrades to the
     * generator, which always succeeds. So a pack that is downloaded, verified,
     * installed, named by the theme and completely broken looks EXACTLY like a
     * pack that was never published: correct icons, generated ones, no error
     * anywhere. That cost a full session to diagnose from the outside, using
     * `ls` on the packs directory and byte offsets inside a 10 MB json.
     *
     * One line at load time collapses that to one `adb logcat`. It fires on a
     * theme switch and a pack install, not on the icon path, so it costs
     * nothing per icon.
     *
     * WARN rather than INFO for the failure, because a named pack that resolves
     * to nothing is always a bug: either the file is absent, or its `icons` map
     * intersected with this device to nothing, or the builder wrote `glyphs`
     * before `icons` and the streaming parser skipped every body.
     */
    private fun report(packId: String?) {
        if (packId == null) return
        val p = pack
        if (p == null) {
            Log.w(
                TAG,
                "pack '$packId' resolved to NOTHING. Every app falls to the " +
                    "generator. Check that pack.json exists, that its `icons` " +
                    "key precedes `glyphs`, and that the packages it names " +
                    "overlap this device.",
            )
        } else {
            Log.i(
                TAG,
                "pack '$packId' loaded: ${p.glyphs.size} glyphs for installed " +
                    "apps, viewBox ${p.viewBox}, stroked ${p.stroked}",
            )
        }
    }

    /**
     * Re-read the pack from disk EVEN IF the id has not changed.
     *
     * PHASE C2, and the reason it exists is the whole point of the CDN work.
     * When the downloader installs a newer `simple-icons`, the id is identical —
     * that is what an update means — so [load] takes its early return and this
     * resolver keeps serving the 39 glyphs it parsed at process start. The pack
     * with 3,449 of them sits on disk, fully verified, doing nothing until the
     * user force-stops the launcher.
     *
     * That failure is invisible: it looks exactly like the download not having
     * happened. Called from IconCache.onPackChanged.
     */
    @Synchronized
    fun reload() {
        val id = loadedId ?: return
        pack = runCatching { readPack(id) }.getOrNull()
        report(id)
    }

    /**
     * The brand glyph for this component, or null to fall through.
     *
     * Package name only. Unlike hero packs there is no componentKey tier: a
     * brand glyph identifies the BRAND, and every launchable activity in a
     * package belongs to the same brand.
     */
    @Synchronized
    fun resolve(componentKey: String): BrandGlyph? {
        val p = pack ?: return null
        val key = ComponentKey.parse(componentKey) ?: return null
        return p.glyphs[key.packageName]
    }

    /**
     * Every package the loaded pack has a drawing for.
     *
     * ─── FREE, BECAUSE THE FILTERING ALREADY HAPPENED ───────────────────────
     *
     * `readPack` intersects the pack's `icons` map with what is installed
     * before it materialises a single glyph body, which is the whole reason a
     * 26 MB line set does not sit resident. So the map this returns is ALREADY
     * "drawings that match an app on this phone", and counting it is a
     * `Map.keys`, not a second pass over the file.
     *
     * The caller intersects again with the LAUNCHABLE list. That is not
     * redundant: `installedPackages()` above asks PackageManager and includes
     * packages with no launcher activity, so the raw size of this set can
     * exceed the number of apps a person can actually see. A numerator larger
     * than its denominator is the kind of number that destroys trust in every
     * other number on the screen.
     *
     * Empty when no pack is loaded, which is indistinguishable from a pack that
     * covers nothing. The caller has the pack id and knows which it asked for,
     * so it reports null rather than zero.
     */
    @Synchronized
    fun coveredPackages(): Set<String> = pack?.glyphs?.keys?.toSet() ?: emptySet()

    /**
     * Parses path data into a Path in viewBox units. The renderer scales it.
     *
     * THE ONLY PLACE PATH DATA IS PARSED, on purpose. `androidx.core.graphics`
     * is the convenient answer but its parser has moved in and out of restricted
     * API over the years. If it is unavailable in the core version this build
     * resolves, vendoring AOSP's parser (Apache-2.0) is a drop-in replacement
     * and this is the single line that has to change.
     *
     * Returns null on malformed data rather than throwing: a bad glyph from a
     * CDN pack must degrade to the generator, not take out the drawer.
     */
    fun parsePaths(glyph: BrandGlyph): List<Path> =
        glyph.paths.mapNotNull { d ->
            runCatching { PathParser.createPathFromPathData(d) }.getOrNull()
        }

    // ---- pack loading ----------------------------------------------------

    /**
     * pack.json, both shapes.
     *
     * Simple Icons, inline and coloured:
     *   { "id":"simple-icons", "viewBox":24,
     *     "icons": { "com.whatsapp": { "d":"M17.4…", "hex":"25D366" } } }
     *
     * A line set, indirected and uncoloured:
     *   { "id":"arcticons-line", "viewBox":48, "style":"stroke", "strokeWidth":1,
     *     "icons":  { "com.whatsapp": "whatsapp" },
     *     "glyphs": { "whatsapp": ["M24,2.5…", "M9,17…"] } }
     *
     * ─── WHY THIS STREAMS INSTEAD OF USING JSONObject ───────────────────────
     *
     * `JSONObject(String(raw))` was fine for 3,449 Simple Icons glyphs. A full
     * line set is 32,951 package entries over 13,623 drawings, roughly 26 MB.
     * That call allocates the whole file as a String, then the whole tree as
     * objects, and on a 2 GB Tecno it is an OOM rather than a slow load.
     *
     * ─── AND WHY IT FILTERS TO INSTALLED PACKAGES ───────────────────────────
     *
     * Even parsed lazily, keeping 13,623 drawings resident is roughly 24 MB of
     * strings for art belonging to apps this phone does not have. A device runs
     * a couple of hundred apps, so the intersection is a couple of hundred
     * drawings, about 450 KB.
     *
     * This is why `icons` precedes `glyphs` in the file. The map is read first,
     * intersected with what is installed, and every glyph body outside that set
     * is skipped with `skipValue()` without ever being materialised. Reversing
     * the two keys in the builder would silently force the whole pack resident,
     * which is the kind of change that looks like formatting.
     *
     * A newly installed app has no glyph until the next reload, and
     * `IconCache.onPackChanged` plus the app-change watcher already trigger
     * one. The failure mode meanwhile is a fall-through to the generator, which
     * is the same thing an uncovered app gets.
     */
    private fun readPack(packId: String): Pack? = readPack(packId, emptySet())

    /**
     * ─── A DERIVED PACK IS A COLOUR AND A POINTER ─────────────────────────────
     *
     * The fourteen official packs are about 200 bytes each:
     *
     *     { "id": "ubuntu-24-04-line", "name": "Ubuntu Icons",
     *       "extends": "arcticons-line", "tint": "#e95420" }
     *
     * No `icons`, no `glyphs`. All fourteen point at one pack holding the 13,622
     * drawings they share, which is the difference between 10.58 MB and 148 MB.
     *
     * Without this, reading such a pack found no `icons` key, returned null, and
     * every app fell through to the generator. On a device that looks exactly
     * like the pack never installed: it downloads, verifies, resolves, and
     * changes nothing.
     *
     * [chain] breaks cycles. A malformed pair extending each other would
     * otherwise recurse until the stack goes, and this runs on the icon path
     * where that is a crash rather than a log line.
     */
    private fun readPack(packId: String, chain: Set<String>): Pack? {
        val stream = openPackStream(packId, "pack.json") ?: return null

        val installed = installedPackages()

        var viewBox = 24f
        var stroked = false
        var strokeWidth = 1f
        var extendsId: String? = null
        var tint: Int? = null
        // packageName -> slug, for the indirected shape. Empty for Simple Icons.
        val bySlug = mutableMapOf<String, MutableList<String>>()
        val inline = mutableMapOf<String, BrandGlyph>()
        val glyphs = mutableMapOf<String, BrandGlyph>()

        stream.use { raw ->
            JsonReader(InputStreamReader(raw, Charsets.UTF_8)).use { reader ->
                reader.beginObject()
                while (reader.hasNext()) {
                    when (reader.nextName()) {
                        "viewBox" -> viewBox = reader.nextDouble().toFloat()
                        "extends" -> extendsId = reader.nextString().ifEmpty { null }
                        "tint" -> tint = runCatching {
                            Color.parseColor(reader.nextString())
                        }.getOrNull()
                        "style" -> stroked = reader.nextString() == "stroke"
                        "strokeWidth" -> strokeWidth = reader.nextDouble().toFloat()

                        "icons" -> {
                            reader.beginObject()
                            while (reader.hasNext()) {
                                val pkg = reader.nextName()
                                if (pkg !in installed) {
                                    reader.skipValue()
                                    continue
                                }
                                when (reader.peek()) {
                                    // A slug reference into `glyphs` below.
                                    JsonToken.STRING ->
                                        bySlug.getOrPut(reader.nextString()) { mutableListOf() }.add(pkg)
                                    // Simple Icons, inline.
                                    JsonToken.BEGIN_OBJECT -> readInlineGlyph(reader)?.let { inline[pkg] = it }
                                    else -> reader.skipValue()
                                }
                            }
                            reader.endObject()
                        }

                        "glyphs" -> {
                            reader.beginObject()
                            while (reader.hasNext()) {
                                val slug = reader.nextName()
                                val wantedBy = bySlug[slug]
                                if (wantedBy == null) {
                                    // The 13,000-odd drawings this phone has no
                                    // app for. Skipped without allocating.
                                    reader.skipValue()
                                    continue
                                }
                                val paths = readPathArray(reader)
                                if (paths.isNotEmpty()) {
                                    val glyph = BrandGlyph(paths = paths, color = null)
                                    for (pkg in wantedBy) glyphs[pkg] = glyph
                                }
                            }
                            reader.endObject()
                        }

                        else -> reader.skipValue()
                    }
                }
                reader.endObject()
            }
        }

        // ─── FOLLOW THE POINTER ──────────────────────────────────────────────
        //
        // Checked AFTER the stream closes, not before, because `extends` can sit
        // anywhere in the file and streaming means not knowing until the end.
        // The cost is one wasted pass over 200 bytes.
        val base = extendsId
        if (base != null) {
            if (base == packId || base in chain) {
                // A pack extending itself, or a cycle. Refused rather than
                // recursed: the alternative is a stack overflow inside icon
                // resolution, which takes the drawer down rather than one icon.
                return null
            }
            val inherited = readPack(base, chain + packId) ?: return null
            return Pack(
                id = packId,
                viewBox = inherited.viewBox,
                stroked = inherited.stroked,
                strokeWidth = inherited.strokeWidth,
                // THE COLOUR IS THE WHOLE PRODUCT. Fourteen packs share one
                // geometry and differ only here, so a null tint would make every
                // distro's pack identical and the catalogue pointless.
                //
                // Stamped onto every glyph rather than held on the Pack, because
                // `renderBrand` reads `glyph.color` and a second source for the
                // same fact is the kind of thing that diverges.
                glyphs = inherited.glyphs.mapValues { (_, g) -> g.copy(color = tint) },
            )
        }

        glyphs.putAll(inline)
        if (glyphs.isEmpty()) return null

        return Pack(
            id = packId,
            viewBox = viewBox,
            stroked = stroked,
            strokeWidth = strokeWidth,
            glyphs = glyphs,
        )
    }

    /** `{ "d": "M17.4…", "hex": "25D366" }`, the Simple Icons shape. */
    private fun readInlineGlyph(reader: JsonReader): BrandGlyph? {
        var d: String? = null
        var hex: String? = null
        reader.beginObject()
        while (reader.hasNext()) {
            when (reader.nextName()) {
                "d" -> d = reader.nextString()
                "hex" -> hex = reader.nextString()
                else -> reader.skipValue()
            }
        }
        reader.endObject()
        val path = d?.takeIf { it.isNotEmpty() } ?: return null
        // Hex is stored without the leading '#', the way the upstream dataset
        // publishes it. Missing or unparseable falls back to a neutral grey
        // rather than dropping an otherwise good glyph.
        val color = hex?.let { runCatching { Color.parseColor("#$it") }.getOrNull() }
            ?: 0xFF6E6E6E.toInt()
        return BrandGlyph(paths = listOf(path), color = color)
    }

    /**
     * `["M…", "M…"]`, or a bare `"M…"`.
     *
     * The single-string form is accepted because a pack written by hand, or by
     * an older builder, is otherwise silently dropped: `beginArray` on a string
     * throws, the surrounding `runCatching` swallows it, and the whole pack
     * fails to load with no way to tell that from a missing file.
     */
    private fun readPathArray(reader: JsonReader): List<String> {
        if (reader.peek() == JsonToken.STRING) return listOf(reader.nextString())
        if (reader.peek() != JsonToken.BEGIN_ARRAY) {
            reader.skipValue()
            return emptyList()
        }
        val out = mutableListOf<String>()
        reader.beginArray()
        while (reader.hasNext()) {
            if (reader.peek() == JsonToken.STRING) out.add(reader.nextString()) else reader.skipValue()
        }
        reader.endArray()
        return out
    }

    /**
     * Every package this device has, for filtering the pack down to what is
     * worth keeping resident.
     *
     * ─── LauncherApps FIRST, AND THAT IS THE CORRECTNESS OF IT ───────────────
     *
     * This asked `PackageManager.getInstalledApplications` alone, and on
     * Android 11+ that is FILTERED BY PACKAGE VISIBILITY. This app deliberately
     * does not hold `QUERY_ALL_PACKAGES`, so what came back was whatever the
     * scoped `<queries>` block happens to name, plus this package itself.
     *
     * Follow that through `readPack` and the result is not a smaller icon set,
     * it is NO icon set: every entry under `icons` fails `pkg !in installed`,
     * `bySlug` ends empty, all 13,622 glyph bodies are skipped by the branch
     * below, the base pack finishes with an empty map and returns null, and the
     * derived pack that points at it returns null too. Ten megabytes of
     * verified geometry sits on disk drawing nothing, which on a device is
     * indistinguishable from the pack never having installed.
     *
     * Holding the home role does not exempt PackageManager. `LauncherApps`
     * IS exempt, needs no permission, and is already the source `AppRepository`
     * builds the drawer from. So the pack is now filtered against the same list
     * the user is looking at, which is also the only list whose coverage they
     * are in a position to judge.
     *
     * PackageManager is still asked, and its answer UNIONED rather than
     * replaced: a package with no launcher activity is invisible to
     * LauncherApps and may still be worth a drawing, since `resolve` is keyed
     * by package name and something other than the drawer can ask. Whatever it
     * returns is a bonus on top of a set that is correct without it.
     *
     * Both are wrapped. A launcher that cannot enumerate apps has larger
     * problems than icons, and throwing here would take the drawer down rather
     * than degrade one tier of it.
     */
    private fun installedPackages(): Set<String> {
        val out = HashSet<String>()

        runCatching {
            val launcherApps =
                appContext.getSystemService(Context.LAUNCHER_APPS_SERVICE) as LauncherApps
            val userManager =
                appContext.getSystemService(Context.USER_SERVICE) as UserManager
            // Every profile, so a work-profile app gets its glyph too. Null as
            // the package name asks for every launchable activity.
            for (user in userManager.userProfiles) {
                launcherApps.getActivityList(null, user)
                    .mapTo(out) { it.componentName.packageName }
            }
        }

        runCatching {
            // MATCH_UNINSTALLED_PACKAGES rather than the default: a pack should
            // still cover an app the user has disabled, because re-enabling it
            // must not need a pack reload to get its icon back.
            appContext.packageManager
                .getInstalledApplications(PackageManager.MATCH_UNINSTALLED_PACKAGES)
                .mapTo(out) { it.packageName }
        }

        return out
    }

    /**
     * CDN-downloaded packs win over bundled ones with the same id, so the brand
     * map can grow — new apps appear constantly — without a Play release. Same
     * property the themes and hero packs have.
     */
    private fun openPackStream(packId: String, filename: String): InputStream? {
        // PHASE C2: the verified packs root, NOT filesDir/brandpacks. That old
        // directory had no writer and no verification; reading from it once a
        // downloader existed would have been a second route into the icon
        // pipeline that skips PackVerifier entirely. See PackPaths.
        PackPaths.installedFile(appContext, packId, filename)?.let { downloaded ->
            return runCatching { downloaded.inputStream() }.getOrNull()
        }

        // A STREAM rather than the ByteArray this used to return. The line pack
        // is roughly 26 MB, so reading it whole to hand to a parser defeats the
        // point of streaming: the peak allocation would be the same as the
        // `JSONObject` call this replaced.
        val assetPath = "flutter_assets/assets/brandpacks/$packId/$filename"
        return runCatching { appContext.assets.open(assetPath) }.getOrNull()
    }
}
