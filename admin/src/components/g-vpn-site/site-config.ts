import 'server-only';

import { readPublicConfigValues } from '@/lib/core/remote-config';
import { DEFAULT_MIN_ANDROID, DEFAULT_PLAY_URL, type StoreId, type StoreLink } from './copy';

/**
 * The G VPN landing's settings, from Remote Config (admin: G VPN, Config).
 *
 * A key that was never created falls back to the default; a key set to an
 * empty string means "not offered" and hides that store. That difference is
 * why Play keeps working before anyone opens the Config screen, and why the
 * other stores stay hidden until a link exists.
 */

const STORE_KEYS: Record<StoreId, string> = {
  play: 'gvpn_play_url',
  appstore: 'gvpn_app_store_url',
  windows: 'gvpn_windows_url',
  macos: 'gvpn_macos_url',
};

const MIN_ANDROID_KEY = 'gvpn_min_android';

/** Order on the page: phones first, then computers. */
const STORE_ORDER: StoreId[] = ['play', 'appstore', 'windows', 'macos'];

const DEFAULT_LINKS: Partial<Record<StoreId, string>> = { play: DEFAULT_PLAY_URL };

export interface GvpnSiteConfig {
  minAndroid: string;
  stores: StoreLink[];
}

export async function readGvpnSiteConfig(): Promise<GvpnSiteConfig> {
  const values = await readPublicConfigValues([...Object.values(STORE_KEYS), MIN_ANDROID_KEY]);

  const stores = STORE_ORDER.flatMap((id): StoreLink[] => {
    const set = values[STORE_KEYS[id]];
    const href = set ?? DEFAULT_LINKS[id] ?? '';
    return href ? [{ id, href }] : [];
  });

  return {
    minAndroid: values[MIN_ANDROID_KEY] || DEFAULT_MIN_ANDROID,
    stores,
  };
}
