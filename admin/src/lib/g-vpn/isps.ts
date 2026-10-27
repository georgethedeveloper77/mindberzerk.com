import 'server-only';

/**
 * Provider rankings from the gvpn-isps Worker: direct speed tests from G VPN
 * users, grouped by country and provider, medians over the last 30 days.
 * Same admin token as the server list (GVPN_ADMIN_TOKEN).
 */

export interface IspRow {
  isp: string;
  tests: number;
  down: number;
  up: number;
  ping: number;
  rank: number;
}

export interface IspCountry {
  country: string;
  tests: number;
  cities: number;
  providers: IspRow[];
}

export interface IspState {
  windowDays: number;
  totalTests: number;
  countries: IspCountry[];
  unreachable: string | null;
}

const BASE = process.env.GVPN_ISPS_URL ?? 'https://gvpn-isps.mindberzerk.workers.dev';

/** Never throws: an unreadable Worker is a named absence, not zeros. */
export async function readIsps(): Promise<IspState> {
  const empty = { windowDays: 30, totalTests: 0, countries: [] };
  const token = process.env.GVPN_ADMIN_TOKEN;
  if (!token) return { ...empty, unreachable: 'GVPN_ADMIN_TOKEN is not set' };
  try {
    const res = await fetch(`${BASE}/admin/isps`, { cache: 'no-store', headers: { authorization: `Bearer ${token}` } });
    if (!res.ok) return { ...empty, unreachable: `Worker answered ${res.status}` };
    return { ...empty, ...((await res.json()) as Partial<IspState>), unreachable: null };
  } catch (e) {
    return { ...empty, unreachable: (e as Error).message || 'The Worker could not be reached.' };
  }
}
