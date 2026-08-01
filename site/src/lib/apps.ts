import type { AppMeta, AppState } from './registry';

/**
 * Client-safe derivations from the registry, shared by the featured module and
 * the catalogue. No 'server-only' here on purpose: the rotator and the filter
 * grid run in the browser and need these.
 */

export const PLAY_DEV_URL = 'https://play.google.com/store/apps/dev?id=8965127905950081681';
export const APP_STORE_DEV_URL = 'https://apps.apple.com/us/developer/george-gakuubi/id1701828476';

/** A Play listing link, only when the registry can actually provide one. */
export function playUrl(app: AppMeta): string | null {
  if (app.state !== 'live' || !app.pkg) return null;
  return `https://play.google.com/store/apps/details?id=${app.pkg}`;
}

/**
 * What the public reads. 'external' means administered outside the panel, which
 * is an internal distinction; to a visitor those apps are simply live.
 */
export function stateLabel(state: AppState): string {
  switch (state) {
    case 'live':
    case 'external':
      return 'Live';
    case 'build':
      return 'In development';
    case 'planned':
      return 'Planned';
  }
}

export function isComing(state: AppState): boolean {
  return state === 'build' || state === 'planned';
}
