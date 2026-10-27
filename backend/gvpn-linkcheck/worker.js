/**
 * gvpn-linkcheck: "is this link safe?" for G VPN's Tools.
 *
 * Unfolds redirects (short links), then asks Cloudflare's security
 * resolver (1.1.1.2, malware and phishing) about every host on the way.
 * It answers 0.0.0.0 for a host on its block lists. Free, no key, no
 * account, no billing: the same kind of check Shield makes while connected.
 *
 * Privacy: links are never stored or logged (observability is off). D1
 * keeps only a per-phone hourly counter, keyed by a hash of IP and hour.
 *
 * Bindings: DB (D1, schema.sql).
 */

const PER_IP_HOUR = 30; // checks per phone per hour
const MAX_HOPS = 5;
const CACHE_SECONDS = 6 * 3600;
const RESOLVER = 'https://security.cloudflare-dns.com/dns-query';

const json = (body, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { 'content-type': 'application/json', 'cache-control': 'no-store' },
  });

export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);
    if (url.pathname !== '/check' || request.method !== 'POST') {
      return json({ error: 'not_found' }, 404);
    }

    let link;
    try {
      link = normalise((await request.json()).url);
    } catch {
      link = null;
    }
    if (!link) return json({ error: 'invalid' }, 400);

    if (!(await allow(env, request))) return json({ error: 'busy' }, 429);

    try {
      const hops = await unfold(link);
      let verdict = 'clear';
      for (const hop of hops) {
        const found = await lookup(ctx, new URL(hop).hostname);
        if (found === 'blocked') {
          verdict = 'danger';
          break;
        }
        // The first host not existing at all is worth saying; later ones
        // cannot be reached anyway.
        if (found === 'missing' && hop === hops[0]) verdict = 'missing';
      }
      return json({
        verdict,
        threats: verdict === 'danger' ? ['LISTED'] : [],
        finalUrl: hops[hops.length - 1],
        hops: hops.length - 1,
      });
    } catch {
      return json({ error: 'network' }, 502);
    }
  },
};

/** An http(s) URL with a dotted host, or null. */
function normalise(raw) {
  if (typeof raw !== 'string' || raw.length > 2048) return null;
  try {
    const u = new URL(raw.trim());
    if (!['http:', 'https:'].includes(u.protocol) || !u.hostname.includes('.')) return null;
    return u.toString();
  } catch {
    return null;
  }
}

/**
 * The link and every redirect it leads to. Requests come from Cloudflare,
 * so the destination never sees the user's address. Bodies are not read.
 */
async function unfold(link) {
  const hops = [link];
  let current = link;
  for (let i = 0; i < MAX_HOPS; i++) {
    let res;
    try {
      res = await fetch(current, {
        method: 'GET',
        redirect: 'manual',
        headers: { 'user-agent': 'Mozilla/5.0 (Linux; Android 14) G-VPN-LinkCheck' },
        signal: AbortSignal.timeout(5000),
      });
    } catch {
      break; // Unreachable: the host itself is still looked up.
    }
    res.body?.cancel();
    const next = res.headers.get('location');
    if (res.status < 300 || res.status >= 400 || !next) break;
    const resolved = normalise(new URL(next, current).toString());
    if (!resolved || hops.includes(resolved)) break;
    hops.push(resolved);
    current = resolved;
  }
  return hops;
}

/**
 * 'blocked' when the security resolver refuses [host] (it answers
 * 0.0.0.0), 'missing' when the name does not exist, else 'ok'.
 */
async function lookup(ctx, host) {
  const cache = caches.default;
  const cacheKey = new Request(`https://linkcheck.cache/v2?h=${encodeURIComponent(host)}`);
  const hit = await cache.match(cacheKey);
  if (hit) return (await hit.json()).result;

  const q = new URLSearchParams({ name: host, type: 'A' });
  const res = await fetch(`${RESOLVER}?${q}`, {
    headers: { accept: 'application/dns-json' },
    signal: AbortSignal.timeout(5000),
  });
  if (!res.ok) throw new Error(`resolver ${res.status}`);
  const body = await res.json();
  const answers = (body.Answer ?? []).filter((a) => a.type === 1).map((a) => a.data);
  const result = answers.includes('0.0.0.0') ? 'blocked' : body.Status === 3 ? 'missing' : 'ok';

  ctx.waitUntil(
    cache.put(
      cacheKey,
      new Response(JSON.stringify({ result }), { headers: { 'cache-control': `max-age=${CACHE_SECONDS}` } }),
    ),
  );
  return result;
}

/** Per-phone rate limit, keyed by a hash of the IP and the hour. */
async function allow(env, request) {
  const ip = request.headers.get('cf-connecting-ip') ?? 'unknown';
  const hour = Math.floor(Date.now() / 3600000);
  const digest = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(`${ip}:${hour}`));
  const key = [...new Uint8Array(digest)].slice(0, 12).map((b) => b.toString(16).padStart(2, '0')).join('');
  const row = await env.DB.prepare(
    'INSERT INTO hits (key, hour, n) VALUES (?, ?, 1) ON CONFLICT(key) DO UPDATE SET n = n + 1 RETURNING n',
  ).bind(key, hour).first();
  // Old hours are cleared now and then, never on every request.
  if (Math.random() < 0.01) {
    await env.DB.prepare('DELETE FROM hits WHERE hour < ?').bind(hour - 1).run();
  }
  return (row?.n ?? 1) <= PER_IP_HOUR;
}
