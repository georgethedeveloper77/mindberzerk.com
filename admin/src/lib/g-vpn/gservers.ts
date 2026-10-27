import 'server-only';

import { createHmac } from 'node:crypto';

/**
 * G Servers: the WireGuard servers Mindberzerk runs, each with the gvpn
 * agent. The panel asks each agent for its health over the agent's own
 * signed API (HMAC-SHA256 over method, path, time and body, as the agent
 * checks), so the agent secrets stay on the panel's server.
 *
 * Configured as GVPN_GSERVERS, a JSON list:
 *   [{"name":"Frankfurt","host":"79.76.105.107","port":8443,"secret":"..."}]
 * Each secret is GVPN_AGENT_SECRET from that server's /etc/gvpn-agent.env.
 */

export interface GServerConfig {
  name: string;
  host: string;
  port?: number;
  secret: string;
}

export interface GServerHealth {
  name: string;
  host: string;
  online: boolean;
  error?: string;
  peers?: number;
  active?: number;
  rxBytes?: number;
  txBytes?: number;
  load1?: number;
  load5?: number;
  cpus?: number;
  memTotal?: number;
  memAvailable?: number;
  diskTotal?: number;
  diskFree?: number;
  uptimeSeconds?: number;
  machineUptimeSeconds?: number;
}

export function gserverConfigs(): { servers: GServerConfig[]; error: string | null } {
  const raw = process.env.GVPN_GSERVERS;
  if (!raw) return { servers: [], error: null };
  try {
    const list = JSON.parse(raw) as GServerConfig[];
    return { servers: list.filter((s) => s.host && s.secret), error: null };
  } catch {
    return { servers: [], error: 'GVPN_GSERVERS is not valid JSON' };
  }
}

async function health(s: GServerConfig): Promise<GServerHealth> {
  const path = '/health';
  const ts = Math.floor(Date.now() / 1000).toString();
  const sig = createHmac('sha256', s.secret).update(['GET', path, ts, ''].join('\n')).digest('hex');
  try {
    const res = await fetch(`http://${s.host}:${s.port ?? 8443}${path}`, {
      headers: { 'X-GVPN-Time': ts, 'X-GVPN-Sig': sig },
      cache: 'no-store',
      signal: AbortSignal.timeout(5000),
    });
    if (!res.ok) return { name: s.name, host: s.host, online: false, error: `agent answered ${res.status}` };
    return { ...(await res.json()), name: s.name, host: s.host, online: true };
  } catch (e) {
    return { name: s.name, host: s.host, online: false, error: (e as Error).message || 'unreachable' };
  }
}

/** Every configured server's health, read in parallel. Never throws. */
export async function readGServers(): Promise<{ servers: GServerHealth[]; error: string | null }> {
  const { servers, error } = gserverConfigs();
  return { servers: await Promise.all(servers.map(health)), error };
}

// ── Broker (gvpn-gservers Worker): the Oracle switch and phone rules ──

export interface BrokerSettings {
  enabled: boolean;
  access: 'everyone' | 'pro';
  limit: number;
  idleDays: number;
  /** Abuse limits on new phones; reconnecting never counts. */
  newPerIpMinute: number;
  newPerIpDay: number;
  newPerDay: number;
  maxPerServer: number;
}

export interface BrokerSummary {
  settings: BrokerSettings;
  perServer: { server_id: string; phones: number }[];
  groups: number;
}

const BROKER = process.env.GVPN_GSERVERS_API ?? 'https://gvpn-gservers.mindberzerk.workers.dev';

function brokerHeaders(): Record<string, string> {
  const t = process.env.GVPN_ADMIN_TOKEN;
  if (!t) throw new Error('GVPN_ADMIN_TOKEN is not set in the panel environment');
  return { authorization: `Bearer ${t}`, 'content-type': 'application/json' };
}

/** Settings and phone counts, or the reason they could not be read. */
export async function readBroker(): Promise<{ summary: BrokerSummary | null; error: string | null }> {
  try {
    const res = await fetch(`${BROKER}/admin/summary`, { headers: brokerHeaders(), cache: 'no-store', signal: AbortSignal.timeout(8000) });
    if (!res.ok) return { summary: null, error: `G Servers broker answered ${res.status}` };
    return { summary: (await res.json()) as BrokerSummary, error: null };
  } catch (e) {
    return { summary: null, error: (e as Error).message };
  }
}

export async function saveBroker(next: BrokerSettings): Promise<{ ok: boolean; error?: string; settings?: BrokerSettings }> {
  const res = await fetch(`${BROKER}/admin/settings`, {
    method: 'PUT',
    headers: brokerHeaders(),
    body: JSON.stringify(next),
    cache: 'no-store',
  });
  if (!res.ok) return { ok: false, error: `G Servers broker answered ${res.status}` };
  return { ok: true, settings: (await res.json()) as BrokerSettings };
}
