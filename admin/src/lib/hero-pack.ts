/**
 * The hero-pack SHAPE, pure and client-safe.
 *
 * A hero pack is a set of hand-authored app icons: a `pack.json` mapping Android
 * package names to bare image filenames, plus those images. The device's
 * HeroIconResolver reads exactly `{ id, name, masked, icons: { pkg: file } }`.
 * `masked` is a single pack-level bool (false = art drawn as authored, the usual
 * case); renderHero draws at native size and ignores per-icon scale.
 *
 * No 'server-only' here: the builder runs this in the browser to preview and
 * validate, and the publish path runs the same serializer on the server so the
 * bytes that get signed are the bytes the builder showed.
 */

export interface HeroPackJson {
  id: string;
  name: string;
  masked: boolean;
  /** package name -> bare filename inside the pack. */
  icons: Record<string, string>;
}

/** One authored icon in the builder: a package, its display label, its file. */
export interface HeroIconEntry {
  pkg: string;
  label: string;
  /** Bare filename this icon will ship as, e.g. `ic_0003.png`. Empty until drawn. */
  file: string;
}

// ── validation (pure copies, matching sign.ts / PackPaths) ───────────────────

const PACK_ID = /^[a-z0-9._-]+$/;
const PACKAGE = /^[a-zA-Z][a-zA-Z0-9_]*(\.[a-zA-Z][a-zA-Z0-9_]*)+$/;
const BARE_FILE = /^[A-Za-z0-9._-]+$/;
const SKU = /^[a-z0-9][a-z0-9_]{0,63}$/;

export function isSafePackId(id: string): boolean {
  return !!id && id.length <= 64 && !id.startsWith('.') && PACK_ID.test(id);
}
/** An Android application id: dotted segments, each starting with a letter. */
export function isValidPackage(pkg: string): boolean {
  return PACKAGE.test(pkg) && pkg.length <= 200;
}
/** Bare filename, no slashes: PackPaths.installedFile refuses anything else. */
export function isBareFilename(f: string): boolean {
  return !!f && !f.includes('/') && !f.includes('\\') && !f.includes('..') && BARE_FILE.test(f);
}
export function isSafeSku(sku: string): boolean {
  return SKU.test(sku);
}

// ── the canonical pack.json (byte-stable) ────────────────────────────────────

/**
 * The exact pack.json bytes that get signed. Package keys are sorted so the same
 * set of icons always produces the same bytes, keeping the manifest hash stable
 * across re-publishes of identical content.
 */
export function canonicalHeroPackJson(pack: HeroPackJson): string {
  const icons: Record<string, string> = {};
  for (const pkg of Object.keys(pack.icons).sort()) icons[pkg] = pack.icons[pkg];
  const body = { id: pack.id, name: pack.name, masked: pack.masked, icons };
  return JSON.stringify(body, null, 2) + '\n';
}

/** Stable bare filename for the nth authored icon. */
export function iconFilename(index: number): string {
  return `ic_${String(index + 1).padStart(4, '0')}.png`;
}

export interface HeroPackDraftMeta {
  id: string;
  name: string;
  minAppVersion: number;
  masked: boolean;
  sku: string | null;
}

/** Problems that would fail the signer or the device, surfaced at edit time. */
export function validateHeroPack(meta: HeroPackDraftMeta, entries: HeroIconEntry[]): string[] {
  const p: string[] = [];
  if (!isSafePackId(meta.id)) p.push(`Pack id '${meta.id}' must be lowercase letters, digits, . _ or -`);
  if (!meta.name.trim()) p.push('Pack name is required');
  if (!Number.isInteger(meta.minAppVersion) || meta.minAppVersion < 0) {
    p.push('Min app version must be a whole number of 0 or more');
  }
  if (meta.sku != null && meta.sku !== '' && !isSafeSku(meta.sku)) {
    p.push(`SKU '${meta.sku}' must match a Play product id`);
  }

  const drawn = entries.filter((e) => e.file);
  if (drawn.length === 0) p.push('Draw or upload at least one icon');

  const seenPkg = new Set<string>();
  const seenFile = new Set<string>();
  for (const e of drawn) {
    if (!isValidPackage(e.pkg)) p.push(`'${e.pkg}' is not a valid Android package name`);
    if (seenPkg.has(e.pkg)) p.push(`Package '${e.pkg}' is listed twice`);
    seenPkg.add(e.pkg);
    if (!isBareFilename(e.file)) p.push(`Filename '${e.file}' must be a bare name`);
    if (seenFile.has(e.file)) p.push(`Filename '${e.file}' is used twice`);
    seenFile.add(e.file);
  }
  return p;
}

/**
 * A starter set of the apps a budget-Android user in G Launcher's markets
 * actually has on the home screen. Third-party package names are stable across
 * OEMs; system apps (camera, dialer, gallery) are deliberately absent because
 * their packages differ per Infinix/Tecno/Xiaomi/Samsung, and a wrong mapping is
 * worse than none. Anything not here is added by typing a package name.
 */
export const COMMON_APPS: { pkg: string; label: string }[] = [
  { pkg: 'com.whatsapp', label: 'WhatsApp' },
  { pkg: 'com.whatsapp.w4b', label: 'WhatsApp Business' },
  { pkg: 'com.facebook.katana', label: 'Facebook' },
  { pkg: 'com.facebook.orca', label: 'Messenger' },
  { pkg: 'com.instagram.android', label: 'Instagram' },
  { pkg: 'com.zhiliaoapp.musically', label: 'TikTok' },
  { pkg: 'com.google.android.youtube', label: 'YouTube' },
  { pkg: 'com.google.android.gm', label: 'Gmail' },
  { pkg: 'com.android.chrome', label: 'Chrome' },
  { pkg: 'com.opera.mini.native', label: 'Opera Mini' },
  { pkg: 'com.google.android.apps.maps', label: 'Maps' },
  { pkg: 'com.android.vending', label: 'Play Store' },
  { pkg: 'com.google.android.apps.photos', label: 'Photos' },
  { pkg: 'com.spotify.music', label: 'Spotify' },
  { pkg: 'com.twitter.android', label: 'X' },
  { pkg: 'org.telegram.messenger', label: 'Telegram' },
  { pkg: 'com.snapchat.android', label: 'Snapchat' },
  { pkg: 'com.netflix.mediaclient', label: 'Netflix' },
  { pkg: 'com.lemon.lvoverseas', label: 'CapCut' },
  { pkg: 'com.truecaller', label: 'Truecaller' },
  { pkg: 'com.lenovo.anyshare.gps', label: 'SHAREit' },
  { pkg: 'com.google.android.apps.messaging', label: 'Messages' },
];
