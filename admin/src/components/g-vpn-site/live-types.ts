/**
 * The live server snapshot the landing renders and polls. Shared by the
 * server reader, the public API route and the client store, so all three
 * agree on one shape. Map positions are resolved on the server, which holds
 * the country centres, so the browser never needs the map file.
 */

export interface LiveCountry {
  /** ISO 3166-1 alpha-2. */
  code: string;
  /** Free servers listed in the app for this country. */
  count: number;
  x: number;
  y: number;
}

export interface LiveGServer {
  city: string;
  /** ISO code, or empty when the server entry has none. */
  country: string;
  online: boolean;
  x: number | null;
  y: number | null;
}

export interface LiveSnapshot {
  /** Null when the free list could not be read. */
  free: { servers: number; countries: LiveCountry[] } | null;
  /** Our own servers; empty when they are switched off or unreadable. */
  gservers: LiveGServer[];
  /** When this snapshot was assembled, ISO 8601. */
  at: string;
}

/** How often an open page refreshes the snapshot. */
export const LIVE_POLL_MS = 60_000;

/** The public route that serves the snapshot to open pages. */
export const LIVE_ROUTE = '/api/g-vpn/live';
