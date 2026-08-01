/**
 * The app registry: what G Launcher knows about the apps it can theme, link to,
 * and group. Pure and client-safe so the editor validates in the browser and the
 * server writes the same shape.
 *
 * Stored UNSIGNED on R2, the same pattern as site/content.json. It is not a pack
 * and never reaches a device through the verified pipeline; it feeds the panel
 * (icon-pack targets, the publisher grouping that answers "are Tryst and Fructa
 * the same publisher") and, later, the news and launcher metadata.
 */

export interface RegistryApp {
  /** Android application id. The stable key. */
  pkg: string;
  name: string;
  /** Who ships it. The field the same-publisher question is answered from. */
  publisher: string;
  /** Optional store links and a one-line description. */
  playUrl: string;
  appStoreUrl: string;
  about: string;
}

const PACKAGE = /^[a-zA-Z][a-zA-Z0-9_]*(\.[a-zA-Z][a-zA-Z0-9_]*)+$/;

export function isValidPackage(pkg: string): boolean {
  return PACKAGE.test(pkg) && pkg.length <= 200;
}

/** Empty-or-https. A store link is optional, but if present it must be a URL. */
export function isOkUrl(u: string): boolean {
  if (!u.trim()) return true;
  try {
    const parsed = new URL(u.trim());
    return parsed.protocol === 'https:';
  } catch {
    return false;
  }
}

export function blankApp(): RegistryApp {
  return { pkg: '', name: '', publisher: '', playUrl: '', appStoreUrl: '', about: '' };
}

/** Problems for one row. Empty array = valid. */
export function validateApp(app: RegistryApp, others: RegistryApp[]): string[] {
  const p: string[] = [];
  if (!isValidPackage(app.pkg)) p.push('package is not a valid Android application id');
  else if (others.some((o) => o !== app && o.pkg === app.pkg)) p.push('package is listed twice');
  if (!app.name.trim()) p.push('name is required');
  if (!isOkUrl(app.playUrl)) p.push('Play URL must be https or blank');
  if (!isOkUrl(app.appStoreUrl)) p.push('App Store URL must be https or blank');
  return p;
}

export function validateRegistry(apps: RegistryApp[]): string[] {
  const problems: string[] = [];
  apps.forEach((a, i) => {
    for (const m of validateApp(a, apps)) problems.push(`${a.pkg || `row ${i + 1}`}: ${m}`);
  });
  return problems;
}

/** A starter set for a first, empty registry. The panel seeds from the app's own
 *  hardcoded REGISTRY when that is wired; until then this gets a bucket going. */
export const STARTER_APPS: RegistryApp[] = [
  { pkg: 'com.whatsapp', name: 'WhatsApp', publisher: 'Meta', playUrl: '', appStoreUrl: '', about: '' },
  { pkg: 'com.instagram.android', name: 'Instagram', publisher: 'Meta', playUrl: '', appStoreUrl: '', about: '' },
  { pkg: 'com.facebook.katana', name: 'Facebook', publisher: 'Meta', playUrl: '', appStoreUrl: '', about: '' },
  { pkg: 'com.zhiliaoapp.musically', name: 'TikTok', publisher: 'ByteDance', playUrl: '', appStoreUrl: '', about: '' },
  { pkg: 'com.google.android.youtube', name: 'YouTube', publisher: 'Google', playUrl: '', appStoreUrl: '', about: '' },
  { pkg: 'com.spotify.music', name: 'Spotify', publisher: 'Spotify', playUrl: '', appStoreUrl: '', about: '' },
  { pkg: 'org.telegram.messenger', name: 'Telegram', publisher: 'Telegram', playUrl: '', appStoreUrl: '', about: '' },
  { pkg: 'com.opera.mini.native', name: 'Opera Mini', publisher: 'Opera', playUrl: '', appStoreUrl: '', about: '' },
];
