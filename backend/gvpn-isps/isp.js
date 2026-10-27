/**
 * Pure logic for ISP comparisons: name clean-up, medians, ranking.
 * No I/O here, so it is tested without a Worker runtime.
 */

/** Results outside these ranges are typos, test faults or abuse. */
export const LIMITS = { down: [0.05, 10000], up: [0.01, 10000], ping: [0.5, 5000] };

/** A provider needs this many tests in the window before it is ranked. */
export const MIN_TESTS = 5;

/** Days of results a comparison covers. */
export const WINDOW_DAYS = 30;

const SUFFIXES = /[\s,]+(limited|ltd\.?|llc|l\.l\.c\.|inc\.?|plc|s\.a\.?|gmbh|co\.?|corp\.?|corporation|company|pvt|private|sdn bhd|jsc|ojsc|pjsc|ag|bv|b\.v\.)$/i;

/**
 * "Safaricom Limited" -> "Safaricom", "MTN NIGERIA Communication limited"
 * -> "MTN NIGERIA Communication". Strips legal suffixes, repeatedly.
 */
export function cleanIsp(raw) {
  let name = String(raw ?? '').trim().replace(/\s+/g, ' ');
  for (let i = 0; i < 3; i++) {
    const next = name.replace(SUFFIXES, '').trim();
    if (next === name) break;
    name = next;
  }
  return name.slice(0, 80);
}

/** Validates one submitted result; returns it rounded, or null. */
export function validResult(body) {
  if (!body || typeof body !== 'object') return null;
  const out = {};
  for (const [k, [lo, hi]] of Object.entries(LIMITS)) {
    const v = Number(body[k]);
    if (!Number.isFinite(v) || v < lo || v > hi) return null;
    out[k] = Math.round(v * 10) / 10;
  }
  return out;
}

export function median(values) {
  const v = values.filter(Number.isFinite).sort((a, b) => a - b);
  if (v.length === 0) return null;
  const mid = v.length >> 1;
  return v.length % 2 ? v[mid] : (v[mid - 1] + v[mid]) / 2;
}

/**
 * Rows {isp, down, up, ping} -> providers ranked by median download, each
 * with its test count and medians. Providers under MIN_TESTS are left out:
 * a median of two tests ranks nothing.
 */
export function rankProviders(rows, minTests = MIN_TESTS) {
  const by = new Map();
  for (const r of rows) {
    if (!by.has(r.isp)) by.set(r.isp, []);
    by.get(r.isp).push(r);
  }
  const providers = [];
  for (const [isp, rs] of by) {
    if (rs.length < minTests) continue;
    providers.push({
      isp,
      tests: rs.length,
      down: round1(median(rs.map((r) => r.down))),
      up: round1(median(rs.map((r) => r.up))),
      ping: Math.round(median(rs.map((r) => r.ping))),
    });
  }
  providers.sort((a, b) => b.down - a.down);
  providers.forEach((p, i) => (p.rank = i + 1));
  return providers;
}

/**
 * The comparison a phone sees: its city when at least two providers there
 * have enough tests, else its country. Null when neither has two.
 */
export function chooseScope(cityProviders, countryProviders) {
  if (cityProviders.length >= 2) return { scope: 'city', providers: cityProviders };
  if (countryProviders.length >= 2) return { scope: 'country', providers: countryProviders };
  return null;
}

function round1(v) {
  return v == null ? null : Math.round(v * 10) / 10;
}
