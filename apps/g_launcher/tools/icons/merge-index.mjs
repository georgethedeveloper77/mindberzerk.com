#!/usr/bin/env node
/**
 * MERGE ONE PACK ENTRY INTO THE LIVE SIGNED INDEX.
 *
 *   node tools/icons/merge-index.mjs <index.json> \
 *     --pack-id arcticons-line --type brand --version 1 \
 *     --min-app 6 --path packs/arcticons-line/pack.json \
 *     --size 11090000 --key-id mh-2026-07 [--sku icons_kali]
 *
 * ─── WHY THIS IS A FILE AND NOT A `node -e` IN THE SHELL SCRIPT ──────────────
 *
 * It started as one. Embedding a program inside a double-quoted bash string
 * means escaping backticks, dollars and quotes through two layers, and the
 * escaping broke silently: a template literal came out as a shell command
 * substitution and the script reported `updated: command not found` while
 * appearing to work. A file has no escaping layer at all.
 *
 * ─── WHAT IT REFUSES, AND WHY EACH ONE MATTERS ──────────────────────────────
 *
 * The index is ONE object naming every pack. Getting this wrong does not
 * corrupt a file, it unpublishes a catalogue, and the devices that already
 * downloaded those packs keep working so nobody notices for a while.
 */

import { readFileSync, writeFileSync } from 'node:fs';

function args(argv) {
  const out = {};
  const rest = [];
  for (let i = 2; i < argv.length; i++) {
    const a = argv[i];
    if (a.startsWith('--')) {
      out[a.slice(2).replace(/-([a-z])/g, (_, c) => c.toUpperCase())] = argv[++i];
    } else rest.push(a);
  }
  return [out, rest];
}

function fail(message) {
  process.stderr.write(`merge-index: ${message}\n`);
  process.exit(1);
}

const [o, rest] = args(process.argv);
const file = rest[0];
if (!file) fail('pass the index file to merge into');

for (const k of ['packId', 'type', 'version', 'minApp', 'path', 'size', 'keyId']) {
  if (!o[k]) fail(`--${k.replace(/[A-Z]/g, (c) => '-' + c.toLowerCase())} is required`);
}

let index;
try {
  index = JSON.parse(readFileSync(file, 'utf8'));
} catch (e) {
  fail(`the live index is not valid JSON: ${e.message}`);
}

// A missing or non-array `packs` means this is not the index. Writing into it
// anyway would produce a file that signs cleanly and describes nothing.
if (!Array.isArray(index.packs)) {
  fail('the live index has no packs array. Refusing to touch it.');
}

/**
 * ─── TITLE AND SUMMARY, WHICH THIS NEVER WROTE ──────────────────────────────
 *
 * `IndexPack` requires both. This built an entry without them, so every pack
 * published by the script carried none and the device fell back to the raw pack
 * id: cards read "kali-202..." and "kde-pla..." instead of "Kali Linux Icons".
 *
 * They default from the pack id rather than being required, because a theme
 * republished by `set-brand-pack.mjs` already has a title in the live index and
 * blanking it would be a regression in the other direction.
 */
const entry = {
  packId: o.packId,
  packType: o.type,
  path: o.path,
  version: Number(o.version),
  minAppVersion: Number(o.minApp),
  sizeBytes: Number(o.size),
  title: o.title || o.packId,
  summary: o.summary || '',
};
if (o.sku) entry.sku = o.sku;

/**
 * ─── WITHOUT THIS THE PACK INSTALLS AND DRAWS NOTHING ───────────────────────
 *
 * A derived icon pack is 200 bytes naming a colour and pointing at the pack
 * that holds the geometry. `requires` is what tells the downloader to fetch
 * that one first.
 *
 * This flag did not exist, so fourteen packs were published without it and
 * `verify-live.mjs` reported all fourteen as "does NOT require arcticons-line"
 * within seconds of the upload. That is exactly what the verifier is for: every
 * step before it had reported success.
 *
 * Comma separated, and OMITTED when absent rather than written as an empty
 * array: `signIndex` emits the field whenever it is defined and its
 * dropped-field guard treats `[]` as present, so an empty one would put
 * `"requires":[]` into the signed bytes of every pack that has no dependency.
 */
/**
 * The pack's colour, carried in the CATALOGUE and not only in the pack.
 *
 * The fourteen official packs differ by exactly this, so the storefront needs
 * it to show what is for sale, and needs it WITHOUT installing anything: the
 * geometry is already on the device, so a preview is the hex and nothing else.
 *
 * Read out of the pack rather than passed by hand where possible; see
 * publish-pack.sh. Validated to the same six-hex-digit shape `signIndex` will
 * enforce, so a bad value fails here with a clear message rather than at the
 * signing step with a stack trace.
 */
if (o.tint) {
  if (!/^#[0-9a-fA-F]{6}$/.test(o.tint)) fail(`tint must be #rrggbb, got '${o.tint}'`);
  entry.tint = o.tint.toLowerCase();
}

if (o.requires) {
  const ids = o.requires.split(',').map((s) => s.trim()).filter(Boolean);
  for (const id of ids) {
    if (id === o.packId) fail(`${o.packId} cannot require itself`);
  }
  if (ids.length > 0) entry.requires = ids;
}

const at = index.packs.findIndex((p) => p.packId === o.packId);
if (at >= 0) {
  const was = index.packs[at].version;
  if (entry.version <= was) {
    fail(
      `version ${entry.version} is not above the published ${was}.\n` +
      '  A device refuses a version it already has, so this would upload bytes that\n' +
      '  nothing installs. Nothing has been uploaded. Raise --version and re-run.',
    );
  }
  // Keep what is live when this run supplied nothing. A republish that silently
  // blanked a title would be invisible in the panel and obvious on every device.
  if (!o.title && index.packs[at].title) entry.title = index.packs[at].title;
  if (!o.summary && index.packs[at].summary) entry.summary = index.packs[at].summary;
  if (!o.tint && index.packs[at].tint) entry.tint = index.packs[at].tint;
  index.packs[at] = entry;
  process.stdout.write(`   updated ${o.packId} v${was} to v${entry.version}, ${index.packs.length} packs total\n`);
} else {
  index.packs.push(entry);
  process.stdout.write(`   added ${o.packId} v${entry.version}, ${index.packs.length} packs total\n`);
}

/**
 * SECONDS, NOT MILLISECONDS.
 *
 * The device holds a `generatedAt` floor and refuses an index older than the
 * one it already has, which is what stops a stale copy being replayed at it. A
 * millisecond value reads as roughly the year 56000, and once a device has
 * recorded that floor no genuine index ever satisfies it again. Updates stop,
 * permanently, on every device that saw the bad one, and a Play release is the
 * only way back.
 */
index.generatedAt = Math.floor(Date.now() / 1000);
index.keyId = o.keyId;

// Trailing newline, and this file is signed over its EXACT bytes afterwards.
// Reformatting it between here and `sign-index` invalidates the signature with
// no visible change to the content.
writeFileSync(file, JSON.stringify(index, null, 2) + '\n');
