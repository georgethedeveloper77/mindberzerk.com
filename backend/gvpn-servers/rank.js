/**
 * VPN Gate list -> ranked Community servers. Pure functions, no I/O, so the
 * ranking is unit-testable and the admin panel can reuse it later.
 *
 * Source: VPN Gate's official list for client apps (CSV). Each row carries a
 * complete OpenVPN config, base64-encoded, which we keep as-is.
 */

/** Rows we keep after ranking, in total and per country. */
export const MAX_SERVERS = 150;
export const MAX_PER_COUNTRY = 8;

/** Parse the CSV. Lines are "*vpn_servers", a "#HostName,..." header, rows, "*". */
export function parseVpnGate(csv) {
  const lines = csv.split(/\r?\n/);
  const headerLine = lines.find((l) => l.startsWith('#HostName'));
  if (!headerLine) throw new Error('VPN Gate list: no header row');
  const header = headerLine.slice(1).split(',');
  const col = (name) => {
    const i = header.indexOf(name);
    if (i < 0) throw new Error(`VPN Gate list: missing column ${name}`);
    return i;
  };
  const c = {
    host: col('HostName'), ip: col('IP'), score: col('Score'), ping: col('Ping'),
    speed: col('Speed'), country: col('CountryLong'), cc: col('CountryShort'),
    sessions: col('NumVpnSessions'), uptime: col('Uptime'), operator: col('Operator'),
    config: col('OpenVPN_ConfigData_Base64'),
  };

  const rows = [];
  for (const line of lines) {
    if (!line || line.startsWith('*') || line.startsWith('#')) continue;
    const f = line.split(',');
    if (f.length < header.length) continue;
    const configB64 = f[c.config];
    if (!configB64) continue;
    rows.push({
      host: f[c.host],
      ip: f[c.ip],
      vgScore: num(f[c.score]),
      pingMs: num(f[c.ping]),
      speedMbps: num(f[c.speed]) / 1e6,
      country: f[c.country],
      countryCode: f[c.cc].toUpperCase(),
      sessions: num(f[c.sessions]),
      uptimeDays: num(f[c.uptime]) / 86_400_000,
      operator: f[c.operator] || null,
      configB64,
    });
  }
  return rows;
}

function num(s) {
  const n = Number(s);
  return Number.isFinite(n) ? n : 0;
}

/** Read protocol and port from the config's "proto" and "remote" lines. */
export function readEndpoint(configText) {
  const proto = /^\s*proto\s+(udp|tcp)/im.exec(configText)?.[1]?.toLowerCase() ?? null;
  const remote = /^\s*remote\s+(\S+)\s+(\d+)/im.exec(configText);
  return { proto, port: remote ? Number(remote[2]) : null };
}

/**
 * Quality 0-100. Speed matters most, then latency, then how loaded and how
 * stable the server is. Ping here is VPN Gate's measurement from Japan, so it
 * is a weak signal; the app re-measures from the user's own network.
 */
export function quality({ speedMbps, pingMs, sessions, uptimeDays }) {
  const speed = Math.min(speedMbps / 200, 1);                      // 200 Mbps+ is full marks
  const ping = pingMs > 0 ? Math.max(0, 1 - pingMs / 300) : 0.3;   // unknown ping: neutral-low
  const load = Math.max(0, 1 - sessions / 150);                    // crowded servers slow down
  const stable = Math.min(uptimeDays / 7, 1);                      // a week up is full marks
  return Math.round(100 * (0.5 * speed + 0.2 * ping + 0.2 * load + 0.1 * stable));
}

export function grade(q) {
  return q >= 70 ? 'fast' : q >= 45 ? 'good' : 'slow';
}

/** Short stable id: the same server keeps its id across refreshes. */
export async function serverId(ip, proto, port) {
  const bytes = new TextEncoder().encode(`${ip}|${proto}|${port}`);
  const hash = new Uint8Array(await crypto.subtle.digest('SHA-256', bytes));
  return [...hash.slice(0, 6)].map((b) => b.toString(16).padStart(2, '0')).join('');
}

/**
 * Rows from any source -> scored, de-duplicated, sorted best first. Not
 * capped: overrides and the reachability check run first, then
 * [capPerCountry] trims what is left.
 */
export async function rank(rows, decode = (b64) => atob(b64)) {
  const seen = new Set();
  const out = [];
  for (const r of rows) {
    let text;
    try {
      text = r.config ?? decode(r.configB64);
    } catch {
      continue;
    }
    const { proto, port } = readEndpoint(text);
    if (!proto || !port) continue;
    const id = await serverId(r.ip, proto, port);
    if (seen.has(id)) continue;
    seen.add(id);
    const q = r.baseQuality ?? quality(r);
    out.push({
      id, ip: r.ip, host: r.host, proto, port,
      source: r.source ?? 'vpngate',
      country: r.country, countryCode: r.countryCode,
      speedMbps: Math.round(r.speedMbps * 10) / 10,
      pingMs: r.pingMs, sessions: r.sessions,
      uptimeDays: Math.round(r.uptimeDays * 10) / 10,
      quality: q, grade: grade(q),
      config: text,
    });
  }
  return out.sort((a, b) => b.quality - a.quality);
}

/** The best few per country, so one country cannot crowd out the rest. */
export function capPerCountry(servers, perCountry = MAX_PER_COUNTRY, total = MAX_SERVERS) {
  const counts = new Map();
  const kept = [];
  for (const s of servers) {
    const n = counts.get(s.countryCode) ?? 0;
    if (s.pinned || n < perCountry) {
      counts.set(s.countryCode, n + 1);
      kept.push(s);
    }
    if (kept.length >= total) break;
  }
  return kept;
}

// ── OneConnect ─────────────────────────────────────────────────────────────

/** OneConnect publishes no speed or load, so its servers start as "good". */
export const ONECONNECT_BASE_QUALITY = 60;

/**
 * OneConnect's `fetchUserServers` reply -> rows for [rank]. Servers whose
 * config is not readable OpenVPN text (their SDK can encrypt configs) are
 * counted in `skipped` rather than guessed at.
 */
export function fromOneConnect(items) {
  const rows = [];
  let skipped = 0;
  for (const it of Array.isArray(items) ? items : []) {
    let text = String(it.ovpnConfiguration ?? '');
    if (!/^\s*remote\s/m.test(text)) {
      try {
        const decoded = atob(text.replace(/\s+/g, ''));
        if (/^\s*remote\s/m.test(decoded)) text = decoded;
      } catch {
        // not base64 either
      }
    }
    if (!/^\s*remote\s/m.test(text)) {
      skipped++;
      continue;
    }
    text = withCredentials(text, it.vpnUserName, it.vpnPassword);
    const host = /^\s*remote\s+(\S+)/m.exec(text)[1];
    const cc = (/\/([a-z]{2})\.(?:png|svg|jpe?g|webp)(?:\?|$)/i.exec(String(it.flag_url ?? ''))?.[1] ?? '').toUpperCase();
    rows.push({
      host, ip: host, source: 'oneconnect',
      country: String(it.serverName ?? cc), countryCode: cc,
      speedMbps: 0, pingMs: 0, sessions: 0, uptimeDays: 0,
      baseQuality: ONECONNECT_BASE_QUALITY,
      config: text,
    });
  }
  return { rows, skipped };
}

/**
 * Embeds a username and password in the config itself, as an inline
 * <auth-user-pass> block, so the app needs nothing beyond the .ovpn text.
 */
export function withCredentials(config, user, pass) {
  if (!user || !pass) return config;
  const block = `<auth-user-pass>\n${user}\n${pass}\n</auth-user-pass>`;
  return /^\s*auth-user-pass\b.*$/m.test(config)
    ? config.replace(/^\s*auth-user-pass\b.*$/m, block)
    : `${config.trimEnd()}\n${block}\n`;
}

// ── admin overrides ────────────────────────────────────────────────────────

export const DEFAULT_OVERRIDES = {
  sources: { vpngate: true, oneconnect: true },
  protocols: { openvpn: true, sstp: true },
  thresholds: { fast: 70, good: 45 },
  hiddenServers: [],
  pinnedServers: [],
  hiddenCountries: [],
  boosts: {},
};

/** Fills gaps and drops anything malformed, so a bad save cannot break refresh. */
export function cleanOverrides(raw) {
  const o = raw && typeof raw === 'object' ? raw : {};
  const ids = (v) => (Array.isArray(v) ? v.filter((x) => typeof x === 'string' && /^[0-9a-f]{12}$/.test(x)) : []);
  const num = (v, d, lo, hi) => (Number.isFinite(v) ? Math.min(hi, Math.max(lo, v)) : d);
  const boosts = {};
  for (const [k, v] of Object.entries(o.boosts ?? {})) {
    if (/^[0-9a-f]{12}$/.test(k) && Number.isFinite(v)) boosts[k] = Math.max(-50, Math.min(50, Math.round(v)));
  }
  return {
    sources: {
      vpngate: o.sources?.vpngate !== false,
      oneconnect: o.sources?.oneconnect !== false,
    },
    // How the app connects to free servers. Both on: SSTP where a server
    // offers it, OpenVPN otherwise. At least one stays on.
    protocols: (() => {
      const openvpn = o.protocols?.openvpn !== false;
      const sstp = o.protocols?.sstp !== false;
      return openvpn || sstp ? { openvpn, sstp } : { openvpn: true, sstp: false };
    })(),
    thresholds: {
      fast: num(o.thresholds?.fast, 70, 1, 100),
      good: num(o.thresholds?.good, 45, 0, 99),
    },
    hiddenServers: ids(o.hiddenServers),
    pinnedServers: ids(o.pinnedServers),
    hiddenCountries: Array.isArray(o.hiddenCountries)
      ? o.hiddenCountries.filter((c) => typeof c === 'string' && /^[A-Z]{2}$/.test(c))
      : [],
    boosts,
  };
}

/**
 * Applies the admin's choices: boosts move quality, thresholds re-grade,
 * hidden servers and countries are flagged (kept for the admin view), and
 * pinned servers go first.
 */
export function applyOverrides(servers, overrides) {
  const o = cleanOverrides(overrides);
  const hidden = new Set(o.hiddenServers);
  const pinned = new Set(o.pinnedServers);
  const hiddenCc = new Set(o.hiddenCountries);
  const regrade = (q) => (q >= o.thresholds.fast ? 'fast' : q >= o.thresholds.good ? 'good' : 'slow');
  return servers
    .map((s) => {
      const q = Math.max(0, Math.min(100, s.quality + (o.boosts[s.id] ?? 0)));
      return {
        ...s,
        quality: q,
        grade: regrade(q),
        pinned: pinned.has(s.id),
        hidden: hidden.has(s.id) || hiddenCc.has(s.countryCode),
      };
    })
    .sort((a, b) => Number(b.pinned) - Number(a.pinned) || b.quality - a.quality);
}

// ── SSTP ───────────────────────────────────────────────────────────────────

/** VPN Gate's server-list web page (the CSV does not say who accepts SSTP). */
export const SSTP_SOURCE = 'https://www.vpngate.net/en/';

/**
 * VPN Gate's web page -> Map(ip -> { host, port }) for servers that accept
 * MS-SSTP. Each table row carries the server's IP (in its OpenVPN link) and,
 * when SSTP is on, an "SSTP Hostname : name.opengw.net[:port]" line. Rows
 * without both are skipped: a server is only offered over SSTP when VPN Gate
 * itself says it takes SSTP.
 */
export function parseSstpHosts(html) {
  const out = new Map();
  for (const row of String(html).split(/<tr[\s>]/i)) {
    const ip = /[?&]ip=(\d{1,3}(?:\.\d{1,3}){3})/i.exec(row)?.[1];
    const m = /SSTP\s*Hostname\s*:?\s*(?:<[^>]*>\s*)*([a-z0-9][a-z0-9.-]*\.[a-z]{2,})(?::(\d{1,5}))?/i.exec(row);
    if (!ip || !m) continue;
    const port = m[2] ? Number(m[2]) : 443;
    if (port < 1 || port > 65535) continue;
    out.set(ip, { host: m[1].toLowerCase(), port });
  }
  return out;
}

/**
 * Applies the protocol switches to ranked servers: SSTP details are dropped
 * when SSTP is off, and with OpenVPN off only servers offering SSTP remain.
 */
export function applyProtocols(servers, protocols) {
  return servers
    .map((s) => (protocols.sstp ? s : { ...s, sstpHost: undefined, sstpPort: undefined }))
    .filter((s) => protocols.openvpn || s.sstpHost);
}
