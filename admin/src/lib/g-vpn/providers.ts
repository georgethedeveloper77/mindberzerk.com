import 'server-only';

/**
 * Internet providers from the gvpn-providers Worker: each provider the app
 * has seen (by network number), the brand details set here, and what users
 * rated it. Same admin token as the other G VPN Workers (GVPN_ADMIN_TOKEN).
 */

export interface ProviderRow {
  asn: number;
  /** As Cloudflare names it, cleaned ("Safaricom"). */
  org: string;
  country: string | null;
  name: string | null;
  color: string | null;
  logo: string | null;
  phone: string | null;
  website: string | null;
  outages: string | null;
  hidden: number;
  ratings: number;
  average: number | null;
  /** Installs that used it this month or last. */
  users: number;
  cities: number;
  first_seen: number;
}

export interface ProvidersState {
  providers: ProviderRow[];
  unreachable: string | null;
}

/** What the admin can set for a provider. */
export interface ProviderEdit {
  name: string;
  color: string;
  logo: string;
  phone: string;
  website: string;
  outages: string;
  hidden: boolean;
}

export const PROVIDERS_BASE = process.env.GVPN_PROVIDERS_URL ?? 'https://gvpn-providers.mindberzerk.workers.dev';

/** Never throws: an unreadable Worker is a named absence, not an empty list. */
export async function readProviders(): Promise<ProvidersState> {
  const token = process.env.GVPN_ADMIN_TOKEN;
  if (!token) return { providers: [], unreachable: 'GVPN_ADMIN_TOKEN is not set' };
  try {
    const res = await fetch(`${PROVIDERS_BASE}/admin/providers`, {
      cache: 'no-store',
      headers: { authorization: `Bearer ${token}` },
    });
    if (!res.ok) return { providers: [], unreachable: `Worker answered ${res.status}` };
    const body = (await res.json()) as { providers?: ProviderRow[] };
    return { providers: body.providers ?? [], unreachable: null };
  } catch (e) {
    return { providers: [], unreachable: (e as Error).message || 'The Worker could not be reached.' };
  }
}
