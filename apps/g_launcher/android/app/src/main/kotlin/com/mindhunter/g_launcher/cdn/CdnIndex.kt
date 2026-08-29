package com.mindhunter.g_launcher.cdn

import com.mindhunter.g_launcher.crypto.Ed25519
import com.mindhunter.g_launcher.theme.PackFormatException
import com.mindhunter.g_launcher.theme.PackManifest
import org.json.JSONObject

/**
 * PHASE C2 - the signed catalogue at `<cdn_base_url>/g-launcher/index.json`.
 *
 * WHY THIS IS SIGNED TOO, when every pack is independently verified anyway.
 * The index cannot forge a pack: point it at the wrong path and the pack's own
 * signature and packId check kill it at install. What an UNSIGNED index can do
 * is LIE BY OMISSION - drop the entry for a pack that fixes something, or hold
 * its version number down, and freeze every device on the old copy forever. A
 * signature stops substitution; only a signature PLUS a monotonic
 * [generatedAt] floor stops freezing. Both are cheap here because the crypto
 * already exists.
 *
 * It is a separate shape from PackManifest rather than a "packType": "index"
 * because it describes packs, it is not one: no files, no hashes, and a
 * different set of required fields. Sharing the type would mean a pile of
 * fields that are meaningless for one of the two cases, which is how a strict
 * parser quietly becomes a lenient one.
 */
data class CdnIndex(
    val formatVersion: Int,
    /** Unix seconds. The rollback floor: a client refuses an older index. */
    val generatedAt: Long,
    val keyId: String,
    val packs: List<CdnPack>,
    /**
     * Bundles: which SKUs grant which packs. PHASE C3.
     *
     * Absent in an older index, which is why it defaults to empty rather than
     * being required. A client that only understands per-pack SKUs still works;
     * it just cannot see bundles.
     */
    val entitlements: List<EntitlementSet> = emptyList(),
) {
    fun pack(packId: String): CdnPack? = packs.firstOrNull { it.packId == packId }

    /**
     * Is [packId] unlocked, given the SKUs Play says this user owns?
     *
     * THE OWNERSHIP RULE, in one place:
     *   1. free packs (no sku) are always unlocked
     *   2. owning the pack's own sku unlocks it
     *   3. owning ANY entitlement whose grants cover it unlocks it
     *
     * Rule 3 is the load-bearing one and it is why bundle membership lives in
     * the signed index rather than in Play. Play owns the SKU IDs, which are
     * immutable and must be pre-created; what a SKU CONTAINS is content, and
     * content belongs in the admin panel. So `distro_pack_gnome` can be created
     * once holding two distros and grow to five a month later with no Play
     * change and no app release.
     *
     * `"*"` is the whole catalogue INCLUDING PACKS THAT DO NOT EXIST YET. That
     * is deliberate and it is a promise made in the store listing: buy the
     * complete collection and future packs are covered. Implementing it as
     * "every packId in today's index" would silently break that promise for
     * every buyer the first time a new pack shipped.
     *
     * [ownedSkus] must come from Play, never from the CDN and never from a
     * local "owned" flag. Entitlement is Play's record; anything cached in
     * prefs is a claim the device makes about itself.
     */
    /**
     * Does this pack come FREE with the distro currently applied?
     *
     * ─── DERIVED, NOT DECLARED ────────────────────────────────────────────────
     *
     * Every distro ships an icon pack in its own colour: `kali-2024-theme` and
     * `kali-2024-line`. Rather than an inclusion list in the index, which is a
     * second thing to keep in step with the catalogue, the relationship is read
     * off the ids: strip `-theme`, append `-line`.
     *
     * That also covers the three BUNDLED distros, `ubuntu-24-04`, `terminal`
     * and `kde-plasma-6`, whose ids carry no `-theme` suffix and which have no
     * entitlement at all because they are free.
     */
    fun isIncludedWith(packId: String, activeThemeId: String?): Boolean {
        val theme = activeThemeId ?: return false
        val base = theme.removeSuffix("-theme")
        return packId == "$base-line"
    }

    /**
     * May this device install it: OWNED or INCLUDED.
     *
     * Two different facts from two different owners. Play answers the first;
     * the applied theme answers the second. Keeping them in one function that
     * takes both is what stops them drifting apart, which is how a pack ends up
     * given away by one path and charged for twice by another.
     */
    fun isAvailable(packId: String, ownedSkus: Set<String>, activeThemeId: String?): Boolean =
        isUnlocked(packId, ownedSkus) || isIncludedWith(packId, activeThemeId)

    fun isUnlocked(packId: String, ownedSkus: Set<String>): Boolean {
        val pack = pack(packId) ?: return false
        if (pack.sku == null) return true
        if (pack.sku in ownedSkus) return true
        return entitlements.any { it.sku in ownedSkus && it.covers(packId) }
    }

    /** Every SKU that would unlock [packId]. For "how do I get this?" in the UI. */
    fun offersFor(packId: String): List<String> {
        val pack = pack(packId) ?: return emptyList()
        val own = pack.sku ?: return emptyList()
        return listOf(own) + entitlements.filter { it.covers(packId) }.map { it.sku }
    }

    companion object {
        const val SUPPORTED_FORMAT_VERSION: Int = 1

        /** Hard cap on the index document. Generous; the full catalogue is tiny. */
        const val MAX_INDEX_BYTES: Int = 1024 * 1024

        const val INDEX_NAME = "index.json"
        const val SIGNATURE_NAME = "index.sig"

        /** Grants every pack, present and future. See [CdnIndex.isUnlocked]. */
        const val WILDCARD = "*"

        /**
         * Play's own rule for product IDs: lowercase alphanumeric plus
         * underscore, starting with a letter or number. Enforced here so a
         * malformed id fails at publish time in the admin panel rather than
         * silently never matching anything Play reports as owned - a failure
         * that looks exactly like the user not having bought it.
         */
        fun isSafeSku(sku: String): Boolean {
            if (sku.isEmpty() || sku.length > 64) return false
            if (!(sku[0] in 'a'..'z' || sku[0] in '0'..'9')) return false
            return sku.all { it in 'a'..'z' || it in '0'..'9' || it == '_' }
        }

        /**
         * Parse and verify in one step, because there is no legitimate reason to
         * hold an unverified index: separating them just creates a variable that
         * some later caller reads before the check.
         *
         * Returns null on ANY failure. The caller keeps whatever index it had,
         * which is always a survivable outcome - the worst case is the user does
         * not see a new theme until the next sync.
         */
        fun parseVerified(
            bytes: ByteArray,
            signature: ByteArray,
            acceptedKeys: Map<String, ByteArray>,
        ): CdnIndex? {
            if (bytes.size > MAX_INDEX_BYTES) return null
            if (signature.size != Ed25519.SIGNATURE_BYTES) return null

            val text = try {
                String(bytes, Charsets.UTF_8)
            } catch (_: Exception) {
                return null
            }

            // Same order as PackVerifier: the keyId is read before the check,
            // but only to pick which trusted key to try. Naming a key grants
            // nothing.
            val keyId = try {
                JSONObject(text).optString("keyId", "")
            } catch (_: Exception) {
                return null
            }
            if (keyId.isEmpty()) return null

            val publicKey = acceptedKeys[keyId] ?: return null
            if (!Ed25519.verify(publicKey, bytes, signature)) return null

            return try {
                parseTrusted(text)
            } catch (_: PackFormatException) {
                null
            }
        }

        /** Only for bytes whose signature has already been checked. */
        fun parseTrusted(text: String): CdnIndex {
            val root = try {
                JSONObject(text)
            } catch (e: Exception) {
                throw PackFormatException("index is not valid JSON: ${e.message}")
            }

            val formatVersion = root.optInt("formatVersion", -1)
            if (formatVersion != SUPPORTED_FORMAT_VERSION) {
                throw PackFormatException("unsupported index formatVersion $formatVersion")
            }

            val generatedAt = root.optLong("generatedAt", -1L)
            if (generatedAt <= 0L) throw PackFormatException("missing or bad 'generatedAt'")

            val keyId = root.optString("keyId", "")
            if (keyId.isEmpty()) throw PackFormatException("missing 'keyId'")

            val array = root.optJSONArray("packs")
                ?: throw PackFormatException("missing 'packs'")

            val packs = ArrayList<CdnPack>(array.length())
            val seen = HashSet<String>()
            for (i in 0 until array.length()) {
                val o = array.optJSONObject(i) ?: throw PackFormatException("packs[$i] is not an object")

                val packId = o.optString("packId", "")
                if (!PackManifest.isSafePackId(packId)) {
                    throw PackFormatException("unsafe packId '$packId' in packs[$i]")
                }
                if (!seen.add(packId)) throw PackFormatException("duplicate packId '$packId'")

                val packType = o.optString("packType", "")
                if (packType !in PackManifest.KNOWN_PACK_TYPES) {
                    throw PackFormatException("unknown packType '$packType' for '$packId'")
                }

                // The remote directory, relative to the launcher root. Held to
                // the same standard as a path inside a pack: it is concatenated
                // into a URL, and a '..' here would walk out of our prefix on
                // the bucket and fetch someone else's objects.
                val path = o.optString("path", "")
                if (!PackManifest.isSafeRelativePath(path)) {
                    throw PackFormatException("unsafe path '$path' for '$packId'")
                }

                val version = o.optInt("version", -1)
                if (version < 1) throw PackFormatException("bad version for '$packId'")

                val minAppVersion = o.optInt("minAppVersion", -1)
                if (minAppVersion < 0) throw PackFormatException("bad minAppVersion for '$packId'")

                val sizeBytes = o.optLong("sizeBytes", -1L)
                if (sizeBytes < 0L) throw PackFormatException("bad sizeBytes for '$packId'")

                packs.add(
                    CdnPack(
                        packId = packId,
                        packType = packType,
                        path = path,
                        version = version,
                        minAppVersion = minAppVersion,
                        sizeBytes = sizeBytes,
                        // Presentation only, and deliberately optional: a pack
                        // must stay installable by a client that predates
                        // whatever field the storefront wants next.
                        title = o.optString("title", packId),
                        summary = o.optString("summary", ""),
                        // null = free. The Play SKU that unlocks it, checked in
                        // C3. Advisory: it lives here so the storefront can draw
                        // a price, NOT so the client can decide entitlement.
                        // Entitlement is Play's answer, never the CDN's.
                        sku = o.optString("sku", "").ifEmpty { null },
                        // The preview block, if this entry carries one. Read
                        // through the same optString-then-ifEmpty pattern as
                        // `sku`, so a missing block and an empty one are the
                        // same thing: absent.
                        previewShell = previewStr(o, "shell"),
                        previewBgTop = previewStr(o, "bgTop"),
                        previewBgBottom = previewStr(o, "bgBottom"),
                        previewBar = previewStr(o, "bar"),
                        previewDock = previewStr(o, "dock"),
                        previewAccent = previewStr(o, "accent"),
                        // Same optString-then-ifEmpty shape as `sku`: a missing
                        // field and an empty string mean the same thing.
                        tint = o.optString("tint", "").ifEmpty { null },
                        // Inside the `preview` object, beside `shell`, not at
                        // the top level: it describes the picture, and the six
                        // colours it sits with are the rest of that picture.
                        previewLayout = previewStr(o, "layout"),
                        requires = stringList(o.optJSONArray("requires")),
                        features = featureList(o.optJSONArray("features")),
                        // The contents block, read the same way as `preview`:
                        // nested here, flat across the bridge, and absent
                        // wherever the publisher has not counted yet.
                        wallpaperCount = contentsInt(o, "wallpapers"),
                        iconPackTitle = contentsStr(o, "iconPack"),
                        fontName = contentsStr(o, "font"),
                    ),
                )
            }

            // Optional. An index authored before C3 has no entitlements block
            // and must keep working, so absence is empty rather than an error.
            val entitlements = ArrayList<EntitlementSet>()
            val entArray = root.optJSONArray("entitlements")
            if (entArray != null) {
                val seenSkus = HashSet<String>()
                for (i in 0 until entArray.length()) {
                    val o = entArray.optJSONObject(i)
                        ?: throw PackFormatException("entitlements[$i] is not an object")

                    val sku = o.optString("sku", "")
                    if (!isSafeSku(sku)) throw PackFormatException("unsafe sku '$sku'")
                    if (!seenSkus.add(sku)) throw PackFormatException("duplicate sku '$sku'")

                    val grantsArray = o.optJSONArray("grants")
                        ?: throw PackFormatException("missing 'grants' for sku '$sku'")
                    if (grantsArray.length() == 0) {
                        throw PackFormatException("empty 'grants' for sku '$sku'")
                    }

                    val grants = LinkedHashSet<String>()
                    for (g in 0 until grantsArray.length()) {
                        val v = grantsArray.optString(g, "")
                        // A grant is either the wildcard or a real pack id. It
                        // is NOT checked against `packs`, on purpose: a bundle
                        // may name a pack that has not shipped yet, and
                        // rejecting that would make publishing order matter.
                        if (v != WILDCARD && !PackManifest.isSafePackId(v)) {
                            throw PackFormatException("unsafe grant '$v' for sku '$sku'")
                        }
                        grants.add(v)
                    }

                    entitlements.add(
                        EntitlementSet(
                            sku = sku,
                            title = o.optString("title", sku),
                            summary = o.optString("summary", ""),
                            grants = grants,
                        ),
                    )
                }
            }

            return CdnIndex(formatVersion, generatedAt, keyId, packs, entitlements)
        }
    }
}

/**
 * A purchasable bundle: one Play SKU, several packs.
 *
 * Lives in the signed index rather than in Play because Play owns the SKU ID and
 * nothing else. IDs are immutable and cannot be reused after deletion, so they
 * have to be decided up front; membership is content and changes constantly.
 * Splitting it this way means adding a distro to an existing bundle is an admin
 * panel edit and a re-signed index, with no Play change and no app release.
 *
 * Because it is inside the signed document, bundle membership is exactly as
 * tamper-proof as everything else. A hostile CDN cannot hand someone a bundle
 * they did not buy: it could claim `distro_pack_gnome` grants everything, but
 * the client still has to actually OWN that sku, and only Play can say so.
 */
data class EntitlementSet(
    /** Play product ID. Must exist in the console before anyone can buy it. */
    val sku: String,
    val title: String,
    val summary: String,
    /** Pack ids, or [CdnIndex.WILDCARD] for the whole catalogue forever. */
    val grants: Set<String>,
) {
    fun covers(packId: String): Boolean =
        CdnIndex.WILDCARD in grants || packId in grants
}

/**
 * A JSON array of strings, leniently.
 *
 * One malformed entry costs its own row, never the catalogue. An index is
 * read on a phone that cannot ask anyone for a corrected copy, so the
 * failure mode has to be "less", not "none".
 */
private fun stringList(arr: org.json.JSONArray?): List<String> {
    if (arr == null) return emptyList()
    val out = ArrayList<String>(arr.length())
    for (i in 0 until arr.length()) {
        val v = arr.optString(i, "")
        if (v.isNotEmpty()) out.add(v)
    }
    return out
}

/** Storefront rows, same leniency as [stringList]. */
/**
 * The rows an entry names, or NULL when it named no block at all.
 *
 * ─── NULLABLE, AND THE DISTINCTION IS THE WHOLE FUNCTION ────────────────────
 *
 * `null` means the entry predates the features block. An empty list means the
 * entry HAS the block and deliberately names nothing, which is what
 * `arch-linux-theme` published for weeks and what any distro with no honest
 * exclusive claim publishes.
 *
 * This returned a non-null `emptyList()` for both, and `PackHostApiImpl` then
 * mapped empty back to null, so the two collapsed into one at this step while
 * the panel, `sign.ts` and `theme_catalog` all took trouble to keep them apart.
 * Harmless only while the floor cards carried rows to fall back to; those rows
 * now live in the specs, so the fallback is gone and the honest answer is the
 * one that has to survive.
 */
private fun featureList(arr: org.json.JSONArray?): List<CdnFeature>? {
    if (arr == null) return null
    val out = ArrayList<CdnFeature>(arr.length())
    for (i in 0 until arr.length()) {
        val o = arr.optJSONObject(i) ?: continue
        val title = o.optString("title", "")
        val body = o.optString("body", "")
        if (title.isEmpty()) continue
        out.add(CdnFeature(title, body, o.optBoolean("exclusive", true)))
    }
    return out
}

/**
 * One field out of an entry's optional `preview` object.
 *
 * A nested object in the JSON, six flat fields on the far side of the bridge.
 * The nesting is right for a hand-authored theme.json, where `preview` reads as
 * one thing; flat is right for the Pigeon class, where a new nested class would
 * take a codec id and renumber every existing one.
 *
 * Returns null for a missing `preview`, a missing key, or an empty string,
 * because a card cannot draw with any of the three and they should not be three
 * different code paths.
 */
private fun previewStr(o: org.json.JSONObject, key: String): String? {
    val p = o.optJSONObject("preview") ?: return null
    return p.optString(key, "").ifEmpty { null }
}

/**
 * One string out of an entry's optional `contents` object.
 *
 * The same nested-in-JSON, flat-across-the-bridge shape [previewStr] documents,
 * and for the same two reasons: a block reads as one thing in a hand-authored
 * index, and a nested Pigeon class would take a codec id and renumber every
 * existing one.
 */
private fun contentsStr(o: org.json.JSONObject, key: String): String? {
    val c = o.optJSONObject("contents") ?: return null
    return c.optString(key, "").ifEmpty { null }
}

/**
 * The wallpaper count out of an entry's optional `contents` object.
 *
 * ─── `has` RATHER THAN `optInt` WITH A DEFAULT ──────────────────────────────
 *
 * ZERO IS AN ANSWER here and it is the reason this is not one line. Terminal
 * ships no wallpapers by design, so a published `0` means "counted, there are
 * none" while an absent key means "nobody has counted", and the card draws
 * nothing for the first and nothing for the second only because the chip would
 * read "0 wallpapers" either way. Collapsing them would still be wrong: the
 * distinction is what lets a later card say something different about the two,
 * and it costs one `has` check to keep.
 *
 * `optInt` returns 0 for a key that is absent AND for one holding a string, so
 * a default here would silently manufacture that answer.
 */
private fun contentsInt(o: org.json.JSONObject, key: String): Long? {
    val c = o.optJSONObject("contents") ?: return null
    if (!c.has(key)) return null
    val v = c.optInt(key, -1)
    // Negative means either a genuinely negative count or a value that is not a
    // number at all. Neither is publishable, and treating it as absent costs
    // one chip rather than refusing the whole index over a typo, which is the
    // rule `tint` states directly above.
    return if (v < 0) null else v.toLong()
}



/** One downloadable pack, as advertised by the index. */
data class CdnPack(
    val packId: String,
    val packType: String,
    /** Remote directory relative to the launcher root, e.g. "brandpacks/simple-icons". */
    val path: String,
    val version: Int,
    val minAppVersion: Int,
    /** Total payload size, for a free-space check and a progress bar. Advisory. */
    val sizeBytes: Long,
    val title: String,
    val summary: String,
    val sku: String?,
    /**
     * The storefront preview: which shell to draw and the six palette colours
     * to draw it in.
     *
     * ALL NULLABLE, and every one of them optional in the JSON. A pack
     * published before this block existed parses exactly as it did and the
     * card falls back to the flat rectangle it draws today, so nothing already
     * in the index has to be republished.
     *
     * Presentation only, like [title] and [summary]. Nothing here is ever
     * consulted to decide whether a pack may be installed.
     */
    val previewShell: String? = null,
    val previewBgTop: String? = null,
    val previewBgBottom: String? = null,
    val previewBar: String? = null,
    val previewDock: String? = null,
    val previewAccent: String? = null,

    /**
     * Rows the storefront card names, in AUTHORED ORDER. Empty for every pack
     * published before this existed. Presentation only.
     */
    /** Null when the entry names no `features` block. See [featureList]. */
    val features: List<CdnFeature>? = null,

    /**
     * Pack ids this one cannot work without.
     *
     * An official icon pack is about 200 bytes naming a colour and extending
     * `arcticons-line`, which carries the 13,622 drawings. This is what tells
     * the downloader to fetch that one first; without it the pointer installs,
     * verifies, and renders nothing.
     */
    val requires: List<String> = emptyList(),

    /**
     * The pack's colour, as `#rrggbb`, or null.
     *
     * The fourteen official packs share one geometry and differ in exactly
     * this, so the colour IS the product and the catalogue has to carry it. It
     * also lets the storefront preview a pack on the user's real apps WITHOUT
     * installing it: the geometry is already on the device, free and required,
     * so a preview is this hex and nothing else.
     *
     * Never validated here. A malformed colour costs one pack its preview;
     * refusing the whole index over it would take the catalogue down for a typo.
     */
    val tint: String? = null,
    val previewLayout: String? = null,

    /**
     * What the pack contains: wallpapers, icon set, typeface.
     *
     * ALL NULLABLE and all optional in the JSON, exactly like the preview
     * block. A pack published before `contents` existed parses as it always
     * did, and the card simply draws fewer chips.
     *
     * [wallpaperCount] is nullable rather than defaulted to 0 because a
     * published zero and an uncounted pack are different answers. See
     * [contentsInt].
     *
     * Presentation only. Nothing here is ever consulted to decide whether a
     * pack may be installed.
     */
    val wallpaperCount: Long? = null,
    val iconPackTitle: String? = null,
    val fontName: String? = null,
)

/** One row a storefront card can name. */
data class CdnFeature(
    val title: String,
    val body: String,
    /** The all-access settings cannot reproduce it. The price argument. */
    val exclusive: Boolean,
)
