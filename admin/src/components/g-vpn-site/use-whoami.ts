'use client';

import { useEffect, useState } from 'react';
import { WHOAMI_URL } from './copy';

/**
 * What the internet sees for this visitor, from the gvpn-whoami Worker.
 *
 * One request per page load however many components ask: the promise is
 * shared at module level. `undefined` while loading, `null` when the lookup
 * failed (offline, blocked, CORS not deployed), so callers can hide rather
 * than fill in a stand-in.
 */

export interface Whoami {
  ip: string;
  city: string | null;
  country: string | null;
  latitude: number | null;
  longitude: number | null;
}

const TIMEOUT_MS = 5000;
let pending: Promise<Whoami | null> | null = null;

function lookup(): Promise<Whoami | null> {
  pending ??= (async () => {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), TIMEOUT_MS);
    try {
      const res = await fetch(WHOAMI_URL, { signal: controller.signal, cache: 'no-store' });
      if (!res.ok) return null;
      const b = (await res.json()) as Record<string, unknown>;
      if (typeof b.ip !== 'string' || !b.ip) return null;
      const num = (v: unknown) => (typeof v === 'number' && Number.isFinite(v) ? v : null);
      const str = (v: unknown) => (typeof v === 'string' && v.trim() ? v.trim() : null);
      return { ip: b.ip, city: str(b.city), country: str(b.country), latitude: num(b.latitude), longitude: num(b.longitude) };
    } catch {
      return null;
    } finally {
      clearTimeout(timer);
    }
  })();
  return pending;
}

export function useWhoami(): Whoami | null | undefined {
  const [value, setValue] = useState<Whoami | null | undefined>(undefined);
  useEffect(() => {
    let live = true;
    lookup().then((v) => {
      if (live) setValue(v);
    });
    return () => {
      live = false;
    };
  }, []);
  return value;
}

/** "Nairobi, Kenya" from Cloudflare's city plus ISO country code. */
export function describeLocation(w: Pick<Whoami, 'city' | 'country'>): string | null {
  const code = w.country && /^[A-Z]{2}$/.test(w.country) ? w.country : null;
  let name: string | null = code;
  if (code) {
    try {
      name = new Intl.DisplayNames(['en'], { type: 'region' }).of(code) ?? code;
    } catch {
      // Older engines without DisplayNames keep the bare code.
    }
  }
  if (w.city && name) return `${w.city}, ${name}`;
  return w.city ?? name;
}
