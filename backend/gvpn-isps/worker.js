/**
 * gvpn-isps: how a phone's internet provider compares with others nearby.
 *
 *   POST /results      one direct speed test {down, up, ping} in Mbps / ms
 *   GET  /compare      providers in the caller's city (or country), ranked
 *   GET  /admin/isps   every country's rankings        (Bearer ADMIN_TOKEN)
 *
 * The phone sends three numbers. Provider, country and city are read from
 * Cloudflare's view of the connection (request.cf), so they cannot be
 * faked, and the IP address is never written anywhere.
 */
import { WINDOW_DAYS, chooseScope, cleanIsp, rankProviders, validResult } from './isp.js';

const MAX_PER_DAY = 10;
const KEEP_DAYS = 90;

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    try {
      if (url.pathname === '/results' && request.method === 'POST') return await submit(request, env);
      if (url.pathname === '/compare' && request.method === 'GET') return await compare(request, env);
      if (url.pathname === '/admin/isps' && request.method === 'GET') {
        if (!(await authorised(request, env))) return json({ error: 'unauthorised' }, 401);
        return await adminIsps(env);
      }
      return json({ error: 'not found' }, 404);
    } catch (e) {
      return json({ error: 'server error' }, 500);
    }
  },

  // Daily: drop old results and yesterday's flood-control hashes.
  async scheduled(_event, env) {
    await env.DB.batch([
      env.DB.prepare('DELETE FROM results WHERE day < ?').bind(daysAgo(KEEP_DAYS)),
      env.DB.prepare('DELETE FROM recent WHERE day < ?').bind(today()),
    ]);
  },
};

function place(request) {
  const cf = request.cf ?? {};
  const isp = cleanIsp(cf.asOrganization);
  const country = String(cf.country ?? '').toUpperCase();
  const city = String(cf.city ?? '').slice(0, 80);
  return isp && /^[A-Z]{2}$/.test(country) ? { isp, country, city } : null;
}

async function submit(request, env) {
  const where = place(request);
  if (!where) return json({ error: 'unknown network' }, 422);
  let body;
  try {
    body = await request.json();
  } catch {
    return json({ error: 'bad json' }, 400);
  }
  const r = validResult(body);
  if (!r) return json({ error: 'invalid result' }, 422);

  const day = today();
  const hash = await keyedHash(`${request.headers.get('cf-connecting-ip') ?? ''}|${day}`, env.ADMIN_TOKEN ?? '');
  const seen = await env.DB.prepare('SELECT COUNT(*) AS n FROM recent WHERE hash = ? AND day = ?').bind(hash, day).first();
  if ((seen?.n ?? 0) >= MAX_PER_DAY) return json({ ok: true, counted: false });

  await env.DB.batch([
    env.DB.prepare('INSERT INTO recent (hash, day) VALUES (?, ?)').bind(hash, day),
    env.DB.prepare('INSERT INTO results (isp, country, city, down, up, ping, day) VALUES (?, ?, ?, ?, ?, ?, ?)')
      .bind(where.isp, where.country, where.city, r.down, r.up, r.ping, day),
  ]);
  return json({ ok: true, counted: true });
}

async function compare(request, env) {
  const where = place(request);
  if (!where) return json({ you: null, scope: null, providers: [] });
  const { results } = await env.DB.prepare(
    'SELECT isp, city, down, up, ping FROM results WHERE country = ? AND day >= ? LIMIT 50000',
  ).bind(where.country, daysAgo(WINDOW_DAYS)).all();

  const city = rankProviders(results.filter((r) => r.city === where.city));
  const country = rankProviders(results);
  const chosen = chooseScope(city, country);
  const providers = chosen?.providers ?? [];
  const mine = providers.find((p) => p.isp === where.isp) ?? null;
  return json(
    {
      you: where,
      scope: chosen?.scope ?? null,
      of: providers.length,
      rank: mine?.rank ?? null,
      providers: providers.slice(0, 10),
    },
    200,
    { 'cache-control': 'private, max-age=300' },
  );
}

async function adminIsps(env) {
  const { results } = await env.DB.prepare(
    'SELECT isp, country, city, down, up, ping FROM results WHERE day >= ? LIMIT 200000',
  ).bind(daysAgo(WINDOW_DAYS)).all();
  const byCountry = new Map();
  for (const r of results) {
    if (!byCountry.has(r.country)) byCountry.set(r.country, []);
    byCountry.get(r.country).push(r);
  }
  const countries = [...byCountry].map(([country, rows]) => ({
    country,
    tests: rows.length,
    cities: new Set(rows.map((r) => r.city)).size,
    // Thin providers included here (min 1): the admin sees everything.
    providers: rankProviders(rows, 1),
  }));
  countries.sort((a, b) => b.tests - a.tests);
  const total = await env.DB.prepare('SELECT COUNT(*) AS n FROM results').first();
  return json({ windowDays: WINDOW_DAYS, totalTests: total?.n ?? 0, countries });
}

async function authorised(request, env) {
  const got = request.headers.get('authorization') ?? '';
  if (!env.ADMIN_TOKEN) return false;
  const want = `Bearer ${env.ADMIN_TOKEN}`;
  const [a, b] = await Promise.all([digest(got), digest(want)]);
  return crypto.subtle.timingSafeEqual(a, b);
}

async function digest(s) {
  return new Uint8Array(await crypto.subtle.digest('SHA-256', new TextEncoder().encode(s)));
}

async function keyedHash(message, secret) {
  const key = await crypto.subtle.importKey('raw', new TextEncoder().encode(secret || 'gvpn'), { name: 'HMAC', hash: 'SHA-256' }, false, ['sign']);
  const sig = new Uint8Array(await crypto.subtle.sign('HMAC', key, new TextEncoder().encode(message)));
  return [...sig.slice(0, 16)].map((b) => b.toString(16).padStart(2, '0')).join('');
}

function today() {
  return new Date().toISOString().slice(0, 10);
}

function daysAgo(n) {
  return new Date(Date.now() - n * 86400000).toISOString().slice(0, 10);
}

function json(body, status = 200, headers = {}) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'content-type': 'application/json', ...headers },
  });
}
