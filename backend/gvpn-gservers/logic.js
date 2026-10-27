/**
 * G Servers rules, kept free of Cloudflare APIs so they can be tested with
 * plain Node: settings, groups, the device limit and idle cleanup.
 */

export const DEFAULT_SETTINGS = {
  // The admin's Oracle switch: off hides G Servers from every phone.
  enabled: true,
  // "everyone": any phone may use G Servers. "pro": only an active Play
  // subscription, verified with Google on every registration.
  access: 'everyone',
  // Phones per group (one Pro subscription, or one phone when free).
  limit: 5,
  // Days without a connection before a phone is removed from the servers.
  idleDays: 30,
  // Abuse limits on NEW phones (reconnecting never counts). Generous per
  // address, because carriers put many real users behind one shared IP;
  // the daily total is what keeps a server's address pool from filling.
  newPerIpMinute: 5,
  newPerIpDay: 20,
  newPerDay: 500,
  maxPerServer: 1000,
};

/** Fills gaps and drops anything malformed, so a bad save cannot break the app. */
export function cleanSettings(raw) {
  const o = raw && typeof raw === 'object' ? raw : {};
  const int = (v, d, lo, hi) => (Number.isInteger(v) ? Math.min(hi, Math.max(lo, v)) : d);
  return {
    enabled: o.enabled !== false,
    access: o.access === 'pro' ? 'pro' : 'everyone',
    limit: int(o.limit, DEFAULT_SETTINGS.limit, 1, 20),
    idleDays: int(o.idleDays, DEFAULT_SETTINGS.idleDays, 7, 365),
    newPerIpMinute: int(o.newPerIpMinute, DEFAULT_SETTINGS.newPerIpMinute, 1, 60),
    newPerIpDay: int(o.newPerIpDay, DEFAULT_SETTINGS.newPerIpDay, 1, 1000),
    newPerDay: int(o.newPerDay, DEFAULT_SETTINGS.newPerDay, 1, 100000),
    maxPerServer: int(o.maxPerServer, DEFAULT_SETTINGS.maxPerServer, 10, 60000),
  };
}

export const KEY_RE = /^[A-Za-z0-9+/]{43}=$/;

/** Busy, 0 to 100: the one-minute load average as a share of the CPUs. */
export function busyPercent(health) {
  if (!health?.cpus) return null;
  return Math.max(0, Math.min(100, Math.round((health.load1 / health.cpus) * 100)));
}

/**
 * The subscription a Play order belongs to: renewals add "..N" to the first
 * order id, so the part before ".." stays the same for its whole life.
 */
export function orderRoot(orderId) {
  return typeof orderId === 'string' && orderId ? orderId.split('..')[0] : null;
}

/** Whether a group may add one more phone (the asking phone not counted). */
export function hasRoom(othersInGroup, limit) {
  return othersInGroup < limit;
}

/**
 * When a phone last used its key: the newest of the WireGuard handshake the
 * server saw (seconds), the last time the app said hello (ms) and the day it
 * was added (ms), so a phone added but never connected also ages out.
 */
export function lastActive(handshakeSec, row) {
  return Math.max((handshakeSec || 0) * 1000, row?.last_seen || 0, row?.created_at || 0);
}

export function isIdle(handshakeSec, row, now, idleDays) {
  return now - lastActive(handshakeSec, row) > idleDays * 86_400_000;
}

/** A WireGuard key in a URL path: '/' and '+' would break the path. */
export function keyToPath(key) {
  return key.replace(/\+/g, '-').replace(/\//g, '_');
}

export function keyFromPath(path) {
  return path.replace(/-/g, '+').replace(/_/g, '/');
}

/** Minimal HTTP/1.1 response parsing for the agent's small JSON replies. */
export function parseHttpResponse(text) {
  const split = text.indexOf('\r\n\r\n');
  if (split < 0) throw new Error('agent: malformed response');
  const head = text.slice(0, split);
  const status = Number(/^HTTP\/1\.[01] (\d{3})/.exec(head)?.[1] ?? 0);
  let body = text.slice(split + 4);
  if (/transfer-encoding:\s*chunked/i.test(head)) {
    let out = '';
    let rest = body;
    for (;;) {
      const nl = rest.indexOf('\r\n');
      const size = parseInt(rest.slice(0, nl), 16);
      if (!size) break;
      out += rest.slice(nl + 2, nl + 2 + size);
      rest = rest.slice(nl + 2 + size + 2);
    }
    body = out;
  }
  return { status, body };
}

/** UTC day, for the per-address counters that are wiped every day. */
export function dayKey(now) {
  return new Date(now).toISOString().slice(0, 10);
}

/**
 * Which limit, if any, stops one more NEW phone. Checked in order of cost
 * to the server: a full server first, then the day's total, then the
 * address's day and minute.
 */
export function newPhoneBlock({ onServer, newToday, fromIpToday, fromIpMinute }, s) {
  if (onServer >= s.maxPerServer) return 'server_full';
  if (newToday >= s.newPerDay) return 'busy';
  if (fromIpToday >= s.newPerIpDay) return 'busy';
  if (fromIpMinute >= s.newPerIpMinute) return 'busy';
  return null;
}
