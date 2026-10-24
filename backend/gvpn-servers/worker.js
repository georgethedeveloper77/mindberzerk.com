/**
 * gvpn-servers: the Community server list for G VPN.
 *
 *   GET /community            ranked list, no configs (small, cacheable)
 *   GET /community/<id>.ovpn  one server's OpenVPN config, fetched at connect
 *   POST /refresh             refresh now                        } admin token:
 *   GET  /admin/state         every server, flags, source health } the
 *   PUT  /admin/overrides     pins, hides, boosts, thresholds     } REFRESH_TOKEN
 *                                                                   secret
 *
 * Sources: VPN Gate (public list) and OneConnect (needs the ONECONNECT_KEY
 * secret). The admin panel's overrides are applied on every refresh.
 *
 * A cron refreshes from VPN Gate every two hours and stores the result in KV,
 * so phones never hit VPN Gate directly and a VPN Gate outage only means the
 * last good list keeps being served.
 */
import { connect } from 'cloudflare:sockets';
import { applyOverrides, capPerCountry, cleanOverrides, fromOneConnect, parseVpnGate, rank } from './rank.js';

const SOURCE = 'http://www.vpngate.net/api/iphone/';
const LIST_KEY = 'community:list';
const ALL_KEY = 'community:all';
const OVERRIDES_KEY = 'admin:overrides';
const ONECONNECT_URL = 'https://developer.oneconnect.top/view/front/controller.php';
const CONFIG_TTL = 6 * 3600; // configs outlive a couple of failed refreshes

// Reachability probe. Workers allow a limited number of outbound connections
// per run, so only the best-ranked candidates are tested, a few at a time.
const PROBE_BUDGET = 45;
const PROBE_PARALLEL = 5;
const PROBE_TIMEOUT_MS = 4000;

export default {
  async scheduled(_event, env, ctx) {
    ctx.waitUntil(refresh(env));
  },

  async fetch(request, env) {
    const url = new URL(request.url);

    if (url.pathname === '/refresh' || url.pathname.startsWith('/admin/')) {
      if (!(await authorised(request, env))) return json({ error: 'unauthorised' }, 401);

      if (url.pathname === '/refresh' && request.method === 'POST') {
        const count = await refresh(env);
        return json({ ok: true, servers: count });
      }
      if (url.pathname === '/admin/state' && request.method === 'GET') {
        const all = JSON.parse((await env.SERVERS.get(ALL_KEY)) ?? '{}');
        const overrides = cleanOverrides(JSON.parse((await env.SERVERS.get(OVERRIDES_KEY)) ?? '{}'));
        return json({ ...all, overrides, oneconnectKey: !!env.ONECONNECT_KEY });
      }
      if (url.pathname === '/admin/overrides' && request.method === 'PUT') {
        let body;
        try {
          body = await request.json();
        } catch {
          return json({ error: 'bad json' }, 400);
        }
        const overrides = cleanOverrides(body);
        await env.SERVERS.put(OVERRIDES_KEY, JSON.stringify(overrides));
        return json({ ok: true, overrides });
      }
      return json({ error: 'not found' }, 404);
    }

    if (request.method !== 'GET') return json({ error: 'method' }, 405);

    if (url.pathname === '/community') {
      const list = await env.SERVERS.get(LIST_KEY);
      if (!list) return json({ error: 'not ready' }, 503);
      return new Response(list, {
        headers: { 'content-type': 'application/json', 'cache-control': 'public, max-age=600' },
      });
    }

    const m = /^\/community\/([0-9a-f]{12})\.ovpn$/.exec(url.pathname);
    if (m) {
      const config = await env.SERVERS.get(`community:config:${m[1]}`);
      if (!config) return json({ error: 'gone' }, 404);
      return new Response(config, {
        headers: { 'content-type': 'application/x-openvpn-profile', 'cache-control': 'public, max-age=3600' },
      });
    }

    return json({ error: 'not found' }, 404);
  },
};

async function refresh(env) {
  const overrides = cleanOverrides(JSON.parse((await env.SERVERS.get(OVERRIDES_KEY)) ?? '{}'));
  const sources = {};
  const rows = [];

  if (overrides.sources.vpngate) {
    try {
      const res = await fetch(SOURCE, { cf: { cacheTtl: 0 } });
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      const found = parseVpnGate(await res.text());
      rows.push(...found);
      sources.vpngate = { ok: true, count: found.length };
    } catch (e) {
      sources.vpngate = { ok: false, error: String(e.message ?? e) };
    }
  } else {
    sources.vpngate = { ok: true, off: true, count: 0 };
  }

  if (!overrides.sources.oneconnect) {
    sources.oneconnect = { ok: true, off: true, count: 0 };
  } else if (!env.ONECONNECT_KEY) {
    sources.oneconnect = { ok: false, error: 'ONECONNECT_KEY secret not set' };
  } else {
    try {
      const res = await fetch(ONECONNECT_URL, {
        method: 'POST',
        headers: { 'content-type': 'application/x-www-form-urlencoded' },
        body: new URLSearchParams({
          package_name: env.ONECONNECT_PACKAGE ?? 'com.mindberzerk.gvpn',
          api_key: env.ONECONNECT_KEY,
          action: 'fetchUserServers',
          type: 'free',
        }),
      });
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      const text = await res.text();
      let body;
      try {
        body = JSON.parse(text);
      } catch {
        throw new Error(`Not JSON: ${text.slice(0, 160)}`);
      }
      // A refusal (bad key, package mismatch, no servers on the plan) comes
      // back as an object or a string, not a list. Say what it said rather
      // than report "0 servers" as if all were well.
      if (!Array.isArray(body)) throw new Error(`OneConnect said: ${JSON.stringify(body).slice(0, 160)}`);
      const { rows: found, skipped } = fromOneConnect(body);
      rows.push(...found);
      sources.oneconnect = body.length === 0
        ? { ok: false, count: 0, error: 'OneConnect returned an empty list: no free servers on this account, or the package name does not match' }
        : { ok: true, count: found.length, skipped };
    } catch (e) {
      sources.oneconnect = { ok: false, error: String(e.message ?? e) };
    }
  }

  const decided = applyOverrides(await rank(rows), overrides);
  const reachable = await keepReachable(decided.filter((s) => !s.hidden));
  const reachableIds = new Set(reachable.map((s) => s.id));
  const listed = capPerCountry(reachable);
  if (listed.length === 0) throw new Error('No reachable servers; keeping the last good list');
  const listedIds = new Set(listed.map((s) => s.id));

  // Write a config only when it changed (or is near expiry): the free KV plan
  // allows 1,000 writes a day, and reads are a hundred times cheaper.
  await Promise.all(
    listed.map(async (s) => {
      const key = `community:config:${s.id}`;
      const { value, metadata } = await env.SERVERS.getWithMetadata(key);
      const fresh = metadata?.writtenAt && Date.now() - metadata.writtenAt < (CONFIG_TTL * 1000) / 2;
      if (value === s.config && fresh) return;
      await env.SERVERS.put(key, s.config, { expirationTtl: CONFIG_TTL, metadata: { writtenAt: Date.now() } });
    }),
  );
  const updatedAt = new Date().toISOString();
  await env.SERVERS.put(LIST_KEY, JSON.stringify({
    source: 'community',
    updatedAt,
    // Shown in the app: honest labelling of who runs these and what they keep.
    notice: 'Volunteer servers from the VPN Gate academic project, whose operators keep connection logs for '
      + 'about two weeks, and partner servers from OneConnect.',
    servers: listed.map(({ config, hidden, ...rest }) => rest),
  }));
  // Everything, including hidden and unreachable servers, for the admin panel.
  await env.SERVERS.put(ALL_KEY, JSON.stringify({
    updatedAt,
    sources,
    servers: decided.map(({ config, ...rest }) => ({
      ...rest,
      reachable: rest.hidden ? null : reachableIds.has(rest.id),
      listed: listedIds.has(rest.id),
    })),
  }));
  return listed.length;
}

async function authorised(request, env) {
  const token = request.headers.get('authorization') ?? '';
  return !!env.REFRESH_TOKEN && (await sameSecret(token, `Bearer ${env.REFRESH_TOKEN}`));
}

/**
 * Drops servers nobody can connect to. VPN Gate keeps listing some (behind a
 * firewall, or a home connection that changed) as fast; a phone would wait
 * and fail. TCP servers are tested with a real connection; UDP cannot be
 * tested from a Worker, so UDP servers pass through untested.
 */
async function keepReachable(ranked) {
  const kept = [];
  let probes = 0;
  for (let i = 0; i < ranked.length; i += PROBE_PARALLEL) {
    const batch = ranked.slice(i, i + PROBE_PARALLEL);
    const results = await Promise.all(
      batch.map(async (s) => {
        if (s.proto !== 'tcp') return { s, ok: true, verified: false };
        if (probes >= PROBE_BUDGET) return { s, ok: false, verified: false };
        probes++;
        return { s, ok: await tcpReachable(s.ip, s.port), verified: true };
      }),
    );
    // Once the budget is spent, TCP servers further down the ranking stay
    // unlisted rather than listed unchecked.
    for (const { s, ok, verified } of results) if (ok) kept.push({ ...s, verified });
  }
  return kept;
}

async function tcpReachable(hostname, port) {
  let socket;
  try {
    socket = connect({ hostname, port });
    const timeout = new Promise((resolve) => setTimeout(() => resolve(false), PROBE_TIMEOUT_MS));
    return await Promise.race([socket.opened.then(() => true, () => false), timeout]);
  } catch {
    // Includes Cloudflare's own address ranges, which Workers may not dial;
    // a server there is the same WARP case that phones cannot reach either.
    return false;
  } finally {
    socket?.close().catch(() => {});
  }
}

/** Constant-time comparison via hashing, so the token cannot be guessed byte by byte. */
async function sameSecret(a, b) {
  const enc = new TextEncoder();
  const [ha, hb] = await Promise.all([
    crypto.subtle.digest('SHA-256', enc.encode(a)),
    crypto.subtle.digest('SHA-256', enc.encode(b)),
  ]);
  const x = new Uint8Array(ha), y = new Uint8Array(hb);
  let diff = 0;
  for (let i = 0; i < x.length; i++) diff |= x[i] ^ y[i];
  return diff === 0;
}

function json(body, status = 200) {
  return new Response(JSON.stringify(body), { status, headers: { 'content-type': 'application/json' } });
}
