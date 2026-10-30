import 'server-only';

import type { LiveCountry, LiveGServer, LiveSnapshot } from './live-types';
import { countryPoint } from './world';

/**
 * Live server numbers for the landing, from the two public Worker lists the
 * app itself reads: the free list (VPN Gate and OneConnect) and our own G
 * Servers. Each is cached for a minute and read independently, so one source
 * failing never hides the other. Server addresses in the G Servers answer are
 * dropped here and never reach the page.
 */

const COMMUNITY_URL = 'https://gvpn-servers.mindberzerk.workers.dev/community';
const GSERVERS_URL = 'https://gvpn-gservers.mindberzerk.workers.dev/servers';
const REVALIDATE_SECONDS = 60;

const ISO = /^[A-Z]{2}$/;

async function readFree(): Promise<LiveSnapshot['free']> {
  try {
    const res = await fetch(COMMUNITY_URL, { next: { revalidate: REVALIDATE_SECONDS } });
    if (!res.ok) return null;
    const body = (await res.json()) as { servers?: { countryCode?: unknown }[] };
    const list = Array.isArray(body.servers) ? body.servers : [];
    if (list.length === 0) return null;

    const counts = new Map<string, number>();
    for (const s of list) {
      if (typeof s.countryCode === 'string' && ISO.test(s.countryCode)) {
        counts.set(s.countryCode, (counts.get(s.countryCode) ?? 0) + 1);
      }
    }
    const countries: LiveCountry[] = [];
    for (const [code, count] of [...counts.entries()].sort((a, b) => b[1] - a[1])) {
      const p = countryPoint(code);
      if (p) countries.push({ code, count, x: p[0], y: p[1] });
    }
    return { servers: list.length, countries };
  } catch {
    return null;
  }
}

async function readGServers(): Promise<LiveGServer[]> {
  try {
    const res = await fetch(GSERVERS_URL, { next: { revalidate: REVALIDATE_SECONDS } });
    if (!res.ok) return [];
    const body = (await res.json()) as {
      enabled?: unknown;
      servers?: { city?: unknown; name?: unknown; country?: unknown; online?: unknown }[];
    };
    if (body.enabled !== true || !Array.isArray(body.servers)) return [];
    return body.servers.map((s) => {
      const country = typeof s.country === 'string' && ISO.test(s.country.toUpperCase()) ? s.country.toUpperCase() : '';
      const p = country ? countryPoint(country) : null;
      return {
        city: String(s.city ?? s.name ?? ''),
        country,
        online: s.online === true,
        x: p?.[0] ?? null,
        y: p?.[1] ?? null,
      };
    });
  } catch {
    return [];
  }
}

export async function readLiveSnapshot(): Promise<LiveSnapshot> {
  const [free, gservers] = await Promise.all([readFree(), readGServers()]);
  return { free, gservers, at: new Date().toISOString() };
}
