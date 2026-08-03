/**
 * PHASE C8 - hero packs, matching the launcher's actual reader.
 *
 * ## This is now READ OFF THE SOURCE, not guessed
 *
 * The first cut of this file invented four things `HeroIconResolver.readPack`
 * does not read, each of which would have produced a pack that verifies,
 * downloads, installs and renders NOTHING:
 *
 *   - a `formatVersion` field                    (not read)
 *   - per-icon `{ file, masked, scale }` objects (it reads a flat
 *     packageName -> filename string map)
 *   - a `scale`, per-icon or pack-level          (renderHero draws at a
 *     hardcoded 1.0f and ignores foregroundScale - there is no scale to set)
 *   - `.webp` filenames                          (the convention is `.png`)
 *
 * The real shape, from HeroIconResolver:
 *
 *   {
 *     "id": "yaru",
 *     "name": "Yaru",
 *     "masked": false,
 *     "icons": {
 *       "com.android.chrome": "chrome.png",
 *       "com.whatsapp": "whatsapp.png"
 *     }
 *   }
 *
 * ## `masked` is ONE pack-level flag, and false is the usual case
 *
 * From the resolver's doc: `masked: false` means each icon is already final art
 * with its own silhouette and transparency, drawn as authored. `masked: true`
 * means the pack ships square full-bleed art that the theme's mask still has to
 * be clipped onto. It is not per-icon, and it is not the brand layer's
 * glyph/plate distinction. Default false.
 *
 * ## There is NO keyline resize for hero art
 *
 * `renderHero` draws the drawable at 1.0f. It does not apply `foregroundScale`,
 * and BRAND_GLYPH_RATIO belongs to the BRAND path, where a single glyph would
 * otherwise fill its plate. Hero art is drawn at its own native size. So the
 * panel must NOT trim-and-rescale hero art to a keyline: that uniformly shrinks
 * art drawn correctly. Keep the source dimensions and transparency, encode PNG.
 *
 * NO `server-only`: the builder runs this in the browser.
 */

export interface HeroPack {
  id: string;
  name: string;
  /** Pack-level. true only when the art is square full-bleed needing the mask. */
  masked: boolean;
  /** packageName (or componentKey) -> filename inside the pack. */
  icons: Record<string, string>;
}

export interface HeroEntry {
  /** Android application id, e.g. `com.whatsapp`. Or a full componentKey. */
  pkg: string;
  /** File name inside the pack, derived from the package. */
  file: string;
}

/** Serialise into the exact shape HeroIconResolver.readPack expects. */
export function buildHeroPackJson(
  id: string,
  name: string,
  masked: boolean,
  entries: HeroEntry[],
): HeroPack {
  const icons: Record<string, string> = {};
  for (const e of entries) icons[e.pkg] = e.file;
  return { id, name, masked, icons };
}

/**
 * Filename for an entry. PNG, because that is the convention in the pack format
 * and `BitmapFactory.decodeByteArray` is fed these bytes directly. Derived from
 * the package so two uploads called `icon.png` cannot collide and every path in
 * the signed manifest is predictable.
 */
export function fileNameFor(pkg: string): string {
  return `${pkg.replace(/[^a-z0-9]/gi, '_').toLowerCase()}.png`;
}

// ── package mapping ─────────────────────────────────────────────────────────

/**
 * THE MAPPING TABLE IS THE ACTUAL CONTENT OF A HERO PACK.
 *
 * Linux icon themes are keyed by desktop file names. The launcher looks up
 * `com.android.chrome`. Nothing connects the two, and that table is what the
 * `icons` map holds. The drawing is the easy half.
 *
 * The core set is biased toward the install base, not the Linux desktop:
 * Papirus ships Inkscape and GIMP; a Tecno Spark has WhatsApp, TikTok, Opera
 * Mini and a payment app. The two barely intersect, which is why importing a
 * desktop theme wholesale changes almost nothing on the devices that matter.
 *
 * The launcher has no app-icon grid, so the only icons a user sees are the dock
 * and the first drawer page - roughly the 25 to 40 slots below.
 */
/**
 * ── ROLES, NOT PACKAGES ─────────────────────────────────────────────────────
 *
 * The table used to be one row per package id, and one row per package is a
 * lie about how phones are actually built. "Phone" is `com.android.dialer` on
 * AOSP, `com.google.android.dialer` on a Pixel and
 * `com.samsung.android.dialer` on the S22 that this project tests on. Under
 * the flat table an artist drew one Phone icon, it matched one of those three,
 * and on the other two the app fell through to the generator SILENTLY, which
 * is this codebase's most expensive recurring failure mode.
 *
 * So a row is now a ROLE: one label, one piece of art, and every package id
 * that plays that role, most standard first. The builders show one tile per
 * role and expand it at publish, so `pack.json` still ships the flat
 * package-to-filename map `HeroIconResolver` already reads. NOTHING ON THE
 * DEVICE CHANGES: the wire format, the resolver and the signed manifest are
 * untouched, the map is simply complete now.
 *
 * ── WHERE THESE IDS COME FROM ───────────────────────────────────────────────
 *
 * Samsung ids were read off the S22 with
 * `adb shell cmd package query-activities -a android.intent.action.MAIN
 *  -c android.intent.category.LAUNCHER`, so they are what that device actually
 * resolves rather than what a blog says. Google and AOSP ids are verified the
 * same way or against the Play listing URL.
 *
 * TRANSSION (HiOS/XOS) IS DELIBERATELY ABSENT. Those ids vary by ROM version,
 * there is no Transsion device on hand to enumerate, and a guessed id is worse
 * than no id: it looks handled and matches nothing. They go in when a device
 * or a verified source provides them.
 */
export interface CoreRole {
  /** Stable key for the role. Used by the builders as the grid slot id. */
  id: string;
  label: string;
  hints: string[];
  /** Every package that plays this role, most standard first. */
  packages: string[];
}

export const CORE_ROLES: CoreRole[] = [
  { id: 'phone', label: 'Phone', hints: ['phone', 'dialer', 'call'], packages: ['com.android.dialer', 'com.google.android.dialer', 'com.samsung.android.dialer'] },
  { id: 'messages', label: 'Messages', hints: ['message', 'sms', 'chat'], packages: ['com.android.mms', 'com.google.android.apps.messaging', 'com.samsung.android.messaging'] },
  { id: 'contacts', label: 'Contacts', hints: ['contact', 'people', 'address'], packages: ['com.android.contacts', 'com.google.android.contacts', 'com.samsung.android.app.contacts'] },
  { id: 'camera', label: 'Camera', hints: ['camera', 'photo'], packages: ['com.android.camera2', 'com.sec.android.app.camera'] },
  { id: 'gallery', label: 'Gallery', hints: ['gallery', 'image', 'pictures', 'photos', 'shotwell'], packages: ['com.android.gallery3d', 'com.google.android.apps.photos', 'com.sec.android.gallery3d'] },
  { id: 'settings', label: 'Settings', hints: ['settings', 'preferences', 'config'], packages: ['com.android.settings'] },
  { id: 'clock', label: 'Clock', hints: ['clock', 'alarm', 'time'], packages: ['com.android.deskclock', 'com.google.android.deskclock', 'com.sec.android.app.clockpackage'] },
  { id: 'calculator', label: 'Calculator', hints: ['calculator', 'calc'], packages: ['com.android.calculator2', 'com.google.android.calculator', 'com.sec.android.app.popupcalculator'] },
  { id: 'files', label: 'Files', hints: ['files', 'file', 'nautilus', 'folder'], packages: ['com.android.documentsui', 'com.google.android.apps.nbu.files', 'com.sec.android.app.myfiles'] },
  { id: 'calendar', label: 'Calendar', hints: ['calendar'], packages: ['com.android.calendar', 'com.google.android.calendar', 'com.samsung.android.calendar'] },
  { id: 'browser', label: 'Browser', hints: ['chrome', 'browser'], packages: ['com.android.chrome', 'com.sec.android.app.sbrowser'] },
  { id: 'store', label: 'App store', hints: ['store', 'play', 'shop', 'software'], packages: ['com.android.vending', 'com.sec.android.app.samsungapps'] },
  { id: 'voice', label: 'Recorder', hints: ['record', 'voice', 'memo'], packages: ['com.sec.android.app.voicenote'] },
  { id: 'notes', label: 'Notes', hints: ['note', 'memo', 'keep'], packages: ['com.google.android.keep', 'com.samsung.android.app.notes'] },
  { id: 'search', label: 'Search', hints: ['search', 'google'], packages: ['com.google.android.googlequicksearchbox'] },
  { id: 'youtube', label: 'YouTube', hints: ['youtube'], packages: ['com.google.android.youtube'] },
  { id: 'gmail', label: 'Gmail', hints: ['gmail', 'mail', 'thunderbird'], packages: ['com.google.android.gm'] },
  { id: 'maps', label: 'Maps', hints: ['maps', 'map'], packages: ['com.google.android.apps.maps'] },
  { id: 'music', label: 'Music', hints: ['music', 'ytmusic'], packages: ['com.google.android.apps.youtube.music', 'com.sec.android.app.music'] },
  { id: 'whatsapp', label: 'WhatsApp', hints: ['whatsapp'], packages: ['com.whatsapp', 'com.whatsapp.w4b'] },
  { id: 'tiktok', label: 'TikTok', hints: ['tiktok'], packages: ['com.zhiliaoapp.musically'] },
  { id: 'facebook', label: 'Facebook', hints: ['facebook', 'fblite'], packages: ['com.facebook.katana', 'com.facebook.lite'] },
  { id: 'messenger', label: 'Messenger', hints: ['messenger', 'orca'], packages: ['com.facebook.orca'] },
  { id: 'instagram', label: 'Instagram', hints: ['instagram'], packages: ['com.instagram.android'] },
  { id: 'x', label: 'X', hints: ['twitter'], packages: ['com.twitter.android'] },
  { id: 'snapchat', label: 'Snapchat', hints: ['snapchat', 'snap'], packages: ['com.snapchat.android'] },
  { id: 'telegram', label: 'Telegram', hints: ['telegram'], packages: ['org.telegram.messenger'] },
  { id: 'opera', label: 'Opera Mini', hints: ['opera'], packages: ['com.opera.mini.native', 'com.opera.browser'] },
  { id: 'spotify', label: 'Spotify', hints: ['spotify'], packages: ['com.spotify.music'] },
  { id: 'boomplay', label: 'Boomplay', hints: ['boomplay'], packages: ['com.afmobi.boomplayer'] },
  { id: 'audiomack', label: 'Audiomack', hints: ['audiomack'], packages: ['com.audiomack'] },
  { id: 'netflix', label: 'Netflix', hints: ['netflix'], packages: ['com.netflix.mediaclient'] },
  { id: 'capcut', label: 'CapCut', hints: ['capcut'], packages: ['com.lemon.lvoverseas'] },
  { id: 'shareit', label: 'SHAREit', hints: ['shareit'], packages: ['com.lenovo.anyshare.gps'] },
  { id: 'xender', label: 'Xender', hints: ['xender'], packages: ['cn.xender'] },
  { id: 'mpesa', label: 'M-PESA', hints: ['mpesa'], packages: ['com.safaricom.mpesa.lifestyle'] },
  { id: 'opay', label: 'OPay', hints: ['opay'], packages: ['team.opay.pay'] },
  { id: 'palmpay', label: 'PalmPay', hints: ['palmpay'], packages: ['com.transsnet.palmpay'] },
  { id: 'grecovery', label: 'G Recovery', hints: ['recovery'], packages: ['com.mindhunter.g_recovery'] },
];

/** The role a package plays, or null when no role claims it. */
export function roleForPackage(pkg: string): CoreRole | null {
  return CORE_ROLES.find((r) => r.packages.includes(pkg)) ?? null;
}

/**
 * Expand one assignment per ROLE into one entry per PACKAGE.
 *
 * This is the whole trick: the builder holds `role -> file`, the pack ships
 * `package -> file`, and every vendor's id lands on the art that was drawn
 * once. A slot whose id is not a known role passes through untouched, which
 * is what keeps hand-typed package ids working.
 */
export function expandRoleEntries(
  assigned: { slot: string; file: string }[],
): { pkg: string; file: string }[] {
  const out: { pkg: string; file: string }[] = [];
  const seen = new Set<string>();
  for (const a of assigned) {
    const role = CORE_ROLES.find((r) => r.id === a.slot);
    const pkgs = role ? role.packages : [a.slot];
    for (const pkg of pkgs) {
      if (seen.has(pkg)) continue;
      seen.add(pkg);
      out.push({ pkg, file: a.file });
    }
  }
  return out;
}

/**
 * Flat view, kept because `guessPackage` and older callers want one row per
 * package. Derived rather than maintained, so the two can never disagree.
 */
export const CORE_PACKAGES: { pkg: string; label: string; hints: string[] }[] =
  CORE_ROLES.flatMap((r) => r.packages.map((pkg) => ({ pkg, label: r.label, hints: r.hints })));

/**
 * Guess a package from a file name. A guess, never an assignment: it fills the
 * field and the row stays flagged until confirmed. A wrong mapping is invisible
 * on device - the icon simply never appears and the generator covers it.
 */
export function guessPackage(fileName: string): string | null {
  const stem = fileName
    .replace(/\.[^.]+$/, '')
    .toLowerCase()
    .replace(/[^a-z0-9]/g, '');
  if (!stem) return null;

  for (const entry of CORE_PACKAGES) {
    for (const hint of entry.hints) {
      if (stem === hint || stem.includes(hint)) return entry.pkg;
    }
  }

  const raw = fileName.replace(/\.[^.]+$/, '');
  if (/^[a-z][a-z0-9_]*(\.[a-z0-9_]+){2,}$/i.test(raw)) return raw.toLowerCase();

  return null;
}

/** Android application ids, loosely. A componentKey (pkg/class#serial) also passes. */
export function isPackageName(value: string): boolean {
  if (/^[a-z][a-z0-9_]*(\.[a-z0-9_]+)+$/i.test(value)) return true;
  // The resolver also accepts a full componentKey for apps with several
  // launchable activities: pkg/class#serial.
  return /^[a-z][a-z0-9_.]+\/[A-Za-z0-9_.$]+#\d+$/.test(value);
}
