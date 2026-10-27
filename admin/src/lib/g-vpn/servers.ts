import 'server-only';

/**
 * G VPN'S SERVER LIST, READ AND STEERED IN THE WORKER.
 *
 * The list is built by the `gvpn-servers` Cloudflare Worker every two hours
 * from its sources (VPN Gate, OneConnect). The panel never edits the list
 * itself: it edits the OVERRIDES the Worker applies on every refresh, then
 * asks for a refresh, so the published list and the panel cannot disagree.
 *
 * The admin token is the Worker's REFRESH_TOKEN secret, held here as
 * GVPN_ADMIN_TOKEN and never sent to the browser: client components call the
 * panel's own route, which calls the Worker.
 */

export type Grade = 'fast' | 'good' | 'slow';
export type Source = 'vpngate' | 'oneconnect';

export interface AdminServer {
  id: string;
  ip: string;
  host: string;
  proto: 'udp' | 'tcp';
  port: number;
  source: Source;
  country: string;
  countryCode: string;
  /** Present when the server takes SSTP and SSTP is on. */
  sstpHost?: string;
  sstpPort?: number;
  speedMbps: number;
  pingMs: number;
  sessions: number;
  uptimeDays: number;
  quality: number;
  grade: Grade;
  pinned: boolean;
  hidden: boolean;
  /** Null when hidden (not checked). */
  reachable: boolean | null;
  listed: boolean;
}

export interface SourceHealth {
  ok: boolean;
  off?: boolean;
  count?: number;
  /** OneConnect configs that were not readable OpenVPN text. */
  skipped?: number;
  /** VPN Gate servers whose SSTP address was found. */
  sstp?: number;
  sstpError?: string;
  error?: string;
}

export interface Overrides {
  sources: { vpngate: boolean; oneconnect: boolean };
  /** How the app connects to free servers; at least one stays on. */
  protocols: { openvpn: boolean; sstp: boolean };
  thresholds: { fast: number; good: number };
  hiddenServers: string[];
  pinnedServers: string[];
  hiddenCountries: string[];
  boosts: Record<string, number>;
}

export interface VpnState {
  updatedAt: string | null;
  sources: Partial<Record<Source, SourceHealth>>;
  servers: AdminServer[];
  overrides: Overrides;
  oneconnectKey: boolean;
  /** Set when the Worker could not be read; every figure is then absent. */
  unreachable: string | null;
}

const BASE = process.env.GVPN_SERVERS_URL ?? 'https://gvpn-servers.mindberzerk.workers.dev';

function token(): string {
  const t = process.env.GVPN_ADMIN_TOKEN;
  if (!t) throw new Error('GVPN_ADMIN_TOKEN is not set in the panel environment');
  return t;
}

async function call(path: string, init: RequestInit = {}): Promise<Response> {
  return fetch(`${BASE}${path}`, {
    ...init,
    cache: 'no-store',
    headers: { ...(init.headers ?? {}), authorization: `Bearer ${token()}` },
  });
}

const EMPTY: Omit<VpnState, 'unreachable'> = {
  updatedAt: null,
  sources: {},
  servers: [],
  overrides: {
    sources: { vpngate: true, oneconnect: true },
    protocols: { openvpn: true, sstp: true },
    thresholds: { fast: 70, good: 45 },
    hiddenServers: [],
    pinnedServers: [],
    hiddenCountries: [],
    boosts: {},
  },
  oneconnectKey: false,
};

/** Never throws: an unreadable Worker is a named absence, not a crash. */
export async function readVpnState(): Promise<VpnState> {
  try {
    const res = await call('/admin/state');
    if (!res.ok) return { ...EMPTY, unreachable: `Worker answered ${res.status}` };
    const body = (await res.json()) as Partial<VpnState>;
    return {
      ...EMPTY,
      ...body,
      servers: body.servers ?? [],
      sources: body.sources ?? {},
      overrides: { ...EMPTY.overrides, ...(body.overrides ?? {}), protocols: body.overrides?.protocols ?? EMPTY.overrides.protocols },
      unreachable: null,
    };
  } catch (e) {
    return { ...EMPTY, unreachable: (e as Error).message || 'The Worker could not be reached.' };
  }
}

export async function saveOverrides(o: Overrides): Promise<{ ok: boolean; error?: string }> {
  const res = await call('/admin/overrides', {
    method: 'PUT',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify(o),
  });
  return res.ok ? { ok: true } : { ok: false, error: `Worker answered ${res.status}` };
}

export async function refreshNow(): Promise<{ ok: boolean; servers?: number; error?: string }> {
  const res = await call('/refresh', { method: 'POST' });
  const body = (await res.json().catch(() => ({}))) as { servers?: number; error?: string };
  return res.ok ? { ok: true, servers: body.servers } : { ok: false, error: body.error ?? `Worker answered ${res.status}` };
}
