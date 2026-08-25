#!/usr/bin/env node
/**
 * STRIP `heroPack` FROM EVERY LIVE THEME.
 *
 *   node tools/icons/strip-hero.mjs            # report only
 *   node tools/icons/strip-hero.mjs --write    # fetch, edit, stage for publish
 *
 * ─── WHAT THIS IS FOR ───────────────────────────────────────────────────────
 *
 * Every distro now has an official icon pack: 13,622 outline drawings in that
 * distro's own colour, resolved through `brandPack`. A hero pack sits ABOVE
 * that layer, so `kali-2024-icons` and its 54 hand-drawn PNGs would win for the
 * 54 apps it covers and the other 13,568 would come from the line set. That is
 * a mixed set, not the uniform brand-coloured one the product is.
 *
 * So the hero slot is emptied. Every theme keeps everything else it has.
 *
 * ─── AND WHY THE THEME IS EDITED RATHER THAN THE PACK DELETED ───────────────
 *
 * Deleting `kali-2024-icons` while `kali-2024-theme` still names it leaves the
 * theme resolving a pack that is not on disk. It would degrade quietly, because
 * a missing hero pack falls through to the layer below, and that is exactly the
 * kind of silent inconsistency that is impossible to find six months later.
 *
 * The panel refuses the delete for that reason and the refusal is right. This
 * removes the reference so the delete becomes legal, in that order.
 *
 * ─── IT DOWNLOADS THE WHOLE PACK, ON PURPOSE ────────────────────────────────
 *
 * A pack is signed over ALL its files, so changing one byte of `theme.json`
 * means re-signing everything: wallpapers, previews, the lot. Fetching the pack
 * back from the CDN and republishing it whole is the only way to keep the
 * signature honest. It is slower than editing the index and it is the only
 * version that produces a pack a device will accept.
 */

import { mkdirSync, rmSync, writeFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const HERE = dirname(fileURLToPath(import.meta.url));
const OUT = join(HERE, 'out');

const cdn = process.env.MB_CDN ?? 'https://cdn.mindberzerk.com';
const prefix = process.env.MB_PREFIX ?? 'g-launcher';
const write = process.argv.includes('--write');

function die(m) {
  process.stderr.write(`strip-hero: ${m}\n`);
  process.exit(1);
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

const themes = (index.packs ?? []).filter((p) => p.packType === 'theme');
if (themes.length === 0) die('no theme packs in the catalogue');

process.stdout.write(`\n  ${themes.length} themes in the catalogue\n\n`);

const staged = [];
const heroesReferenced = new Set();

for (const t of themes) {
  const root = `${cdn}/${prefix}/${t.path}`;

  let manifest;
  let theme;
  try {
    manifest = await getJson(`${root}/manifest.json`);
    theme = await getJson(`${root}/theme.json`);
  } catch (e) {
    process.stdout.write(`  SKIP   ${t.packId.padEnd(26)} ${e.message}\n`);
    continue;
  }

  const hero = theme?.icons?.heroPack;
  if (!hero) {
    process.stdout.write(`  clean  ${t.packId.padEnd(26)} no heroPack\n`);
    continue;
  }
  heroesReferenced.add(hero);

  if (!write) {
    process.stdout.write(`  would  ${t.packId.padEnd(26)} drop heroPack '${hero}'\n`);
    continue;
  }

  // ── fetch the whole pack, because the signature covers all of it ──────────
  const dir = join(OUT, t.packId);
  rmSync(dir, { recursive: true, force: true });
  mkdirSync(dir, { recursive: true });

  let ok = true;
  for (const f of manifest.files ?? []) {
    // `PackPaths.installedFile` refuses slashes, so a pack's files are bare
    // names by construction. Anything else here is a malformed manifest and is
    // refused rather than written somewhere unexpected.
    if (f.path.includes('/') || f.path.includes('\\')) {
      process.stdout.write(`  SKIP   ${t.packId.padEnd(26)} unsafe file path '${f.path}'\n`);
      ok = false;
      break;
    }
    try {
      const r = await fetch(`${root}/${f.path}`, { cache: 'no-store' });
      if (!r.ok) throw new Error(`${f.path} returned ${r.status}`);
      writeFileSync(join(dir, f.path), Buffer.from(await r.arrayBuffer()));
    } catch (e) {
      process.stdout.write(`  SKIP   ${t.packId.padEnd(26)} ${e.message}\n`);
      ok = false;
      break;
    }
  }
  if (!ok) {
    rmSync(dir, { recursive: true, force: true });
    continue;
  }

  // ── the edit ─────────────────────────────────────────────────────────────
  //
  // DELETED, not set to null or "". `ThemeSpec` reads `icons['heroPack'] as
  // String?`, so null would work, but an explicit null in a published theme
  // reads as a deliberate choice to have none rather than as a field that was
  // removed, and the two want different things the next time this is edited.
  delete theme.icons.heroPack;
  writeFileSync(join(dir, 'theme.json'), JSON.stringify(theme, null, 2) + '\n');

  // The manifest is regenerated by `sign-pack.mjs`, so the stale copy fetched
  // above must not survive into the directory it signs: it lists the OLD
  // theme.json hash, and a pack carrying two manifests is not a thing.
  rmSync(join(dir, 'manifest.json'), { force: true });
  rmSync(join(dir, 'manifest.sig'), { force: true });

  staged.push({ packId: t.packId, dir, hero, sku: t.sku ?? null, minApp: t.minAppVersion });
  process.stdout.write(`  staged ${t.packId.padEnd(26)} dropped '${hero}'\n`);
}

if (!write) {
  process.stdout.write(
    `\n  ${heroesReferenced.size} hero pack(s) referenced: ${[...heroesReferenced].join(', ') || 'none'}\n` +
      '\n  Re-run with --write to fetch and stage the edits.\n\n',
  );
  process.exit(0);
}

// ── the publish commands, printed rather than run ───────────────────────────
//
// Printed on purpose. This script already fetched and rewrote fourteen signed
// packs; having it also sign and upload them would make one command that
// rewrites the entire live catalogue with no chance to look at what it staged.
// The next step is one loop and it is worth reading first.
process.stdout.write(`\n  staged ${staged.length} theme(s) under ${OUT}\n\n`);
for (const s of staged) {
  process.stdout.write(
    `  ./tools/icons/publish-pack.sh ${s.dir} --type theme --version <n>` +
      `${s.sku ? ` --sku ${s.sku}` : ''} --min-app ${s.minApp}\n`,
  );
}
process.stdout.write(
  `\n  Then the hero packs are unreferenced and the panel will let you delete them:\n` +
    `  ${[...heroesReferenced].join(', ')}\n\n`,
);
