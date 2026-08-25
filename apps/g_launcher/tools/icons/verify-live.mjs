#!/usr/bin/env node
/**
 * IS EVERY PACK ACTUALLY ON THE CDN?
 *
 *   node tools/icons/verify-live.mjs
 *
 * Reads the PUBLISHED index over HTTP and asserts that the base pack and all
 * fourteen colour packs are in it, each declaring its dependency.
 *
 * ─── WHY THIS IS NOT PARANOIA ───────────────────────────────────────────────
 *
 * `arcticons-line` was published, confirmed present at seventeen packs, and was
 * gone an hour later with sixteen remaining and every other pack intact. The
 * cause was never found. Every step before this one can report success against
 * a local file and still leave the CDN wrong, so the only honest confirmation
 * is to fetch what a device would fetch.
 *
 * `cache: 'no-store'` because the index is published with `max-age=300` and a
 * verification that reads a cached copy verifies nothing.
 */

import { readFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const HERE = dirname(fileURLToPath(import.meta.url));
// The panel's copy, which is the canonical one. See build-official-packs.mjs.
const table = JSON.parse(
  readFileSync(resolve(HERE, '../../../../admin/src/lib/g-launcher/distros.json'), 'utf8'),
);

const cdn = process.env.MB_CDN ?? 'https://cdn.mindberzerk.com';
const prefix = process.env.MB_PREFIX ?? 'g-launcher';
const url = `${cdn}/${prefix}/index.json`;

const base = table.base.packId;
const want = [base, ...table.distros.map((d) => d.packId)];

let index;
try {
  const res = await fetch(url, { cache: 'no-store' });
  if (!res.ok) {
    process.stderr.write(`verify-live: ${url} returned ${res.status}\n`);
    process.exit(1);
  }
  index = await res.json();
} catch (e) {
  process.stderr.write(`verify-live: could not read ${url}: ${e.message}\n`);
  process.exit(1);
}

const byId = new Map((index.packs ?? []).map((p) => [p.packId, p]));
process.stdout.write(`\n  ${byId.size} packs in the live index\n\n`);

let bad = 0;
for (const id of want) {
  const p = byId.get(id);
  if (!p) {
    process.stdout.write(`  MISSING  ${id}\n`);
    bad++;
    continue;
  }

  const needs = p.requires ?? [];
  const notes = [];

  // A colour pack without its dependency installs, verifies and draws nothing.
  // That is the failure this whole field exists to prevent, so it is checked
  // here rather than trusted.
  if (id !== base && !needs.includes(base)) {
    notes.push(`does NOT require ${base}`);
    bad++;
  }
  // The version gate is what actually enforces the dependency: a build that
  // predates `requires` ignores the field and installs the pointer alone.
  if (id !== base && p.minAppVersion < table.minAppVersion) {
    notes.push(`minAppVersion ${p.minAppVersion} is below ${table.minAppVersion}`);
    bad++;
  }

  const state = notes.length ? 'WARN   ' : 'ok     ';
  process.stdout.write(
    `  ${state}  ${id.padEnd(24)} v${String(p.version).padEnd(12)}` +
      `${(p.sku ?? 'free').padEnd(22)}${notes.join('; ')}\n`,
  );
}

if (bad > 0) {
  process.stderr.write(`\n  ${bad} problem(s). The catalogue is not ready.\n\n`);
  process.exit(1);
}
process.stdout.write(`\n  all ${want.length} packs live and wired\n\n`);
