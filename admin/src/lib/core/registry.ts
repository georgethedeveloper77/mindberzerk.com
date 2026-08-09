/**
 * PHASE C5 - the app registry.
 *
 * NO `server-only` HERE, AND THAT IS THE WHOLE POINT. `catalogue.ts` is marked
 * server-only because it reads R2, so a client component that imports `AppId`
 * from it fails the build. The nav is a client component and needs to know what
 * apps exist, so the list lives here and catalogue.ts re-exports it:
 *
 *   // lib/catalogue.ts - replace the two lines that declare APPS
 *   export { APPS, type AppId } from '@/lib/core/registry';
 *
 * Two lists in two files would drift, and the failure mode is a nav item that
 * links to a 404 for one specific app.
 *
 * ## Managed vs listed
 *
 * `managed: true` means this panel administers the app: it has a CDN prefix, an
 * index.json, and a section in the nav. Those ids are the ones in [APPS] and the
 * only ones a route may resolve.
 *
 * `managed: false` means Mindberzerk publishes it but it is administered
 * elsewhere - its own Firebase project, its own store listing, no packs here.
 * Tryst and Fructa are listed so the publisher site and any cross-promotion read
 * one registry, and so the overview tells the truth about what exists rather
 * than only what this panel happens to touch.
 */

/** Apps this panel administers. A route segment must be one of these. */
export const APPS = ['g-launcher', 'g-recovery'] as const;
export type AppId = (typeof APPS)[number];

export type AppState = 'live' | 'build' | 'planned' | 'external';

export interface AppMeta {
  /** CDN prefix and route segment for managed apps; a stable slug otherwise. */
  id: string;
  name: string;
  /** Android application id, or null before one exists. */
  pkg: string | null;
  /** One or two characters for the mark. No image assets in the nav. */
  mark: string;
  /** Mark colour. Not used for status anywhere, so it carries no meaning. */
  tint: string;
  managed: boolean;
  state: AppState;
  /** One line, for the publisher site. Not shown in the panel chrome. */
  blurb: string;

  // ── store identity ────────────────────────────────────────────────────
  //
  // FOUR LINKS PER APP, TWO PUBLIC AND TWO PRIVATE, all derived from ids
  // rather than stored as URLs. A stored URL is a string that rots, and a
  // registry full of pasted links is a registry nobody trusts. Ids are
  // stable, so the URL shapes live in the helpers below and a path change is
  // one edit here rather than seven.
  //
  // Absent means "no such record", which is information the dashboard shows
  // rather than hides: an app with no App Store id is dimmed, not omitted.

  /** Numeric app id inside Play Console. Taken from the console URL. */
  playConsoleAppId?: string;
  /** Numeric App Store id. The same id serves the listing and Connect. */
  appStoreAppId?: string;
}

/** The Play publisher account every app of ours sits under. */
export const PLAY_DEVELOPER_ID = '8965127905950081681';

export const PLAY_DEVELOPER_URL = `https://play.google.com/store/apps/dev?id=${PLAY_DEVELOPER_ID}`;
export const APP_STORE_DEVELOPER_URL =
  'https://apps.apple.com/us/developer/george-gakuubi/id1701828476';

// ── link helpers ─────────────────────────────────────────────────────────
//
// All four return null rather than a broken URL when the id they need is
// absent. A caller that renders null as a disabled control is correct; one
// that renders a link to nowhere is not.

/** Public Play listing. Needs a package, and only once the app has shipped. */
export function playListingUrl(app: AppMeta): string | null {
  if (!app.pkg) return null;
  if (app.state === 'planned' || app.state === 'build') return null;
  return `https://play.google.com/store/apps/details?id=${app.pkg}`;
}

/** Public App Store listing. */
export function appStoreUrl(app: AppMeta): string | null {
  if (!app.appStoreAppId) return null;
  return `https://apps.apple.com/app/id${app.appStoreAppId}`;
}

/** Play Console dashboard. Private; the link only works with a session. */
export function playConsoleUrl(app: AppMeta): string | null {
  if (!app.playConsoleAppId) return null;
  return `https://play.google.com/console/u/0/developers/${PLAY_DEVELOPER_ID}/app/${app.playConsoleAppId}/app-dashboard`;
}

/** App Store Connect record. Private. */
export function appStoreConnectUrl(app: AppMeta): string | null {
  if (!app.appStoreAppId) return null;
  return `https://appstoreconnect.apple.com/apps/${app.appStoreAppId}/distribution/info`;
}

export const REGISTRY: AppMeta[] = [
  {
    id: 'g-launcher',
    name: 'G Launcher',
    pkg: 'com.mindhunter.g_launcher',
    mark: 'G',
    tint: '#e95420',
    managed: true,
    state: 'live',
    blurb:
      'A Linux desktop for your home screen. Free distros included, packs sold once.',
    playConsoleAppId: '4975715356489098445',
  },
  {
    id: 'g-recovery',
    name: 'G Recovery',
    pkg: 'com.mindhunter.g_recovery',
    mark: 'R',
    tint: '#4c8dff',
    managed: true,
    state: 'build',
    blurb:
      'Storage audit, permission review, and scheduled backup to your own home server.',
  },
  {
    id: 'g-music',
    name: 'G Music',
    pkg: 'com.mindhunter.g_music',
    mark: 'M',
    tint: '#b4407f',
    managed: false,
    state: 'live',
    blurb: 'A local player for music you already own. No upload, no account.',
  },
  {
    id: 'g-news',
    name: 'G News',
    pkg: null,
    mark: 'N',
    tint: '#d29922',
    managed: false,
    state: 'planned',
    blurb: 'Headlines you chose, in a tile that lives on your desktop.',
  },
  {
    id: 'g-editor',
    name: 'G Editor',
    pkg: null,
    mark: 'E',
    tint: '#3fb950',
    managed: false,
    state: 'planned',
    blurb: 'Photo editing that keeps the original and never phones home.',
  },
  {
    id: 'tryst',
    name: 'Tryst',
    pkg: null,
    mark: 'T',
    tint: '#8b5cf6',
    managed: false,
    state: 'external',
    blurb: 'Separate Firebase project. Listed here, administered elsewhere.',
  },
  {
    id: 'fructa',
    name: 'Fructa',
    pkg: null,
    mark: 'F',
    tint: '#22c55e',
    managed: false,
    state: 'external',
    blurb: 'Separate Firebase project. Listed here, administered elsewhere.',
    // CONFIRM THIS ID BEFORE TRUSTING THE LINK. It came from an App Store
    // Connect URL pasted as an example of the shape, not as a statement that it
    // is Fructa's. Check it in Connect; a wrong id here links to another app's
    // record, which is worse than no link at all.
    appStoreAppId: '6789087329',
  },
];

export const MANAGED = REGISTRY.filter((a) => a.managed);

/**
 * WHICH PACK TYPES AN APP CAN PUBLISH BY HAND.
 *
 * `KNOWN_PACK_TYPES` in `sign.ts` is the union across every app and is the gate:
 * this is only what the upload form OFFERS. The two lists diverging is
 * deliberate, because the form offered `theme, brand, hero, icon` to every app,
 * which meant G Recovery could not publish a registry through the escape hatch
 * at all while being invited to publish an icon pack it has no renderer for.
 *
 * Strings rather than the `PackType` union, because `sign.ts` is server-only and
 * the upload form is a client component. `isSafeSku` keeps its own copy of a
 * regex for the same reason: a validator the browser can reach is not a gate.
 *
 * Anything not listed here is still publishable through the API. This is the
 * menu, not the lock.
 */
export function packTypesFor(app: string): string[] {
  switch (app) {
    case 'g-launcher':
      return ['theme', 'brand', 'hero', 'icon'];
    case 'g-recovery':
      return ['registry', 'article', 'guide'];
    default:
      return ['theme', 'brand', 'hero', 'icon', 'registry', 'article', 'guide'];
  }
}

/**
 * The minimum app version the upload form starts at.
 *
 * ZERO MEANS EVERY INSTALL, which is the right default and was not what the
 * form did: it hardcoded 6, G Launcher's current build number, so a G Recovery
 * pack published through this screen would have been withheld from every device
 * below version 6 of an app whose current version is 2. A pack nobody receives
 * is indistinguishable from a pack that was never published.
 */
export function minAppVersionFor(app: string): string {
  return app === 'g-launcher' ? '6' : '0';
}

export function isAppId(value: string): value is AppId {
  return (APPS as readonly string[]).includes(value);
}

export function appMeta(id: string): AppMeta | undefined {
  return REGISTRY.find((a) => a.id === id);
}

/** Display name, falling back to the id so a missing row never renders blank. */
export function appName(id: string): string {
  return appMeta(id)?.name ?? id;
}
