#!/usr/bin/env node
/**
 * MAKE EACH DISTRO'S LINE PACK ITS DEFAULT, IN THE THEME ITSELF.
 *
 *   node tools/icons/set-brand-pack.mjs              # report only
 *   node tools/icons/set-brand-pack.mjs --write      # fetch, edit, stage
 *   node tools/icons/set-brand-pack.mjs --publish    # and sign and upload
 *   node tools/icons/set-brand-pack.mjs --publish --force   # even if unchanged
 *
 * ─── WHY THE THEME MUST NAME IT, GIVEN DART ALREADY DEFAULTS ────────────────
 *
 * `EffectiveTheme.resolve` falls back to `defaultLinePackFor(spec.id)` when a
 * theme names no `brandPack`, so Kali already resolves `kali-2024-line` at
 * render time. That was the cheap fix and it is not enough:
 *
 *   - The PANEL cannot see it. It looks for a reference in `theme.json` and
 *     correctly reports "used by nothing" on all fourteen, which is a warning
 *     that is both accurate and misleading, and a warning you learn to ignore
 *     is worse than no warning.
 *   - Nothing INSTALLS it. A pack is fetched because something asked for it,
 *     and a fallback computed at render time asks for nothing.
 *   - It is invisible. Someone reading `kali-2024-theme` sees no icon pack and
 *     has no way to know one is coming from Dart.
 *
 * Naming it in the theme makes the relationship a fact in the published data
 * rather than an inference in one language. The Dart fallback stays as the
 * floor for a theme published before this ran.
 *
 * ─── AND WHY THE WHOLE PACK IS RE-FETCHED ───────────────────────────────────
 *
 * A pack is signed over ALL its files, so changing one byte of `theme.json`
 * means re-signing the wallpapers too. Editing the index instead would be
 * faster and would produce a pack no device accepts.
 */

import { execFileSync } from 'node:child_process';
import { mkdirSync, rmSync, writeFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const HERE = dirname(fileURLToPath(import.meta.url));
const OUT = join(HERE, 'out');
const TABLE = resolve(HERE, '../../../../admin/src/lib/g-launcher/distros.json');

const cdn = process.env.MB_CDN ?? 'https://cdn.mindberzerk.com';
const prefix = process.env.MB_PREFIX ?? 'g-launcher';

const publish = process.argv.includes('--publish');
const write = publish || process.argv.includes('--write');

/**
 * Republish even when `brandPack` is already correct.
 *
 * ─── WHY IDEMPOTENCE NEEDED AN ESCAPE HATCH ───────────────────────────────
 *
 * Skipping a theme that already names its pack is right almost always: it
 * avoids fourteen pointless version bumps every run.
 *
 * It is wrong when the thing that needs fixing is somewhere ELSE in the pack.
 * The fourteen themes were republished before `merge-index.mjs` learned to
 * write `title`, so every one fell back to its own pack id and the app's
 * section headers read "arch-linux-theme packs" instead of "Arch Linux". The
 * `brandPack` was already correct, so the tool that could have fixed it
 * reported `done` fourteen times and did nothing.
 *
 * `--force` republishes regardless. The edit is still the same one; only the
 * decision to skip changes.
 */
const force = process.argv.includes('--force');

const die = (m) => {
  process.stderr.write(`set-brand-pack: ${m}\n`);
  process.exit(1);
};

async function getJson(url) {
  const r = await fetch(url, { cache: 'no-store' });
  if (!r.ok) throw new Error(`${url} returned ${r.status}`);
  return r.json();
}

const { readFileSync } = await import('node:fs');
const table = JSON.parse(readFileSync(TABLE, 'utf8'));

/** themeId -> the line pack that distro ships with. */
const wanted = new Map(table.distros.map((d) => [d.themeId, d.packId]));

let index;
try {
  index = await getJson(`${cdn}/${prefix}/index.json`);
} catch (e) {
  die(`could not read the catalogue: ${e.message}`);
}

const live = new Set((index.packs ?? []).map((p) => p.packId));
const themes = (index.packs ?? []).filter((p) => p.packType === 'theme');

process.stdout.write(`\n  ${themes.length} themes, ${wanted.size} in the table\n\n`);

const staged = [];

for (const t of themes) {
  const want = wanted.get(t.packId);
  if (!want) {
    process.stdout.write(`  SKIP   ${t.packId.padEnd(26)} not in distros.json\n`);
    continue;
  }
  // A theme pointing at a pack nobody published is a theme that resolves
  // nothing. Refused rather than written, because the failure is silent: icons
  // simply fall through to the generator.
  if (!live.has(want)) {
    process.stdout.write(`  SKIP   ${t.packId.padEnd(26)} '${want}' is not published\n`);
    continue;
  }

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

  theme.icons ??= {};
  if (theme.icons.brandPack === want && !force) {
    process.stdout.write(`  done   ${t.packId.padEnd(26)} already names '${want}'\n`);
    continue;
  }
  const had = theme.icons.brandPack;

  if (!write) {
    process.stdout.write(
      `  would  ${t.packId.padEnd(26)} ` +
        (had === want
          ? `republish, keeping '${want}'`
          : `set brandPack '${want}'${had ? ` (was '${had}')` : ''}`) +
        `\n`,
    );
    continue;
  }

  const dir = join(OUT, t.packId);
  rmSync(dir, { recursive: true, force: true });
  mkdirSync(dir, { recursive: true });

  let ok = true;
  for (const f of manifest.files ?? []) {
    // `PackPaths.installedFile` refuses slashes, so pack files are bare names
    // by construction. Anything else is a malformed manifest.
    if (f.path.includes('/') || f.path.includes('\\')) {
      process.stdout.write(`  SKIP   ${t.packId.padEnd(26)} unsafe path '${f.path}'\n`);
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

  theme.icons.brandPack = want;
  writeFileSync(join(dir, 'theme.json'), JSON.stringify(theme, null, 2) + '\n');
  // Regenerated by sign-pack. The fetched copy describes the OLD theme.json.
  rmSync(join(dir, 'manifest.json'), { force: true });
  rmSync(join(dir, 'manifest.sig'), { force: true });

  staged.push({ packId: t.packId, dir, want, sku: t.sku ?? null, minApp: t.minAppVersion });
  process.stdout.write(`  staged ${t.packId.padEnd(26)} brandPack '${want}'\n`);
}

if (!write) {
  process.stdout.write('\n  Re-run with --write to stage, or --publish to go live.\n\n');
  process.exit(0);
}

if (!publish) {
  process.stdout.write(`\n  staged ${staged.length} theme(s) under ${OUT}\n\n`);
  for (const s of staged) {
    process.stdout.write(
      `  ./tools/icons/publish-pack.sh ${s.dir} --type theme --version <n>` +
        `${s.sku ? ` --sku ${s.sku}` : ''} --min-app ${s.minApp}\n`,
    );
  }
  process.stdout.write('\n  Or re-run with --publish.\n\n');
  process.exit(0);
}

// ─── PUBLISH, ONE AT A TIME ────────────────────────────────────────────────
//
// Sequential on purpose. `publish-pack.sh` reads the live index, merges one
// entry and signs, so each run must see the previous one's write. In parallel
// the last to finish would silently drop every entry the others had added.
//
// ONE VERSION for all of them, from the clock: it is always above whatever is
// live, which is what publish-pack requires, and it makes the whole batch
// identifiable afterwards as one operation.
const version = Math.floor(Date.now() / 1000);
process.stdout.write(`\n  publishing ${staged.length} theme(s) at v${version}\n\n`);

let failed = 0;
for (const s of staged) {
  const args = [
    s.dir, '--type', 'theme', '--version', String(version), '--min-app', String(s.minApp),
  ];
  if (s.sku) args.push('--sku', s.sku);
  try {
    execFileSync(join(HERE, 'publish-pack.sh'), args, { stdio: 'pipe' });
    process.stdout.write(`  ok     ${s.packId}\n`);
  } catch (e) {
    failed++;
    // The script's own message, not a generic one: it says which step refused.
    const detail = (e.stderr?.toString() || e.stdout?.toString() || e.message).trim();
    process.stdout.write(`  FAILED ${s.packId}\n         ${detail.split('\n').pop()}\n`);
  }
}

process.stdout.write(
  failed
    ? `\n  ${failed} of ${staged.length} failed. The rest are live.\n\n`
    : `\n  all ${staged.length} themes now name their line pack.\n\n`,
);
process.exit(failed ? 1 : 0);
