#!/usr/bin/env node
/**
 * BUILD THE FOURTEEN OFFICIAL ICON PACKS.
 *
 *   node tools/icons/build-official-packs.mjs
 *
 * Reads `distros.json`, writes fourteen directories under `out/`, each holding
 * a `pack.json` of about 207 bytes. `ship-icons.sh` publishes them.
 *
 * ─── 207 BYTES, NOT 10.58 MB, AND WHY THAT IS NOT A SHORTCUT ────────────────
 *
 * Every one of these is a colour and a pointer at `arcticons-line`, which
 * carries the 13,622 drawings all fourteen share. The alternative was baking
 * the colour into fourteen full packs: 148 MB to say the same thing fourteen
 * times, fourteen uploads of ten megabytes each, and a fifteenth distro costing
 * another 10.58 MB instead of another row in a table.
 *
 * The drawings are identical in all fourteen. Only the hex differs. Shipping
 * fourteen copies of identical geometry would also mean a user who owns two
 * distros holding the same 13,622 paths twice on a phone with 32 GB.
 *
 * ─── WHAT THE DEVICE DOES WITH IT ───────────────────────────────────────────
 *
 * `BrandIconResolver` sees `extends`, loads that pack's geometry through the
 * path it already had, and stamps `tint` onto every glyph. `requires` in the
 * index is what makes the downloader fetch the base first; without it the
 * pointer installs alone and renders nothing, silently.
 */

import { mkdirSync, readFileSync, writeFileSync, rmSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const HERE = dirname(fileURLToPath(import.meta.url));
/**
 * ─── THE TABLE LIVES IN THE PANEL, AND THIS READS IT FROM THERE ─────────────
 *
 * One file, two readers, and the location is decided by the constrained one.
 * Node can read any path in the repo; a Next.js bundler cannot import from
 * outside `admin/`. So the canonical copy sits where the panel can reach it and
 * this reaches across, rather than the other way round.
 *
 * A copy under `tools/` would have drifted the first time a colour changed in
 * one and not the other, and the symptom would be a pack published in a hex
 * the panel never showed.
 */
const TABLE = resolve(HERE, '../../../../admin/src/lib/g-launcher/distros.json');

const HEX = /^#[0-9a-fA-F]{6}$/;
const PACK_ID = /^[a-z0-9][a-z0-9._-]*$/;

function die(message) {
  process.stderr.write(`build-official-packs: ${message}\n`);
  process.exit(1);
}

function args(argv) {
  const out = {};
  for (let i = 2; i < argv.length; i++) {
    const a = argv[i];
    if (!a.startsWith('--')) continue;
    out[a.slice(2).replace(/-([a-z])/g, (_, c) => c.toUpperCase())] = argv[++i];
  }
  return out;
}

const opts = args(process.argv);
const outDir = resolve(opts.out ?? join(HERE, 'out'));

let table;
try {
  table = JSON.parse(readFileSync(TABLE, 'utf8'));
} catch (e) {
  die(`cannot read distros.json: ${e.message}`);
}

const { base, distros, minAppVersion } = table;
if (!base?.packId) die('distros.json has no base pack');
if (!Array.isArray(distros) || distros.length === 0) die('distros.json has no distros');

// ─── EVERY REFUSAL HERE COSTS A RE-RUN. EACH ONE PAST HERE COSTS A PUBLISH ──
const seenPack = new Set();
const seenSku = new Set();
for (const d of distros) {
  for (const k of ['base', 'title', 'themeId', 'packId', 'sku', 'tint']) {
    if (!d[k]) die(`${d.packId ?? '(unnamed)'}: missing ${k}`);
  }
  if (!HEX.test(d.tint)) die(`${d.packId}: tint must be 6 hex digits, got ${d.tint}`);
  if (!PACK_ID.test(d.packId)) die(`${d.packId}: not a safe pack id`);
  // A pack extending itself is an infinite loop in the resolver, and the
  // resolver runs on the icon path, so it hangs the drawer rather than throwing
  // anywhere visible.
  if (d.packId === base.packId) die(`${d.packId}: a pack cannot extend itself`);
  // Two rows writing one id means the second silently overwrites the first at
  // publish, and the distro that lost points at another distro's colour.
  if (seenPack.has(d.packId)) die(`duplicate pack id: ${d.packId}`);
  if (seenSku.has(d.sku)) die(`duplicate sku: ${d.sku}`);
  seenPack.add(d.packId);
  seenSku.add(d.sku);
}

let total = 0;
const rows = [];
for (const d of distros) {
  const dir = join(outDir, d.packId);
  // WIPED, not merged. `sign-pack.mjs` signs a directory WHOLE and lists every
  // file it finds, so a stray leftover from an earlier run would be signed into
  // the pack and shipped to every device.
  rmSync(dir, { recursive: true, force: true });
  mkdirSync(dir, { recursive: true });

  const pack = {
    v: 1,
    id: d.packId,
    name: `${d.title} Icons`,
    extends: base.packId,
    tint: d.tint.toLowerCase(),
    license: base.license,
    attribution: base.attribution,
  };
  const json = JSON.stringify(pack, null, 2) + '\n';
  writeFileSync(join(dir, 'pack.json'), json);

  const bytes = Buffer.byteLength(json, 'utf8');
  total += bytes;
  rows.push({ id: d.packId, name: pack.name, tint: pack.tint, sku: d.sku, bytes });
}

const pad = (s, n) => String(s).padEnd(n);
process.stdout.write(`\nwrote ${rows.length} packs to ${outDir}\n\n`);
for (const r of rows) {
  process.stdout.write(
    `  ${pad(r.id, 24)} ${pad(r.tint, 9)} ${pad(r.sku, 22)} ${r.bytes} B\n`,
  );
}
process.stdout.write(
  `\n  ${total} bytes total, mean ${Math.round(total / rows.length)}\n` +
    `  all extend ${base.packId}, minAppVersion ${minAppVersion}\n\n`,
);
