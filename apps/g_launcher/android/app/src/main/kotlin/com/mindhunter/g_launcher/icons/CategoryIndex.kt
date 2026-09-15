package com.mindhunter.g_launcher.icons

import android.content.pm.ApplicationInfo

/**
 * PHASE L4: a drawing for the apps no pack has ever heard of.
 *
 * ─── WHERE THIS SITS ────────────────────────────────────────────────────────
 *
 * Fifth of five, between the brand pack and the generator:
 *
 *   webApp -> iconPack -> hero -> brand -> THIS -> generator
 *
 * The four above it all answer "which app is this". This one answers "what KIND
 * of app is this", which is a strictly weaker claim, so it goes below all of
 * them and above the generator, which claims nothing at all.
 *
 * The gap it fills is the long tail. A brand pack covers a few hundred
 * recognisable apps; the other hundred on a Kenyan phone are a bank, a SACCO,
 * three matatu apps and a delivery service that Simple Icons will never carry.
 * Those currently fall to the generator, which re-masks the app's own icon, so
 * a line-art distro shows a grid of line drawings with a dozen full-colour
 * squares scattered through it. A category glyph is not the right icon, but it
 * is the right PICTURE, and coherence is what a themed drawer is selling.
 *
 * ─── WHY THE LABEL LEADS AND appCategory FOLLOWS ────────────────────────────
 *
 * The obvious design reads `ApplicationInfo.category` first. That field comes
 * from `android:appCategory` in the manifest, it is optional, and almost nobody
 * sets it. Every app that motivated this tier reports CATEGORY_UNDEFINED.
 *
 * It is also nine buckets wide, and three of the distinctions worth drawing
 * (finance, shopping, delivery) all live inside PRODUCTIVITY. So the manifest
 * value is a confirmation rather than a source: it is consulted after the label
 * and it is trusted for exactly one thing, GAME, which Play enforces.
 *
 * ─── AND WHY IT IS AN INDEX RATHER THAN A FUNCTION ──────────────────────────
 *
 * The icon path has a component key and nothing else. Classifying needs the
 * LABEL, which lives in `AppRepository` and is already being read there for the
 * drawer. Handing `AppRepository` to `IconCache` would couple the icon pipeline
 * to app enumeration for one string per package.
 *
 * So the repository publishes what it already knows, once per app-list build,
 * and the icon path reads a map. The cost is a few hundred short strings; the
 * alternative is a second enumeration of every installed app on the icon path.
 */

/**
 * The buckets a pack can draw.
 *
 * ─── ADDING ONE IS THREE EDITS, AND THE THIRD IS NOT IN THIS FILE ───────────
 *
 * The value here, its row in [KEYWORDS], and a slug in
 * `tools/icons/categories.json`. Miss the third and the bucket classifies
 * correctly, resolves to nothing, and falls to the generator: right answer, no
 * picture, no error. Same failure shape as a `LayoutResolver` allow-list.
 */
enum class AppCategoryBucket(val key: String) {
    FINANCE("finance"),
    SHOPPING("shopping"),
    DELIVERY("delivery"),
    VIDEO("video"),
    MUSIC("music"),
    MESSAGE("message"),
    CALL("call"),
    MAIL("mail"),
    SOCIAL("social"),
    CAMERA("camera"),
    FILES("files"),
    BROWSER("browser"),
    MAPS("maps"),
    PROPERTY("property"),
    TRAVEL("travel"),
    TRANSPORT("transport"),
    HEALTH("health"),
    SECURITY("security"),
    NETWORK("network"),
    TOOLS("tools"),
    NEWS("news"),
    CALENDAR("calendar"),
    GAME("game"),
    DATING("dating"),
    WORK("work"),
    ACCESSIBILITY("accessibility"),

    /**
     * Nothing matched.
     *
     * A REAL bucket rather than a null, because the alternative is falling to
     * the generator, and a generated full-colour tile beside twenty-five line
     * drawings is the incoherence this tier exists to remove. An empty ring
     * says "no idea" honestly; a re-masked app icon says it by accident.
     */
    UNKNOWN("unknown"),
}

/**
 * Classifies one app, and holds the answers for the icon path to read.
 *
 * Process-wide state, written by `AppRepository` on every app-list build and
 * read on the icon path. Both are already off the main thread and the map is
 * replaced wholesale rather than mutated, so a reader either sees the old map
 * or the new one and never a half-written one.
 */
object CategoryIndex {

    /**
     * Tokens per bucket, longest-first within a bucket at match time.
     *
     * ─── SUBSTRINGS OF THE WHOLE LABEL, NOT WORDS ───────────────────────────
     *
     * Splitting on word boundaries loses "MAFCarrefour", because camel case is
     * not a boundary anyone can rely on across locales and Kenyan app names are
     * full of it. Matching substrings of the lowercased label catches it, at the
     * cost of the occasional collision, which is why the bucket ORDER below is
     * load bearing: the first bucket whose token appears wins, so `message`
     * sits above `social` and `tools` above `work`.
     *
     * Spanish and Portuguese tokens are in from the start rather than as a
     * later pass. LatAm is where the paying users are, `es` and `pt-BR` are what
     * P1 is prioritising, and a tier that only works in English would be a
     * feature that fails precisely in the markets it was built for.
     */
    private val KEYWORDS: List<Pair<AppCategoryBucket, List<String>>> = listOf(
        // Ahead of everything: Play enforces this one, so a label never overrules it.
        AppCategoryBucket.GAME to listOf("game", "puzzle", "arcade", "juego", "jogo"),
        AppCategoryBucket.FINANCE to listOf(
            "bank", "banco", "wallet", "pesa", "money", "cash", "loan", "credit",
            "sacco", "invest", "fund", "bond", "stock", "currency", "forex",
            "insur", "dinero", "prestamo", "pago",
        ),
        AppCategoryBucket.DELIVERY to listOf(
            "pizza", "eats", "deliver", "kitchen", "restaurant", "takeaway",
            "glovo", "comida", "entrega",
        ),
        AppCategoryBucket.SHOPPING to listOf(
            "shop", "store", "mart", "market", "cart", "carrefour", "bazaar",
            "duka", "tienda", "loja", "compra",
        ),
        AppCategoryBucket.MESSAGE to listOf(
            "chat", "message", "mensaje", "conversa", "sms", "messenger",
        ),
        AppCategoryBucket.CALL to listOf("dial", "call", "voip", "llamada", "chamada"),
        AppCategoryBucket.MAIL to listOf("mail", "inbox", "correo"),
        AppCategoryBucket.VIDEO to listOf(
            "cinema", "cine", "movie", "pelicula", "film", "video", "stream",
            "flix", "player",
        ),
        AppCategoryBucket.MUSIC to listOf(
            "music", "musica", "audio", "song", "radio", "podcast", "sound",
        ),
        AppCategoryBucket.CAMERA to listOf(
            "camera", "photo", "foto", "gallery", "lens", "image", "imagen",
            "picture",
        ),
        AppCategoryBucket.MAPS to listOf("map", "mapa", "navig", "gps", "route", "ruta", "traffic"),
        AppCategoryBucket.PROPERTY to listOf(
            "property", "house", "apartment", "crib", "estate", "rent",
            "alquiler", "imovel", "casa",
        ),
        AppCategoryBucket.TRAVEL to listOf(
            "travel", "viaje", "flight", "voo", "hotel", "trip", "tour",
            "booking", "airbnb",
        ),
        AppCategoryBucket.TRANSPORT to listOf(
            "ride", "taxi", "uber", "bolt", "matatu", "train", "fuel", "coche",
            "carro",
        ),
        AppCategoryBucket.HEALTH to listOf(
            "health", "salud", "saude", "medic", "doctor", "clinic", "pharma",
            "fitness", "workout", "period",
        ),
        AppCategoryBucket.NETWORK to listOf("wifi", "hotspot", "speedtest", "signal", "detector"),
        AppCategoryBucket.SECURITY to listOf(
            "authenticat", "vpn", "password", "secure", "seguridad", "privac",
            "2fa", "guard", "lock",
        ),
        AppCategoryBucket.TOOLS to listOf(
            "remote", "desk", "console", "admin", "handyman", "repair",
            "calculat", "convert", "scanner", "herramienta", "util",
        ),
        AppCategoryBucket.NEWS to listOf("news", "noticia", "jornal", "daily", "times", "press"),
        AppCategoryBucket.CALENDAR to listOf("calendar", "agenda", "alarm", "timer", "reloj"),
        AppCategoryBucket.DATING to listOf("dating", "tryst", "match", "cita"),
        AppCategoryBucket.BROWSER to listOf("browser", "navegador", "surf"),
        AppCategoryBucket.FILES to listOf(
            "file", "archivo", "drive", "cloud", "nuvem", "storage", "backup",
            "transfer",
        ),
        AppCategoryBucket.SOCIAL to listOf("social", "feed", "forum", "community"),
        AppCategoryBucket.WORK to listOf(
            "meet", "office", "sheet", "slide", "project", "trabajo", "member",
        ),
        AppCategoryBucket.ACCESSIBILITY to listOf("accessib", "magnif", "talkback"),
    )

    /**
     * `ApplicationInfo.category` to a bucket, for the nine the platform knows.
     *
     * Consulted only when no keyword hit. Deliberately coarse: PRODUCTIVITY
     * covers a spreadsheet and a bank app equally badly, so it answers WORK,
     * which is the more common of the two and the less wrong when it misses.
     */
    private fun fromManifest(category: Int): AppCategoryBucket? = when (category) {
        ApplicationInfo.CATEGORY_GAME -> AppCategoryBucket.GAME
        ApplicationInfo.CATEGORY_AUDIO -> AppCategoryBucket.MUSIC
        ApplicationInfo.CATEGORY_VIDEO -> AppCategoryBucket.VIDEO
        ApplicationInfo.CATEGORY_IMAGE -> AppCategoryBucket.CAMERA
        ApplicationInfo.CATEGORY_SOCIAL -> AppCategoryBucket.SOCIAL
        ApplicationInfo.CATEGORY_NEWS -> AppCategoryBucket.NEWS
        ApplicationInfo.CATEGORY_MAPS -> AppCategoryBucket.MAPS
        ApplicationInfo.CATEGORY_PRODUCTIVITY -> AppCategoryBucket.WORK
        // CATEGORY_ACCESSIBILITY is API 33 and its constant is 8. Written as a
        // literal rather than gated behind a version check for one integer: the
        // value cannot change, and the alternative is a branch that reads as
        // though the number might.
        8 -> AppCategoryBucket.ACCESSIBILITY
        else -> null
    }

    /**
     * The bucket for one app.
     *
     * Pure, so it can be unit tested and so the index below is only a cache of
     * it rather than the definition.
     */
    fun classify(label: String, manifestCategory: Int): AppCategoryBucket {
        // GAME is checked against the manifest FIRST, not last, because Play
        // enforces it and it is the one value more reliable than any label.
        if (manifestCategory == ApplicationInfo.CATEGORY_GAME) return AppCategoryBucket.GAME

        val lower = label.lowercase()
        for ((bucket, tokens) in KEYWORDS) {
            for (t in tokens) {
                if (lower.contains(t)) return bucket
            }
        }
        return fromManifest(manifestCategory) ?: AppCategoryBucket.UNKNOWN
    }

    /**
     * packageName -> bucket. Replaced wholesale; never mutated in place.
     */
    @Volatile
    private var index: Map<String, AppCategoryBucket> = emptyMap()

    /**
     * Called by `AppRepository` once per app-list build.
     *
     * Takes the whole map rather than one entry at a time so the swap is atomic.
     * A reader mid-build would otherwise see a map missing most of its apps and
     * draw a screen of unknown rings, which is a worse wrong answer than the
     * previous build's slightly stale one.
     */
    fun publish(next: Map<String, AppCategoryBucket>) {
        index = next
    }

    /**
     * The bucket for a package, or null when the index has never been built.
     *
     * Null rather than UNKNOWN, and the difference matters: "not classified yet"
     * has to fall to the generator, because drawing the unknown ring for every
     * app on first boot would be a screen of identical circles that then
     * silently became real icons a second later.
     */
    fun bucketFor(packageName: String): AppCategoryBucket? = index[packageName]
}
