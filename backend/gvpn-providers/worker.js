/**
 * gvpn-providers: internet providers, their brand, and user ratings.
 *
 * A phone can only rate the provider it is connected through right now
 * (Cloudflare tells us which), once a month. No IP addresses are kept.
 *
 * Phone endpoints (header X-Device: the app's random install id):
 *   GET  /me      the caller's provider, its brand and ratings, and the
 *                 caller's own rating this month. Also records that this
 *                 install used this provider this month, which is how the
 *                 directory fills itself from ordinary use.
 *   POST /rate    {stars: 1-5, tags: [...], down: Mbps?}
 *   GET  /nearby  providers rated in the caller's country (city first)
 * Admin endpoints (Authorization: Bearer ADMIN_TOKEN):
 *   GET  /admin/providers?country=KE
 *   PUT  /admin/providers/:asn  {name, color, logo, phone, website, outages, hidden}
 *
 * Secrets: ADMIN_TOKEN. Bindings: DB (D1, schema.sql).
 */

const TAGS = ['fast', 'reliable', 'support', 'price', 'slowEvenings', 'drops', 'poorSupport', 'pricey'];
const RATES_PER_HOUR = 10;
const MIN_FOR_AVERAGE = 3; // fewer ratings than this show as "not enough yet"

const json = (body, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { 'content-type': 'application/json', 'cache-control': 'no-store' },
  });

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const path = url.pathname.replace(/\/+$/, '');
    try {
      if (path.startsWith('/admin/')) return await admin(request, env, url, path);
      if (request.method === 'GET' && path === '/me') return await me(request, env);
      if (request.method === 'POST' && path === '/rate') return await rate(request, env);
      if (request.method === 'GET' && path === '/nearby') return await nearby(request, env);
      return json({ error: 'not_found' }, 404);
    } catch (e) {
      return json({ error: 'server' }, 500);
    }
  },
};

const SUFFIXES = /[\s,]+(limited|ltd\.?|llc|l\.l\.c\.|inc\.?|plc|s\.a\.?|gmbh|co\.?|corp\.?|corporation|company|pvt|private|sdn bhd|jsc|ojsc|pjsc|ag|bv|b\.v\.)$/i;

/**
 * "Safaricom Limited" -> "Safaricom". The same clean-up as gvpn-isps
 * (backend/gvpn-isps/isp.js): keep the two in step, because the app joins
 * ratings to speeds by this name.
 */
function cleanIsp(raw) {
  let name = String(raw ?? '').trim().replace(/\s+/g, ' ');
  for (let i = 0; i < 3; i++) {
    const next = name.replace(SUFFIXES, '').trim();
    if (next === name) break;
    name = next;
  }
  return name.slice(0, 80);
}

/** Where the caller is and who carries them, as Cloudflare sees it. */
function place(request) {
  const cf = request.cf ?? {};
  const org = cleanIsp(cf.asOrganization);
  return {
    asn: Number(cf.asn) || null,
    org: org || null,
    country: typeof cf.country === 'string' ? cf.country : null,
    city: typeof cf.city === 'string' ? cf.city : null,
  };
}

function device(request) {
  const d = request.headers.get('x-device') ?? '';
  return /^[A-Za-z0-9_-]{16,64}$/.test(d) ? d : null;
}

const month = () => new Date().toISOString().slice(0, 7);

/** "2026-09" when it is October: users counts cover this month and last. */
function lastMonth() {
  const d = new Date();
  d.setUTCDate(1);
  d.setUTCMonth(d.getUTCMonth() - 1);
  return d.toISOString().slice(0, 7);
}

/** The provider row for [p], created the first time it is seen. */
async function provider(env, p) {
  const now = Date.now();
  await env.DB.prepare(
    'INSERT INTO providers (asn, org, country, first_seen, updated) VALUES (?, ?, ?, ?, ?) ON CONFLICT(asn) DO NOTHING',
  ).bind(p.asn, p.org ?? `AS${p.asn}`, p.country, now, now).run();
  return env.DB.prepare('SELECT * FROM providers WHERE asn = ?').bind(p.asn).first();
}

function profile(row) {
  return {
    asn: row.asn,
    org: row.org,
    name: row.name || row.org,
    color: row.color || null,
    logo: row.logo || null,
    phone: row.phone || null,
    website: row.website || null,
    outages: row.outages || null,
  };
}

/** Average, count, star spread and tag counts over the last 12 months. */
async function summary(env, asn, country) {
  const since = new Date();
  since.setMonth(since.getMonth() - 12);
  const from = since.toISOString().slice(0, 7);
  const { results } = await env.DB.prepare(
    'SELECT stars, tags, verified FROM ratings WHERE asn = ? AND (? IS NULL OR country = ?) AND month >= ?',
  ).bind(asn, country, country, from).all();
  const spread = [0, 0, 0, 0, 0];
  const tags = {};
  let sum = 0;
  let weight = 0;
  for (const r of results) {
    spread[r.stars - 1]++;
    // A rating that came with a speed test counts a little more.
    const w = r.verified ? 1.5 : 1;
    sum += r.stars * w;
    weight += w;
    for (const t of String(r.tags).split(',').filter((t) => TAGS.includes(t))) tags[t] = (tags[t] ?? 0) + 1;
  }
  return {
    count: results.length,
    average: results.length >= MIN_FOR_AVERAGE ? Math.round((sum / weight) * 10) / 10 : null,
    spread,
    tags,
  };
}

async function me(request, env) {
  const p = place(request);
  if (!p.asn) return json({ error: 'unknown_network' }, 400);
  const row = await provider(env, p);
  const d = device(request);
  if (d) {
    await env.DB.prepare('INSERT INTO seen (asn, device, month, country, city) VALUES (?, ?, ?, ?, ?) ON CONFLICT DO NOTHING')
      .bind(p.asn, d, month(), p.country, p.city).run();
  }
  const mine = d
    ? await env.DB.prepare('SELECT stars, tags FROM ratings WHERE asn = ? AND device = ? AND month = ?')
        .bind(p.asn, d, month()).first()
    : null;
  return json({
    provider: profile(row),
    hidden: !!row.hidden,
    city: p.city,
    country: p.country,
    rating: await summary(env, p.asn, p.country),
    mine: mine ? { stars: mine.stars, tags: String(mine.tags).split(',').filter(Boolean) } : null,
  });
}

async function rate(request, env) {
  const p = place(request);
  const d = device(request);
  if (!p.asn || !d) return json({ error: 'invalid' }, 400);
  if (!(await allow(env, request))) return json({ error: 'busy' }, 429);
  let body;
  try {
    body = await request.json();
  } catch {
    return json({ error: 'invalid' }, 400);
  }
  const stars = Number(body.stars);
  if (!Number.isInteger(stars) || stars < 1 || stars > 5) return json({ error: 'invalid' }, 400);
  const tags = Array.isArray(body.tags) ? [...new Set(body.tags.filter((t) => TAGS.includes(t)))].slice(0, 6) : [];
  const verified = Number(body.down) > 0 ? 1 : 0;
  const row = await provider(env, p);
  if (row.hidden) return json({ error: 'not_rateable' }, 400);
  await env.DB.prepare(
    `INSERT INTO ratings (asn, device, month, country, city, stars, tags, verified, at)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
     ON CONFLICT(asn, device, month) DO UPDATE SET stars = excluded.stars, tags = excluded.tags,
       verified = MAX(ratings.verified, excluded.verified), at = excluded.at`,
  ).bind(p.asn, d, month(), p.country, p.city, stars, tags.join(','), verified, Date.now()).run();
  return json({ ok: true, rating: await summary(env, p.asn, p.country) });
}

async function nearby(request, env) {
  const p = place(request);
  if (!p.country) return json({ providers: [] });
  const since = new Date();
  since.setMonth(since.getMonth() - 12);
  const from = since.toISOString().slice(0, 7);
  // City when it has enough ratings, else the whole country.
  const query = (byCity) =>
    env.DB.prepare(
      `SELECT r.asn, COUNT(*) AS n,
              SUM(r.stars * CASE WHEN r.verified = 1 THEN 1.5 ELSE 1 END) / SUM(CASE WHEN r.verified = 1 THEN 1.5 ELSE 1 END) AS avg,
              p.org, p.name, p.color, p.logo
         FROM ratings r JOIN providers p ON p.asn = r.asn
        WHERE r.country = ? AND (? = 0 OR r.city = ?) AND r.month >= ? AND p.hidden = 0
        GROUP BY r.asn HAVING n >= ?
        ORDER BY avg DESC LIMIT 30`,
    ).bind(p.country, byCity ? 1 : 0, p.city, from, MIN_FOR_AVERAGE).all();
  let scope = 'city';
  let { results } = p.city ? await query(true) : { results: [] };
  if (results.length < 2) {
    scope = 'country';
    ({ results } = await query(false));
  }
  return json({
    scope,
    city: p.city,
    country: p.country,
    you: p.asn,
    providers: results.map((r) => ({
      asn: r.asn,
      org: r.org,
      name: r.name || r.org,
      color: r.color || null,
      logo: r.logo || null,
      average: Math.round(r.avg * 10) / 10,
      count: r.n,
    })),
  });
}

// ── Admin ─────────────────────────────────────────────────────────────

async function admin(request, env, url, path) {
  const auth = request.headers.get('authorization') ?? '';
  if (!env.ADMIN_TOKEN || auth !== `Bearer ${env.ADMIN_TOKEN}`) return json({ error: 'unauthorized' }, 401);

  if (request.method === 'GET' && path === '/admin/providers') {
    const country = url.searchParams.get('country');
    const { results } = await env.DB.prepare(
      `SELECT p.*, (SELECT COUNT(*) FROM ratings r WHERE r.asn = p.asn) AS ratings,
              (SELECT ROUND(AVG(stars), 1) FROM ratings r WHERE r.asn = p.asn) AS average,
              (SELECT COUNT(DISTINCT device) FROM seen s WHERE s.asn = p.asn AND s.month >= ?) AS users,
              (SELECT COUNT(DISTINCT city) FROM seen s WHERE s.asn = p.asn) AS cities
         FROM providers p WHERE (? IS NULL OR p.country = ?) ORDER BY users DESC, ratings DESC LIMIT 1000`,
    ).bind(lastMonth(), country, country).all();
    return json({ providers: results });
  }

  const m = path.match(/^\/admin\/providers\/(\d+)$/);
  if (request.method === 'PUT' && m) {
    const b = await request.json();
    const text = (v, max = 200) => (typeof v === 'string' && v.trim() ? v.trim().slice(0, max) : null);
    const color = typeof b.color === 'string' && /^#[0-9a-fA-F]{6}$/.test(b.color) ? b.color.toUpperCase() : null;
    const link = (v) => {
      const s = text(v, 500);
      return s && /^https:\/\//.test(s) ? s : null;
    };
    const phone = text(b.phone, 40);
    const res = await env.DB.prepare(
      `UPDATE providers SET name = ?, color = ?, logo = ?, phone = ?, website = ?, outages = ?, hidden = ?, updated = ?
        WHERE asn = ?`,
    ).bind(text(b.name, 60), color, link(b.logo), phone, link(b.website), link(b.outages), b.hidden ? 1 : 0, Date.now(), Number(m[1])).run();
    if (!res.meta.changes) return json({ error: 'not_found' }, 404);
    return json({ ok: true });
  }

  return json({ error: 'not_found' }, 404);
}

/** Per-phone rating limit, keyed by a hash of the IP and the hour. */
async function allow(env, request) {
  const ip = request.headers.get('cf-connecting-ip') ?? 'unknown';
  const hour = Math.floor(Date.now() / 3600000);
  const digest = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(`${ip}:${hour}`));
  const key = [...new Uint8Array(digest)].slice(0, 12).map((b) => b.toString(16).padStart(2, '0')).join('');
  const row = await env.DB.prepare(
    'INSERT INTO hits (key, hour, n) VALUES (?, ?, 1) ON CONFLICT(key) DO UPDATE SET n = n + 1 RETURNING n',
  ).bind(key, hour).first();
  if (Math.random() < 0.01) await env.DB.prepare('DELETE FROM hits WHERE hour < ?').bind(hour - 1).run();
  return (row?.n ?? 1) <= RATES_PER_HOUR;
}
