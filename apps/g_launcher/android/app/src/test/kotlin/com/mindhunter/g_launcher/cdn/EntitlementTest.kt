package com.mindhunter.g_launcher.cdn

import com.mindhunter.g_launcher.theme.PackFormatException
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * PHASE C3 - who can open what.
 *
 * These are pure-function tests on parsed data: no network, no Play, no
 * emulator. That is possible because [CdnIndex.isUnlocked] takes the owned SKUs
 * as an argument rather than reaching for a billing client, which is also the
 * property that keeps the entitlement decision testable at all.
 */
class EntitlementTest {

    private fun index(json: String): CdnIndex = CdnIndex.parseTrusted(json)

    private val catalogue = """
        {
          "formatVersion": 1,
          "generatedAt": 1784505600,
          "keyId": "mh-2026-07",
          "packs": [
            {"packId": "ubuntu-24-04", "packType": "theme", "path": "themes/ubuntu-24-04",
             "version": 1, "minAppVersion": 6, "sizeBytes": 100},
            {"packId": "fedora-41", "packType": "theme", "path": "themes/fedora-41",
             "version": 1, "minAppVersion": 6, "sizeBytes": 100, "sku": "distro_pack_fedora"},
            {"packId": "kali-2026", "packType": "theme", "path": "themes/kali-2026",
             "version": 1, "minAppVersion": 6, "sizeBytes": 100, "sku": "distro_pack_kali"},
            {"packId": "garuda-dr460nized", "packType": "theme", "path": "themes/garuda",
             "version": 1, "minAppVersion": 6, "sizeBytes": 100, "sku": "distro_pack_garuda"}
          ],
          "entitlements": [
            {"sku": "distro_pack_gnome", "title": "GNOME collection",
             "grants": ["fedora-41", "kali-2026"]},
            {"sku": "distro_pack_all", "title": "Every distro, forever",
             "grants": ["*"]}
          ]
        }
    """.trimIndent()

    @Test
    fun `a pack with no sku is free`() {
        val i = index(catalogue)
        assertTrue(i.isUnlocked("ubuntu-24-04", emptySet()))
        // Free stays free no matter what is owned; nothing about ownership can
        // take the fallback theme away.
        assertTrue(i.isUnlocked("ubuntu-24-04", setOf("distro_pack_all")))
    }

    @Test
    fun `owning the pack's own sku unlocks exactly that pack`() {
        val i = index(catalogue)
        assertTrue(i.isUnlocked("kali-2026", setOf("distro_pack_kali")))
        assertFalse(i.isUnlocked("fedora-41", setOf("distro_pack_kali")))
        assertFalse(i.isUnlocked("garuda-dr460nized", setOf("distro_pack_kali")))
    }

    @Test
    fun `a bundle unlocks everything it grants and nothing else`() {
        val i = index(catalogue)
        val owned = setOf("distro_pack_gnome")
        assertTrue(i.isUnlocked("fedora-41", owned))
        assertTrue(i.isUnlocked("kali-2026", owned))
        assertFalse("garuda is not in the GNOME bundle", i.isUnlocked("garuda-dr460nized", owned))
    }

    @Test
    fun `the wildcard covers a pack that did not exist when it was bought`() {
        // THE PROMISE. Someone buys the complete collection today; a new distro
        // ships next month and is not named in any grants list. If the wildcard
        // were expanded to "every packId in the index at purchase time", this
        // buyer would be asked to pay again, and the store listing would be a
        // lie. Hence the literal "*" check rather than an expansion.
        val later = catalogue.replace(
            """{"packId": "garuda-dr460nized", "packType": "theme", "path": "themes/garuda",
             "version": 1, "minAppVersion": 6, "sizeBytes": 100, "sku": "distro_pack_garuda"}""",
            """{"packId": "garuda-dr460nized", "packType": "theme", "path": "themes/garuda",
             "version": 1, "minAppVersion": 6, "sizeBytes": 100, "sku": "distro_pack_garuda"},
            {"packId": "mint-22", "packType": "theme", "path": "themes/mint-22",
             "version": 1, "minAppVersion": 6, "sizeBytes": 100, "sku": "distro_pack_mint"}""",
        )
        val i = index(later)
        assertTrue(i.isUnlocked("mint-22", setOf("distro_pack_all")))
        assertFalse(i.isUnlocked("mint-22", setOf("distro_pack_gnome")))
    }

    @Test
    fun `an unknown pack is never unlocked`() {
        val i = index(catalogue)
        // Not even by the wildcard. A pack the index does not describe has no
        // path to download from, so "unlocked" would be meaningless anyway, and
        // returning true would invite a caller to act on it.
        assertFalse(i.isUnlocked("something-invented", setOf("distro_pack_all")))
    }

    @Test
    fun `offersFor lists every route to a pack, own sku first`() {
        val i = index(catalogue)
        assertEquals(
            listOf("distro_pack_kali", "distro_pack_gnome", "distro_pack_all"),
            i.offersFor("kali-2026"),
        )
        // A free pack has nothing to sell.
        assertTrue(i.offersFor("ubuntu-24-04").isEmpty())
    }

    @Test
    fun `an index with no entitlements block still parses`() {
        // Every index authored before C3 looks like this. It must keep working:
        // a client that cannot see bundles is degraded, not broken.
        val i = index(catalogue.replace(Regex(""",\s*"entitlements":\s*\[[\s\S]*?\]\s*(?=})"""), ""))
        assertTrue(i.entitlements.isEmpty())
        assertTrue(i.isUnlocked("kali-2026", setOf("distro_pack_kali")))
        assertFalse(i.isUnlocked("kali-2026", setOf("distro_pack_all")))
    }

    // ── publish-time validation ──────────────────────────────────────────────

    @Test
    fun `malformed skus are refused at parse`() {
        for (bad in listOf("Distro_Pack_All", "distro-pack-all", "_leading", "distro pack", "")) {
            assertFalse("should have rejected '$bad'", CdnIndex.isSafeSku(bad))
        }
        for (good in listOf("distro_pack_all", "pro_unlock", "pack1")) {
            assertTrue("should have accepted '$good'", CdnIndex.isSafeSku(good))
        }
    }

    @Test(expected = PackFormatException::class)
    fun `an entitlement with empty grants is refused`() {
        index(catalogue.replace("""["fedora-41", "kali-2026"]""", "[]"))
    }

    @Test(expected = PackFormatException::class)
    fun `a duplicate sku is refused`() {
        index(catalogue.replace("\"distro_pack_all\", \"title\"", "\"distro_pack_gnome\", \"title\""))
    }

    @Test
    fun `a bundle may grant a pack that has not shipped yet`() {
        // Deliberately allowed. Rejecting it would make publishing ORDER
        // matter: you could not announce a bundle before every pack in it was
        // live, which is the opposite of how a pre-order or a staged rollout
        // works. The grant simply matches nothing until the pack appears.
        val i = index(catalogue.replace("""["fedora-41", "kali-2026"]""", """["fedora-41", "not-yet-built"]"""))
        assertTrue(i.isUnlocked("fedora-41", setOf("distro_pack_gnome")))
        assertFalse(i.isUnlocked("not-yet-built", setOf("distro_pack_gnome")))
    }
}
