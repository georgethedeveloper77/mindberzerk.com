/**
 * G Servers broker: the only thing between phones and the gvpn agents.
 *
 * A phone makes its own WireGuard key and sends only the PUBLIC key here.
 * This Worker checks the admin's switches and the phone limit, asks the
 * agent (signed with that server's secret, which never leaves Cloudflare)
 * to add the key, and returns the server's half of the config. Each phone
 * gets a random device token, stored here only as a hash, to list and
 * remove its group's phones later.
 *
 * Free tier only: Workers, D1, one daily cron. No IP addresses are stored.
 *
 *   GET    /servers            G Servers with live load, plus access rules
 *   POST   /devices            add this phone to a server, returns its config
 *   GET    /devices            this phone's group            (device token)
 *   DELETE /devices/:key       remove a phone in the group   (device token)
 *   POST   /seen               "still in use"                (device token)
 *   GET    /admin/settings     PUT /admin/settings           (admin token)
 *   GET    /admin/summary      phones per server             (admin token)
 */

import { connect } from 'cloudflare:sockets';

import {
  KEY_RE, busyPercent, cleanSettings, dayKey, hasRoom, isIdle, keyFromPath, keyToPath, lastActive, newPhoneBlock, orderRoot,
  parseHttpResponse,
} from './logic.js';

const PACKAGE = 'com.mindberzerk.gvpn';
const ACTIVE_STATES = new Set(['SUBSCRIPTION_STATE_ACTIVE', 'SUBSCRIPTION_STATE_IN_GRACE_PERIOD']);

export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);
    const { pathname: path } = url;
    const method = request.method;
    try {
      if (method === 'GET' && path === '/servers') return await listServers(request, env, ctx);
      if (method === 'POST' && path === '/devices') return await addDevice(request, env);
      if (method === 'GET' && path === '/devices') return await listDevices(request, env);
      if (method === 'DELETE' && path.startsWith('/devices/')) return await removeDevice(request, env, path.slice(9));
      if (method === 'POST' && path === '/seen') return await seen(request, env);
      if (path.startsWith('/admin/')) {
        if (!isAdmin(request, env)) return json({ error: 'unauthorised' }, 401);
        if (path === '/admin/settings' && method === 'GET') return json(await settings(env));
        if (path === '/admin/settings' && method === 'PUT') return await saveSettings(request, env);
        if (path === '/admin/summary' && method === 'GET') return await summary(env);
      }
      return json({ error: 'not found' }, 404);
    } catch (e) {
      return json({ error: 'failed', message: String(e?.message ?? e) }, 500);
    }
  },

  /** Daily: remove phones idle longer than the admin's limit. */
  async scheduled(_event, env, ctx) {
    ctx.waitUntil(cleanUp(env));
  },
};

// ── Servers ─────────────────────────────────────────────────────────────

function configuredServers(env) {
  try {
    const list = JSON.parse(env.GSERVERS || '[]');
    return list.filter((s) => s.id && s.host && s.secret);
  } catch {
    return [];
  }
}

async function listServers(request, env, ctx) {
  // A minute of caching: the list is read on every Pro tab visit.
  const cache = caches.default;
  const key = new Request(new URL('/servers', request.url).toString());
  const hit = await cache.match(key);
  if (hit) return hit;

  const s = await settings(env);
  const servers = s.enabled
    ? await Promise.all(
        configuredServers(env).map(async (srv) => {
          try {
            const h = await agent(srv, 'GET', '/health');
            return {
              id: srv.id,
              name: srv.name,
              city: srv.city ?? srv.name,
              country: srv.country ?? '',
              online: true,
              busy: busyPercent(h),
              // 15-minute samples, oldest first, for the 24-hour chart.
              history: Array.isArray(h.history) ? h.history.slice(-96) : [],
              // Where the phone times a connection, for its ping.
              host: srv.host,
              pingPort: Number(srv.port ?? 8443),
            };
          } catch {
            return { id: srv.id, name: srv.name, city: srv.city ?? srv.name, country: srv.country ?? '', online: false, busy: null, history: [] };
          }
        }),
      )
    : [];
  const res = json({ enabled: s.enabled, access: s.access, limit: s.limit, idleDays: s.idleDays, servers }, 200, 'public, max-age=60');
  ctx.waitUntil(cache.put(key, res.clone()));
  return res;
}

// ── Devices ─────────────────────────────────────────────────────────────

async function addDevice(request, env) {
  const s = await settings(env);
  if (!s.enabled) return json({ error: 'off' }, 403);
  const body = await request.json().catch(() => ({}));
  const publicKey = String(body.publicKey ?? '');
  if (!KEY_RE.test(publicKey)) return json({ error: 'bad key' }, 400);
  const srv = configuredServers(env).find((x) => x.id === body.serverId);
  if (!srv) return json({ error: 'no such server' }, 404);

  const me = await deviceByToken(request, env);
  const existing = await env.DB.prepare('SELECT * FROM devices WHERE public_key = ?').bind(publicKey).first();

  // Which group this phone counts against.
  let group;
  if (s.access === 'pro') {
    const sub = await verifySubscription(env, String(body.purchaseToken ?? ''));
    if (!sub) return json({ error: 'pro_required' }, 402);
    group = `p:${sub}`;
  } else {
    group = me?.grp ?? existing?.grp ?? `d:${randomId(12)}`;
  }

  const others = await env.DB.prepare('SELECT public_key, name, last_seen FROM devices WHERE grp = ? AND public_key != ?')
    .bind(group, publicKey)
    .all();
  if (!hasRoom(others.results.length, s.limit)) {
    return json({ error: 'limit', limit: s.limit, devices: others.results.map(publicDevice(null)) }, 409);
  }

  // Abuse limits, for phones the broker has never seen. Reconnecting,
  // reinstalling into the same key or moving servers never counts.
  let throttle = null;
  if (!existing) {
    const now = Date.now();
    const day = dayKey(now);
    const minute = Math.floor(now / 60_000);
    // A scrambled code from the address, kept for the day only: never the
    // address itself (privacy policy: "kept one day").
    const code = await sha256(`${env.ADMIN_TOKEN}|${day}|${request.headers.get('cf-connecting-ip') ?? ''}`);
    const row = await env.DB.prepare('SELECT * FROM throttle WHERE code = ?').bind(code).first();
    const [onServer, newToday] = await Promise.all([
      env.DB.prepare('SELECT COUNT(*) AS n FROM devices WHERE server_id = ?').bind(srv.id).first(),
      env.DB.prepare('SELECT COUNT(*) AS n FROM devices WHERE created_at > ?').bind(now - 86_400_000).first(),
    ]);
    const counts = {
      onServer: onServer?.n ?? 0,
      newToday: newToday?.n ?? 0,
      fromIpToday: row?.day_count ?? 0,
      fromIpMinute: row && row.minute_bucket === minute ? row.minute_count : 0,
    };
    const block = newPhoneBlock(counts, s);
    if (block === 'server_full') return json({ error: 'server_full' }, 409);
    if (block) return json({ error: 'busy' }, 429, 'no-store', { 'retry-after': '60' });
    throttle = { code, day, minute, fromIpToday: counts.fromIpToday, fromIpMinute: counts.fromIpMinute };
  }

  const peer = await agent(srv, 'POST', '/peers', JSON.stringify({ publicKey }));
  // Moving to another G Server: the old one forgets this key.
  if (existing && existing.server_id !== srv.id) {
    const old = configuredServers(env).find((x) => x.id === existing.server_id);
    if (old) await agent(old, 'DELETE', `/peers/${keyToPath(publicKey)}`).catch(() => {});
  }

  const token = randomId(32);
  const now = Date.now();
  await env.DB.prepare(
    `INSERT INTO devices (public_key, server_id, grp, token_hash, name, address, created_at, last_seen)
     VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?7)
     ON CONFLICT(public_key) DO UPDATE SET server_id = ?2, grp = ?3, token_hash = ?4, name = ?5, address = ?6, last_seen = ?7`,
  )
    .bind(publicKey, srv.id, group, await sha256(token), String(body.name ?? '').slice(0, 60) || null, peer.address, now)
    .run();

  if (throttle) {
    await env.DB.prepare(
      `INSERT INTO throttle (code, day, day_count, minute_bucket, minute_count) VALUES (?1, ?2, ?3, ?4, ?5)
       ON CONFLICT(code) DO UPDATE SET day_count = ?3, minute_bucket = ?4, minute_count = ?5`,
    )
      .bind(throttle.code, throttle.day, throttle.fromIpToday + 1, throttle.minute, throttle.fromIpMinute + 1)
      .run();
  }

  return json({ token, ...peer });
}

async function listDevices(request, env) {
  const me = await deviceByToken(request, env);
  if (!me) return json({ error: 'unauthorised' }, 401);
  const rows = await env.DB.prepare('SELECT public_key, name, server_id, last_seen FROM devices WHERE grp = ? ORDER BY last_seen DESC')
    .bind(me.grp)
    .all();
  const s = await settings(env);
  return json({ limit: s.limit, idleDays: s.idleDays, devices: rows.results.map(publicDevice(me.public_key)) });
}

async function removeDevice(request, env, keyPath) {
  const me = await deviceByToken(request, env);
  if (!me) return json({ error: 'unauthorised' }, 401);
  const key = keyFromPath(decodeURIComponent(keyPath));
  const row = await env.DB.prepare('SELECT * FROM devices WHERE public_key = ? AND grp = ?').bind(key, me.grp).first();
  if (!row) return json({ error: 'not found' }, 404);
  const srv = configuredServers(env).find((x) => x.id === row.server_id);
  if (srv) await agent(srv, 'DELETE', `/peers/${keyToPath(key)}`);
  await env.DB.prepare('DELETE FROM devices WHERE public_key = ?').bind(key).run();
  return json({ removed: true });
}

async function seen(request, env) {
  const me = await deviceByToken(request, env);
  if (!me) return json({ error: 'unauthorised' }, 401);
  await env.DB.prepare('UPDATE devices SET last_seen = ? WHERE public_key = ?').bind(Date.now(), me.public_key).run();
  return json({ ok: true });
}

function publicDevice(myKey) {
  return (r) => ({
    key: r.public_key,
    name: r.name,
    server: r.server_id,
    lastSeen: r.last_seen,
    you: r.public_key === myKey,
  });
}

async function deviceByToken(request, env) {
  const token = /^Bearer (.+)$/.exec(request.headers.get('authorization') ?? '')?.[1];
  if (!token) return null;
  return env.DB.prepare('SELECT * FROM devices WHERE token_hash = ?').bind(await sha256(token)).first();
}

// ── Admin ───────────────────────────────────────────────────────────────

function isAdmin(request, env) {
  const got = request.headers.get('authorization') ?? '';
  return Boolean(env.ADMIN_TOKEN) && got === `Bearer ${env.ADMIN_TOKEN}`;
}

async function settings(env) {
  const row = await env.DB.prepare("SELECT value FROM settings WHERE key = 'config'").first();
  return cleanSettings(row ? JSON.parse(row.value) : null);
}

async function saveSettings(request, env) {
  const next = cleanSettings(await request.json().catch(() => null));
  await env.DB.prepare("INSERT INTO settings (key, value) VALUES ('config', ?1) ON CONFLICT(key) DO UPDATE SET value = ?1")
    .bind(JSON.stringify(next))
    .run();
  return json(next);
}

async function summary(env) {
  const rows = await env.DB.prepare('SELECT server_id, COUNT(*) AS phones FROM devices GROUP BY server_id').all();
  const groups = await env.DB.prepare('SELECT COUNT(DISTINCT grp) AS n FROM devices').first();
  return json({ settings: await settings(env), perServer: rows.results, groups: groups?.n ?? 0 });
}

// ── Cleanup ─────────────────────────────────────────────────────────────

async function cleanUp(env) {
  const s = await settings(env);
  const now = Date.now();
  // Yesterday's per-address codes go every day.
  await env.DB.prepare('DELETE FROM throttle WHERE day < ?').bind(dayKey(now)).run();
  for (const srv of configuredServers(env)) {
    let activity;
    try {
      activity = await agent(srv, 'GET', '/peers/activity');
    } catch {
      continue; // server down: try again tomorrow, never guess
    }
    const handshakes = new Map(activity.peers.map((p) => [p.publicKey, p.lastHandshake]));
    const rows = await env.DB.prepare('SELECT * FROM devices WHERE server_id = ?').bind(srv.id).all();
    // Only phones this Worker added are ever removed; peers added by hand
    // on the server (gvpn-peer) are left alone.
    for (const row of rows.results) {
      const hs = handshakes.get(row.public_key) ?? 0;
      if (isIdle(hs, row, now, s.idleDays)) {
        await agent(srv, 'DELETE', `/peers/${keyToPath(row.public_key)}`).catch(() => {});
        await env.DB.prepare('DELETE FROM devices WHERE public_key = ?').bind(row.public_key).run();
      } else {
        await env.DB.prepare('UPDATE devices SET last_seen = ? WHERE public_key = ?')
          .bind(lastActive(hs, row), row.public_key)
          .run();
      }
    }
  }
}

// ── Agent (signed HTTP over a raw socket: any IP, any port) ─────────────

async function agent(srv, method, path, body = '') {
  const ts = Math.floor(Date.now() / 1000).toString();
  const sig = await hmacHex(srv.secret, [method, path, ts, body].join('\n'));
  const bytes = new TextEncoder().encode(body);
  const request =
    `${method} ${path} HTTP/1.1\r\nHost: ${srv.host}\r\nConnection: close\r\n` +
    `X-GVPN-Time: ${ts}\r\nX-GVPN-Sig: ${sig}\r\nContent-Type: application/json\r\nContent-Length: ${bytes.length}\r\n\r\n`;
  const socket = connect({ hostname: srv.host, port: Number(srv.port ?? 8443) });
  const timeout = setTimeout(() => socket.close(), 8000);
  try {
    const writer = socket.writable.getWriter();
    await writer.write(new TextEncoder().encode(request));
    if (bytes.length) await writer.write(bytes);
    writer.releaseLock();
    const text = await new Response(socket.readable).text();
    const { status, body: reply } = parseHttpResponse(text);
    if (status !== 200) throw new Error(`agent ${srv.id}: ${status} ${reply.slice(0, 120)}`);
    return JSON.parse(reply);
  } finally {
    clearTimeout(timeout);
    socket.close().catch(() => {});
  }
}

// ── Google Play: is this an active G VPN Pro subscription? ──────────────

/** The subscription's first order id when active, else null. */
async function verifySubscription(env, purchaseToken) {
  if (!purchaseToken || !env.PLAY_SERVICE_ACCOUNT) return null;
  const access = await googleToken(env);
  const res = await fetch(
    `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${PACKAGE}/purchases/subscriptionsv2/tokens/${encodeURIComponent(purchaseToken)}`,
    { headers: { authorization: `Bearer ${access}` } },
  );
  if (!res.ok) return null;
  const sub = await res.json();
  if (!ACTIVE_STATES.has(sub.subscriptionState)) return null;
  return orderRoot(sub.latestOrderId);
}

/** OAuth token for the Play Developer API from the service account (RS256 JWT). */
async function googleToken(env) {
  const sa = JSON.parse(env.PLAY_SERVICE_ACCOUNT);
  const now = Math.floor(Date.now() / 1000);
  const b64 = (o) => base64url(new TextEncoder().encode(JSON.stringify(o)));
  const unsigned = `${b64({ alg: 'RS256', typ: 'JWT' })}.${b64({
    iss: sa.client_email,
    scope: 'https://www.googleapis.com/auth/androidpublisher',
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600,
  })}`;
  const pem = sa.private_key.replace(/-----[^-]+-----/g, '').replace(/\s+/g, '');
  const der = Uint8Array.from(atob(pem), (c) => c.charCodeAt(0));
  const key = await crypto.subtle.importKey('pkcs8', der, { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' }, false, ['sign']);
  const sig = new Uint8Array(await crypto.subtle.sign('RSASSA-PKCS1-v1_5', key, new TextEncoder().encode(unsigned)));
  const res = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'content-type': 'application/x-www-form-urlencoded' },
    body: `grant_type=urn%3Aietf%3Aparams%3Aoauth%3Agrant-type%3Ajwt-bearer&assertion=${unsigned}.${base64url(sig)}`,
  });
  if (!res.ok) throw new Error(`Google token: ${res.status}`);
  return (await res.json()).access_token;
}

// ── Helpers ─────────────────────────────────────────────────────────────

function json(body, status = 200, cacheControl = 'no-store', extra = {}) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'content-type': 'application/json', 'cache-control': cacheControl, ...extra },
  });
}

function randomId(bytes) {
  return base64url(crypto.getRandomValues(new Uint8Array(bytes)));
}

function base64url(bytes) {
  return btoa(String.fromCharCode(...bytes)).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

async function sha256(text) {
  const d = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(text));
  return [...new Uint8Array(d)].map((b) => b.toString(16).padStart(2, '0')).join('');
}

async function hmacHex(secret, message) {
  const key = await crypto.subtle.importKey('raw', new TextEncoder().encode(secret), { name: 'HMAC', hash: 'SHA-256' }, false, ['sign']);
  const sig = await crypto.subtle.sign('HMAC', key, new TextEncoder().encode(message));
  return [...new Uint8Array(sig)].map((b) => b.toString(16).padStart(2, '0')).join('');
}
