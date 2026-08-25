#!/usr/bin/env node
/**
 * REMOVE A PACK FROM THE CATALOGUE.
 *
 *   node tools/icons/unpublish-pack.mjs kali-2024-icons
 *   node tools/icons/unpublish-pack.mjs kali-2024-icons --write
 *   node tools/icons/unpublish-pack.mjs kali-2024-icons --write --key @path/to/key
 *
 * Prints what it would do, then does it with `--write`: drops the entry from
 * the live index, re-signs and uploads. The pack's OBJECTS are left in the
 * bucket, because unreferenced bytes cost pennies and a device mid-download
 * when the index changed should finish rather than fail.
 *
 * ─── EVERY REFUSAL HERE IS A DEVICE THAT WOULD BREAK ────────────────────────
 *
 * This is the one operation in the toolchain that takes something away, and
 * `commitIndex` in the panel refuses to drop a pack for exactly that reason. So
 * the checks are the point of the script, not preamble to it:
 *
 *   - a THEME still naming it, in `heroPack` or `brandPack`, would resolve a
 *     pack that is not in the catalogue
 *   - a PACK still requiring it would install and draw nothing
 *   - a BUNDLE still granting it would sell something that does not exist
 *
 * The first is what the panel means by "point that distro at another pack
 * first", and it is checked here by reading every live theme rather than by
 * trusting a field.
 */

import { execFileSync } from 'node:child_process';
import { existsSync, mkdtempSync, writeFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const HERE = dirname(fileURLToPath(import.meta.url));
const ROOT = join(HERE, '../..');
const SIGN = join(ROOT, '../../tools/sign-pack.mjs');

const cdn = process.env.MB_CDN ?? 'https://cdn.mindberzerk.com';
const bucket = process.env.MB_BUCKET ?? 'mindberzerk-cdn';
const prefix = process.env.MB_PREFIX ?? 'g-launcher';

const args = process.argv.slice(2);
const write = args.includes('--write');

/**
 * The signing key, same default and same `@path` convention as
 * `publish-pack.sh`.
 *
 * Omitting it made `sign-index` exit with "missing --key" AFTER every check had
 * passed and printed, which reads as the checks having failed. Nothing was
 * uploaded, because signing comes before the upload, but the ordering is what
 * saved it rather than anything deliberate about the error.
 */
const keyAt = args.indexOf('--key');
const key = keyAt >= 0 ? args[keyAt + 1] : `@${process.env.HOME}/.mindberzerk/pack-signing.key`;

// The pack id is the first bare argument, and `--key`'s VALUE is not one. It
// follows a flag, so it would otherwise be taken as the pack to delete.
const packId = args.find((a, i) => !a.startsWith('--') && args[i - 1] !== '--key');

const die = (m) => {
  process.stderr.write(`\nunpublish-pack: ${m}\n\n`);
  process.exit(1);
};

if (!packId) die('usage: unpublish-pack.mjs <packId> [--write] [--key @path]');

// CHECKED UP FRONT, not at the moment of signing. Every check below is a
// network read, and discovering a missing key after all of them have run and
// printed reads as the checks themselves having failed.
if (write) {
  const path = key.startsWith('@') ? key.slice(1) : null;
  if (path && !existsSync(path)) {
    die(`no signing key at ${path}. Pass --key @<path>, or set one up first.`);
  }
}

async function getJson(url) {
  const r = await fetch(url, { cache: 'no-store' });
  if (!r.ok) throw new Error(`${url} returned ${r.status}`);
  return r.json();
}

let index;
try {
  index = await getJson(`${cdn}/${prefix}/index.json`);
} catch (e) {
  die(`could not read the catalogue: ${e.message}`);
}

const target = (index.packs ?? []).find((p) => p.packId === packId);
if (!target) die(`'${packId}' is not in the catalogue. Nothing to do.`);

process.stdout.write(
  `\n  ${packId}  ${target.packType}  v${target.version}  ${target.sku ?? 'free'}\n\n`,
);

// ── who still points at it ──────────────────────────────────────────────────
const blockers = [];

for (const p of index.packs ?? []) {
  if (p.packId === packId) continue;
  if ((p.requires ?? []).includes(packId)) {
    blockers.push(`${p.packId} requires it`);
  }
}

for (const e of index.entitlements ?? []) {
  if ((e.grants ?? []).includes(packId)) {
    // Not fatal on its own: an entitlement granting a pack that no longer
    // exists sells nothing, which is a merchandising problem rather than a
    // broken device. Reported so it is a decision rather than a surprise.
    process.stdout.write(`  note   ${e.sku} still grants it\n`);
  }
}

// THE THEME CHECK, which is the one that matters. Read from the published
// theme.json rather than inferred, because `heroPack` is authored data and the
// index carries no copy of it.
const themes = (index.packs ?? []).filter((p) => p.packType === 'theme');
for (const t of themes) {
  let theme;
  try {
    theme = await getJson(`${cdn}/${prefix}/${t.path}/theme.json`);
  } catch {
    // A theme that cannot be read cannot be cleared, so it counts against the
    // delete. Silence here would be the delete proceeding on incomplete
    // evidence, which is the one thing this script must not do.
    blockers.push(`${t.packId} could not be read, so its icons are unknown`);
    continue;
  }
  const icons = theme?.icons ?? {};
  if (icons.heroPack === packId) blockers.push(`${t.packId} names it as heroPack`);
  if (icons.brandPack === packId) blockers.push(`${t.packId} names it as brandPack`);
}

if (blockers.length > 0) {
  process.stdout.write('  BLOCKED\n');
  for (const b of blockers) process.stdout.write(`    ${b}\n`);
  die('point those at another pack first, then re-run.');
}

process.stdout.write('  nothing references it\n');

if (!write) {
  process.stdout.write(
    `\n  Would drop '${packId}', leaving ${index.packs.length - 1} packs.\n` +
      '  Re-run with --write.\n\n',
  );
  process.exit(0);
}

// ── drop, sign, upload ──────────────────────────────────────────────────────
const work = mkdtempSync(join(tmpdir(), 'unpub-'));
try {
  const before = index.packs.length;
  index.packs = index.packs.filter((p) => p.packId !== packId);
  // Seconds, not milliseconds. The device holds a `generatedAt` floor and a
  // millisecond value reads as roughly the year 56000, after which no genuine
  // index ever satisfies it again and updates stop permanently.
  index.generatedAt = Math.floor(Date.now() / 1000);

  const file = join(work, 'index.json');
  writeFileSync(file, JSON.stringify(index, null, 2) + '\n');
  execFileSync('node', [SIGN, 'sign-index', file, '--key', key], { stdio: 'inherit' });

  for (const name of ['index.json', 'index.sig']) {
    execFileSync(
      'npx',
      [
        'wrangler@latest', 'r2', 'object', 'put',
        `${bucket}/${prefix}/${name}`,
        '--file', join(work, name),
        '--remote',
        '--content-type', name.endsWith('.sig') ? 'application/octet-stream' : 'application/json',
        '--cache-control', 'public, max-age=300',
      ],
      { stdio: 'pipe' },
    );
    process.stdout.write(`  uploaded ${name}\n`);
  }

  process.stdout.write(
    `\n  dropped '${packId}'. ${before} packs became ${index.packs.length}.\n` +
      `  Its objects are still in the bucket under ${target.path}.\n\n`,
  );
} finally {
  rmSync(work, { recursive: true, force: true });
}
