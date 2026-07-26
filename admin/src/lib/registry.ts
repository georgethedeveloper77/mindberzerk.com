/**
 * PHASE C5 - the app registry.
 *
 * NO `server-only` HERE, AND THAT IS THE WHOLE POINT. `catalogue.ts` is marked
 * server-only because it reads R2, so a client component that imports `AppId`
 * from it fails the build. The nav is a client component and needs to know what
 * apps exist, so the list lives here and catalogue.ts re-exports it:
 *
 *   // lib/catalogue.ts - replace the two lines that declare APPS
 *   export { APPS, type AppId } from './registry';
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
  },
];

export const MANAGED = REGISTRY.filter((a) => a.managed);

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
