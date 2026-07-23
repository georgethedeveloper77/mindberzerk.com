/**
 * PHASE C8 — hero packs, matching the launcher's actual reader.
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
 *     hardcoded 1.0f and ignores foregroundScale — there is no scale to set)
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
 * and the first drawer page — roughly the 25 to 40 slots below.
 */
export const CORE_PACKAGES: { pkg: string; label: string; hints: string[] }[] = [
  { pkg: 'com.android.dialer', label: 'Phone', hints: ['phone', 'dialer', 'call'] },
  { pkg: 'com.android.mms', label: 'Messages', hints: ['message', 'sms', 'chat'] },
  { pkg: 'com.android.camera2', label: 'Camera', hints: ['camera', 'photo'] },
  { pkg: 'com.android.gallery3d', label: 'Gallery', hints: ['gallery', 'image', 'pictures'] },
  { pkg: 'com.android.settings', label: 'Settings', hints: ['settings', 'preferences', 'config'] },
  { pkg: 'com.android.deskclock', label: 'Clock', hints: ['clock', 'alarm', 'time'] },
  { pkg: 'com.android.calculator2', label: 'Calculator', hints: ['calculator', 'calc'] },
  { pkg: 'com.android.documentsui', label: 'Files', hints: ['files', 'file', 'nautilus', 'folder'] },
  { pkg: 'com.android.chrome', label: 'Chrome', hints: ['chrome', 'browser'] },
  { pkg: 'com.android.vending', label: 'Play Store', hints: ['store', 'play', 'shop'] },
  { pkg: 'com.google.android.youtube', label: 'YouTube', hints: ['youtube'] },
  { pkg: 'com.google.android.gm', label: 'Gmail', hints: ['gmail', 'mail', 'thunderbird'] },
  { pkg: 'com.google.android.apps.maps', label: 'Maps', hints: ['maps', 'map'] },
  { pkg: 'com.android.calendar', label: 'Calendar', hints: ['calendar'] },
  { pkg: 'com.whatsapp', label: 'WhatsApp', hints: ['whatsapp'] },
  { pkg: 'com.zhiliaoapp.musically', label: 'TikTok', hints: ['tiktok'] },
  { pkg: 'com.facebook.lite', label: 'Facebook Lite', hints: ['facebook', 'fblite'] },
  { pkg: 'com.instagram.android', label: 'Instagram', hints: ['instagram'] },
  { pkg: 'com.opera.mini.native', label: 'Opera Mini', hints: ['opera'] },
  { pkg: 'com.spotify.music', label: 'Spotify', hints: ['spotify'] },
  { pkg: 'org.telegram.messenger', label: 'Telegram', hints: ['telegram'] },
  { pkg: 'com.boomplay', label: 'Boomplay', hints: ['boomplay'] },
  { pkg: 'com.lenovo.anyshare.gps', label: 'SHAREit', hints: ['shareit'] },
  { pkg: 'cn.xender', label: 'Xender', hints: ['xender'] },
  { pkg: 'com.mindhunter.g_recovery', label: 'G Recovery', hints: ['recovery'] },
];

/**
 * Guess a package from a file name. A guess, never an assignment: it fills the
 * field and the row stays flagged until confirmed. A wrong mapping is invisible
 * on device — the icon simply never appears and the generator covers it.
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
