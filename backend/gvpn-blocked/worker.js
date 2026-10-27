/**
 * gvpn-blocked: which sites OONI's volunteers found blocked in the
 * caller's country over the last 30 days.
 *
 *   GET /country   { country, since, blocked: [{ domain, tests, anomalies, confirmed }] }
 *
 * The phone asks us, not OONI, so OONI never sees users' IP addresses. The
 * country comes from Cloudflare's view of the connection; nothing about
 * the caller is stored. Answers are cached per country for six hours.
 */

const DAYS = 30;
const MIN_TESTS = 10;
const CACHE_SECONDS = 6 * 3600;

const json = (body, status = 200, extra = {}) =>
  new Response(JSON.stringify(body), { status, headers: { 'content-type': 'application/json', ...extra } });

export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);
    if (request.method !== 'GET' || url.pathname !== '/country') return json({ error: 'not_found' }, 404);
    const cc = String(request.cf?.country ?? '').toUpperCase();
    if (!/^[A-Z]{2}$/.test(cc)) return json({ error: 'unknown_country' }, 400);

    const cache = caches.default;
    const key = new Request(`https://gvpn-blocked.cache/${cc}`);
    const hit = await cache.match(key);
    if (hit) return hit;

    const since = new Date(Date.now() - DAYS * 86400000).toISOString().slice(0, 10);
    const api = new URL('https://api.ooni.io/api/v1/aggregation');
    api.search = new URLSearchParams({ probe_cc: cc, test_name: 'web_connectivity', since, axis_x: 'domain' }).toString();

    let rows = [];
    try {
      const res = await fetch(api, { headers: { 'user-agent': 'G-VPN (mindberzerk.com)' }, signal: AbortSignal.timeout(20000) });
      if (!res.ok) return json({ error: 'upstream', status: res.status }, 502);
      const body = await res.json();
      rows = Array.isArray(body.result) ? body.result : [];
    } catch {
      return json({ error: 'upstream' }, 502);
    }

    // Confirmed: a known block page was seen. Otherwise a site counts only
    // when it failed in at least a third of enough tests, because single
    // failures are often just a slow network.
    const blocked = rows
      .map((r) => ({
        domain: String(r.domain ?? ''),
        tests: Number(r.measurement_count) || 0,
        anomalies: Number(r.anomaly_count) || 0,
        confirmed: Number(r.confirmed_count) || 0,
      }))
      .filter((r) => r.domain && r.tests >= MIN_TESTS && (r.confirmed > 0 || r.anomalies / r.tests >= 1 / 3))
      .sort((a, b) => b.confirmed - a.confirmed || b.anomalies / b.tests - a.anomalies / a.tests)
      .slice(0, 60);

    const out = json({ country: cc, since, blocked }, 200, { 'cache-control': `public, max-age=${CACHE_SECONDS}` });
    ctx.waitUntil(cache.put(key, out.clone()));
    return out;
  },
};
