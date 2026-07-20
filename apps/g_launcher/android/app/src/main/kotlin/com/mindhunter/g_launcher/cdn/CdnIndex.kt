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
)
