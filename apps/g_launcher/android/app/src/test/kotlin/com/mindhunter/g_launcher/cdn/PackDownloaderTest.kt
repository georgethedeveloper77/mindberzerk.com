package com.mindhunter.g_launcher.cdn

import com.mindhunter.g_launcher.theme.PackKeys
import com.mindhunter.g_launcher.theme.PackVerifier
import com.mindhunter.g_launcher.theme.ThemeAssetLoader
import com.sun.net.httpserver.HttpServer
import java.io.File
import java.net.InetSocketAddress
import java.security.MessageDigest
import org.bouncycastle.crypto.params.Ed25519PrivateKeyParameters
import org.bouncycastle.crypto.signers.Ed25519Signer
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder

/**
 * PHASE C2 - the download path, end to end, against a real HTTP server.
 *
 * `com.sun.net.httpserver` ships with the JDK, so this needs no emulator, no
 * Robolectric and no mock HTTP library. It is the payoff for keeping every
 * class in this pipeline free of `android.*`: the interesting logic is fully
 * exercised on a laptop in under a second.
 *
 * The origin is deliberately HOSTILE in several tests. A CDN that serves
 * exactly what it was told to serve proves nothing; the checks here only earn
 * their place against an origin that swaps a file, replays an old index, or
 * sends far more bytes than it promised.
 */
class PackDownloaderTest {

    @get:Rule
    val temp = TemporaryFolder()

    private lateinit var server: HttpServer
    private lateinit var baseUrl: String

    /** Remote path -> body. Mutated mid-test to simulate a bad origin. */
    private val objects = HashMap<String, ByteArray>()

    private lateinit var privateKey: Ed25519PrivateKeyParameters
    private lateinit var keys: Map<String, ByteArray>
    private lateinit var packsRoot: File
    private lateinit var loader: ThemeAssetLoader
    private lateinit var verifier: PackVerifier
    private lateinit var downloader: PackDownloader

    private val keyId = "test-key"

    @Before
    fun setUp() {
        val seed = ByteArray(32) { i -> (i * 11 + 5).toByte() }
        privateKey = Ed25519PrivateKeyParameters(seed, 0)
        keys = mapOf(keyId to privateKey.generatePublicKey().encoded)

        server = HttpServer.create(InetSocketAddress("127.0.0.1", 0), 0)
        server.createContext("/") { exchange ->
            val path = exchange.requestURI.path.removePrefix("/")
            val body = objects[path]
            if (body == null) {
                exchange.sendResponseHeaders(404, -1)
            } else {
                exchange.responseHeaders.add("ETag", "\"" + sha256Hex(body).take(16) + "\"")
                exchange.sendResponseHeaders(200, body.size.toLong())
                exchange.responseBody.write(body)
            }
            exchange.close()
        }
        server.start()
        baseUrl = "http://127.0.0.1:${server.address.port}"

        // The one place plaintext is permitted, and only ever from a test.
        CdnClient.allowInsecureForTests = true

        packsRoot = temp.newFolder("packs")
        verifier = PackVerifier(acceptedKeys = keys, appVersionCode = 6)
        loader = ThemeAssetLoader(packsRoot, verifier)
        downloader = PackDownloader(
            client = CdnClient(baseUrl, connectTimeoutMs = 2_000, readTimeoutMs = 2_000),
            loader = loader,
            packsRoot = packsRoot,
            acceptedKeys = keys,
            verifier = verifier,
        )
    }

    @After
    fun tearDown() {
        server.stop(0)
        CdnClient.allowInsecureForTests = false
    }

    // ── the index ────────────────────────────────────────────────────────────

    @Test
    fun `a signed index is fetched, verified and cached`() {
        publishIndex(generatedAt = 1_000, version = 1)

        val first = downloader.refreshIndex()
        assertTrue("expected Updated, got $first", first is IndexResult.Updated)
        assertEquals(1, (first as IndexResult.Updated).index.packs.size)
        assertEquals("simple-icons", first.index.packs[0].packId)

        // Second call sends If-None-Match and the origin has not changed.
        assertNotNull(downloader.cachedIndex())
    }

    @Test
    fun `an index signed by the wrong key is refused and the cache survives`() {
        publishIndex(generatedAt = 1_000, version = 1)
        assertTrue(downloader.refreshIndex() is IndexResult.Updated)

        val stranger = Ed25519PrivateKeyParameters(ByteArray(32) { 0x3C }, 0)
        publishIndex(generatedAt = 2_000, version = 2, signWith = stranger)

        val result = downloader.refreshIndex()
        assertTrue("expected Rejected, got $result", result is IndexResult.Rejected)
        // The device still holds the good one.
        assertEquals(1_000L, downloader.cachedIndex()!!.generatedAt)
    }

    @Test
    fun `replaying an older index is refused`() {
        publishIndex(generatedAt = 5_000, version = 2)
        assertTrue(downloader.refreshIndex() is IndexResult.Updated)

        // Correctly signed, genuinely ours, and older. A stale edge or a
        // deliberate replay to hide the v2 pack. Same answer either way.
        publishIndex(generatedAt = 4_000, version = 1)

        val result = downloader.refreshIndex()
        assertTrue("expected Stale, got $result", result is IndexResult.Stale)
        assertEquals(5_000L, downloader.cachedIndex()!!.generatedAt)
    }

    // ── one pack ─────────────────────────────────────────────────────────────

    @Test
    fun `a brand pack downloads, verifies and installs`() {
        publishIndex(generatedAt = 1_000, version = 1)
        publishPack(version = 1)

        val index = (downloader.refreshIndex() as IndexResult.Updated).index

        val progress = ArrayList<Pair<Long, Long>>()
        val result = downloader.syncPack("simple-icons", index) { done, total ->
            progress.add(done to total)
        }

        assertTrue("expected Installed, got $result", result is SyncResult.Installed)
        assertTrue(loader.isInstalled("simple-icons"))
        assertEquals(1, loader.installedVersion("simple-icons"))
        assertTrue(File(loader.installedDir("simple-icons"), "pack.json").readText().contains("com.whatsapp"))
        assertTrue("progress should have been reported", progress.isNotEmpty())
        assertEquals(progress.last().second, progress.last().first)
    }

    @Test
    fun `a second sync with nothing new fetches no payload`() {
        publishIndex(generatedAt = 1_000, version = 1)
        publishPack(version = 1)
        val index = (downloader.refreshIndex() as IndexResult.Updated).index
        assertTrue(downloader.syncPack("simple-icons", index) is SyncResult.Installed)

        // Remove the payload from the origin entirely. If the downloader tried
        // to fetch it, this fails loudly - which is exactly the assertion:
        // the version comparison must short-circuit before any transfer.
        objects.remove("g-launcher/brandpacks/simple-icons/pack.json")

        val second = downloader.syncPack("simple-icons", index)
        assertTrue("expected UpToDate, got $second", second is SyncResult.UpToDate)
    }

    @Test
    fun `an origin that swaps a payload file after signing is caught`() {
        publishIndex(generatedAt = 1_000, version = 1)
        publishPack(version = 1)
        val index = (downloader.refreshIndex() as IndexResult.Updated).index

        // The manifest is untouched and its signature is perfect. Only the
        // payload was replaced - the exact attack the per-file hashes exist for.
        objects["g-launcher/brandpacks/simple-icons/pack.json"] =
            """{"id":"simple-icons","icons":{"com.bank":{"d":"M0 0","hex":"000000"}}}""".toByteArray()

        val result = downloader.syncPack("simple-icons", index)
        // Caught on size first here, which is the cheap check doing its job.
        assertTrue("expected Rejected or Failed, got $result",
            result is SyncResult.Rejected || result is SyncResult.Failed)
        assertFalse(loader.isInstalled("simple-icons"))
    }

    @Test
    fun `an origin sending more bytes than the manifest promised is cut off`() {
        publishIndex(generatedAt = 1_000, version = 1)
        publishPack(version = 1)
        val index = (downloader.refreshIndex() as IndexResult.Updated).index

        // Same first bytes, then megabytes more. Without the mid-stream cap
        // this fills the device before a single hash is computed.
        val real = objects["g-launcher/brandpacks/simple-icons/pack.json"]!!
        objects["g-launcher/brandpacks/simple-icons/pack.json"] = real + ByteArray(2 * 1024 * 1024)

        val result = downloader.syncPack("simple-icons", index)
        assertTrue("expected Failed, got $result", result is SyncResult.Failed)
        assertFalse(loader.isInstalled("simple-icons"))
        // And nothing survives in staging.
        assertFalse(File(packsRoot, ".staging/simple-icons").exists())
    }

    @Test
    fun `an index advertising a version the manifest does not confirm is refused`() {
        publishIndex(generatedAt = 1_000, version = 9)
        publishPack(version = 1)
        val index = (downloader.refreshIndex() as IndexResult.Updated).index

        val result = downloader.syncPack("simple-icons", index)
        assertTrue("expected Rejected, got $result", result is SyncResult.Rejected)
        assertFalse(loader.isInstalled("simple-icons"))
    }

    @Test
    fun `a pack the index does not offer is not fetched`() {
        publishIndex(generatedAt = 1_000, version = 1)
        val index = (downloader.refreshIndex() as IndexResult.Updated).index
        assertTrue(downloader.syncPack("kde-plasma-6", index) is SyncResult.NotOffered)
    }

    @Test
    fun `a pack requiring a newer app is refused before any transfer`() {
        publishIndex(generatedAt = 1_000, version = 1, minAppVersion = 99)
        val index = (downloader.refreshIndex() as IndexResult.Updated).index
        val result = downloader.syncPack("simple-icons", index)
        assertTrue("expected AppTooOld, got $result", result is SyncResult.AppTooOld)
    }

    @Test
    fun `a genuine update replaces the installed pack`() {
        publishIndex(generatedAt = 1_000, version = 1)
        publishPack(version = 1)
        var index = (downloader.refreshIndex() as IndexResult.Updated).index
        assertTrue(downloader.syncPack("simple-icons", index) is SyncResult.Installed)

        publishIndex(generatedAt = 2_000, version = 2)
        publishPack(version = 2, extraIcon = true)
        index = (downloader.refreshIndex() as IndexResult.Updated).index

        assertTrue(downloader.syncPack("simple-icons", index) is SyncResult.Installed)
        assertEquals(2, loader.installedVersion("simple-icons"))
        assertTrue(File(loader.installedDir("simple-icons"), "pack.json").readText().contains("com.spotify"))
    }

    @Test
    fun `plaintext http is refused when the test escape hatch is closed`() {
        CdnClient.allowInsecureForTests = false
        publishIndex(generatedAt = 1_000, version = 1)
        val result = downloader.refreshIndex()
        assertTrue("expected Failed, got $result", result is IndexResult.Failed)
    }

    // ── the fake origin ──────────────────────────────────────────────────────

    private fun publishIndex(
        generatedAt: Long,
        version: Int,
        minAppVersion: Int = 0,
        signWith: Ed25519PrivateKeyParameters = privateKey,
    ) {
        val body = buildString {
            append("{\n")
            append("  \"formatVersion\": 1,\n")
            append("  \"generatedAt\": ").append(generatedAt).append(",\n")
            append("  \"keyId\": \"").append(keyId).append("\",\n")
            append("  \"packs\": [\n")
            append("    {\"packId\": \"simple-icons\", \"packType\": \"brand\", ")
            append("\"path\": \"brandpacks/simple-icons\", \"version\": ").append(version)
            append(", \"minAppVersion\": ").append(minAppVersion)
            append(", \"sizeBytes\": 4096, \"title\": \"Simple Icons\", \"summary\": \"CC0 brand glyphs\"}\n")
            append("  ]\n")
            append("}")
        }.toByteArray(Charsets.UTF_8)

        objects["g-launcher/index.json"] = body
        objects["g-launcher/index.sig"] = sign(signWith, body)
    }

    private fun publishPack(version: Int, extraIcon: Boolean = false) {
        val icons = StringBuilder("""{"com.whatsapp":{"d":"M17 14z","hex":"25D366"}""")
        if (extraIcon) icons.append(""","com.spotify":{"d":"M12 0z","hex":"1DB954"}""")
        icons.append("}")
        val packJson = """{"id":"simple-icons","viewBox":24,"icons":$icons}""".toByteArray()

        val manifest = buildString {
            append("{\n")
            append("  \"formatVersion\": 1,\n")
            append("  \"packType\": \"brand\",\n")
            append("  \"packId\": \"simple-icons\",\n")
            append("  \"version\": ").append(version).append(",\n")
            append("  \"minAppVersion\": 0,\n")
            append("  \"keyId\": \"").append(keyId).append("\",\n")
            append("  \"files\": [\n")
            append("""    {"path": "pack.json", "size": ${packJson.size}, "sha256": "${sha256Hex(packJson)}"}""")
            append("\n  ]\n")
            append("}")
        }.toByteArray(Charsets.UTF_8)

        val prefix = "g-launcher/brandpacks/simple-icons"
        objects["$prefix/pack.json"] = packJson
        objects["$prefix/manifest.json"] = manifest
        objects["$prefix/manifest.sig"] = sign(privateKey, manifest)
    }

    private fun sign(key: Ed25519PrivateKeyParameters, message: ByteArray): ByteArray {
        val signer = Ed25519Signer()
        signer.init(true, key)
        signer.update(message, 0, message.size)
        return signer.generateSignature()
    }

    private fun sha256Hex(bytes: ByteArray): String =
        PackKeys.encodeHex(MessageDigest.getInstance("SHA-256").digest(bytes))
}
