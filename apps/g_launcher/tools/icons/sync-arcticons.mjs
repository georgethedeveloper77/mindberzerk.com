#!/usr/bin/env node
/**
 * BUILD THE LINE-ART INDEX FROM A LOCAL ICON SET.
 *
 * ─── WHY THIS RUNS LOCALLY AND THE PANEL DOES NOT ───────────────────────────
 *
 * The admin panel deploys to Firebase App Hosting. A Next.js route there has no
 * shell, no clone of Arcticons, and no path back to this machine, so "the
 * builder runs the script" cannot mean what it sounds like. It has to mean:
 * this runs here, emits artifacts, and the panel reads them. That also makes
 * local dev and production identical, which the current setup is not.
 *
 * ─── WHAT IT READS ──────────────────────────────────────────────────────────
 *
 *   <set>/app/src/main/res/xml/appfilter.xml    the package to drawing map
 *   <set>/icons/white/<slug>.svg                the drawings
 *
 * NOT `generated/`. That directory does not carry the appfilter in the upstream
 * layout, and a script that looks for it fails with an empty index rather than
 * an error, which is the worst way for this to go wrong.
 *
 * ─── WHAT IT WRITES ─────────────────────────────────────────────────────────
 *
 *   out/index.json     32,951 packages, 1.25 MB, 0.40 MB gzipped on the wire
 *   out/glyphs.json    art for the requested slug set only
 *   out/glyphs-all.json  the whole set, only with --all, 12.8 MB
 *
 * The split is not tidiness. The map is small enough to hold in a tab; the art
 * is 12.78 MB normalised and must never be fetched by default to let somebody
 * pick forty icons.
 *
 * ─── USAGE ──────────────────────────────────────────────────────────────────
 *
 *   node tools/icons/sync-arcticons.mjs \
 *     --set "$HOME/Documents/icon packs/Arcticons-main" \
 *     --packages tools/icons/packages.txt
 *
 *   --set        path to the icon set clone (required)
 *   --packages   newline-delimited Android package ids to scope the bundle to
 *   --out        output directory, default tools/icons/out
 *   --all        also emit glyphs-all.json
 *   --source     set id written into the index, default arcticons
 *
 * NOTE ON zsh: no `!` appears in any string here, and none should be added
 * without a quoted heredoc, because history expansion fires inside double
 * quotes and the failure is a silently different file.
 */

import { readFileSync, writeFileSync, readdirSync, existsSync, mkdirSync, statSync } from 'node:fs';
import { join, resolve, basename } from 'node:path';
import { gzipSync } from 'node:zlib';

// ── licence, carried rather than assumed ────────────────────────────────────
//
// The Arcticons APP is GPL-3.0 and its ICONS are CC BY-SA 4.0. Those are
// different licences on different things and only the second one governs what
// is imported here. BY-SA permits commercial use and modification, including
// selling; it requires attribution to travel with the art and it forces the
// same licence onto anything derived, which means a recoloured set is
// redistributable by whoever buys it. That is a business fact, not a blocker,
// and `bulk-icons.ts` already has the `attributed` lane for it.
//
// The scan in `bulk-icons.ts` will NOT catch this on its own: these SVGs are
// bare geometry carrying no licence text, so they pass a scan built to find
// GPL and CC markers. The attribution is therefore written into the index here,
// at the only point in the pipeline that knows where the art came from.
const SETS = {
  arcticons: {
    appfilter: 'app/src/main/res/xml/appfilter.xml',
    icons: 'icons/white',
    box: 48,
    // 0 means "declares none, so the SVG default of 1 applies". Verified across
    // the set: not one file carries a stroke-width.
    strokeWidth: 0,
    license: 'CC-BY-SA-4.0',
    attribution: 'Arcticons by Donnnno, CC BY-SA 4.0',
  },
};

// ── args ────────────────────────────────────────────────────────────────────
function args(argv) {
  const out = { all: false, source: 'arcticons' };
  for (let i = 2; i < argv.length; i++) {
    const a = argv[i];
    if (a === '--all') out.all = true;
    else if (a.startsWith('--')) out[a.slice(2)] = argv[++i];
  }
  return out;
}

function die(msg) {
  process.stderr.write(`sync-arcticons: ${msg}\n`);
  process.exit(1);
}

// ── appfilter ───────────────────────────────────────────────────────────────
/**
 * Package id to drawing name.
 *
 * Regex rather than a DOM, matching `bulk-icons.ts`. The file is 48,132 flat
 * elements and building a tree for it is a lot of allocation for no benefit.
 *
 * ATTRIBUTE ORDER IS NOT ASSUMED. The element is matched first and each
 * attribute pulled from it separately, because `drawable` before `component`
 * occurs in the wild and one combined pattern silently matches half a file.
 *
 * FIRST ENTRY WINS. Apps with several launchable activities are listed several
 * times and the launcher resolves by package, so the first is the one that
 * would actually be used.
 */
function parseAppFilter(xml) {
  const map = new Map();
  const item = /<item\b([^>]*)>/gi;
  let m;
  let items = 0;
  while ((m = item.exec(xml)) !== null) {
    items++;
    const attrs = m[1];
    const component = /component\s*=\s*"([^"]*)"/i.exec(attrs)?.[1];
    const drawable = /drawable\s*=\s*"([^"]*)"/i.exec(attrs)?.[1];
    if (!component || !drawable) continue;
    const pkg =
      /\{([^/}]+)\//.exec(component)?.[1] ??
      /^:?([A-Za-z0-9_.]+)\//.exec(component)?.[1] ??
      null;
    if (!pkg) continue;
    if (!map.has(pkg)) map.set(pkg, drawable.toLowerCase());
  }
  return { map, items };
}

// ── glyph normalisation ─────────────────────────────────────────────────────
/**
 * Strip everything the composer does not need.
 *
 * Out: the XML declaration, editor ids, titles, and the `<defs><style>` block
 * with its single class rule. What survives is geometry plus a root element
 * carrying the paint, which is smaller and, more importantly, uniform: every
 * file then declares its stroke the same way, so `setStroke` has one shape to
 * handle instead of two.
 *
 * `fill="none"` is written onto the root EXPLICITLY. It was in the class rule
 * that just got deleted, and without it every open path fills solid black. This
 * is the line that turns a line set into a set of blobs if it is ever dropped.
 */
function normalise(svg) {
  let s = svg
    .replace(/<\?xml[^>]*\?>/g, '')
    .replace(/<!--[\s\S]*?-->/g, '')
    .replace(/<title>[\s\S]*?<\/title>/g, '')
    // Some files embed a C2PA content-provenance manifest, and it dwarfs the
    // drawing: termux.svg is 18,306 bytes of which 17,930 are a base64 blob and
    // 376 are the icon. Left in, a bundle is mostly provenance for art it is
    // not shipping.
    .replace(/<metadata>[\s\S]*?<\/metadata>/gi, '')
    .replace(/<desc>[\s\S]*?<\/desc>/gi, '')
    .replace(/<defs>[\s\S]*?<\/defs>/g, '')
    .replace(/\sid="[^"]*"/g, '')
    .replace(/\sclass="[^"]*"/g, '')
    .replace(/\s+/g, ' ')
    .trim();

  const open = /<svg\b[^>]*>/i.exec(s);
  if (!open) return null;

  const viewBox = /viewBox\s*=\s*"([^"]*)"/i.exec(open[0])?.[1] ?? '0 0 48 48';
  const root =
    `<svg xmlns="http://www.w3.org/2000/svg" viewBox="${viewBox}" ` +
    `fill="none" stroke="#ffffff" stroke-linecap="round" stroke-linejoin="round">`;

  return root + s.slice(open.index + open[0].length);
}

// ── main ────────────────────────────────────────────────────────────────────
const opts = args(process.argv);
const setSpec = SETS[opts.source];
if (!setSpec) die(`unknown source "${opts.source}". Known: ${Object.keys(SETS).join(', ')}`);
if (!opts.set) die('--set is required and must point at the icon set clone');

const root = resolve(opts.set.replace(/^~/, process.env.HOME ?? '~'));
if (!existsSync(root)) die(`no such directory: ${root}`);

const filterPath = join(root, setSpec.appfilter);
if (!existsSync(filterPath)) {
  die(`no appfilter at ${filterPath}\n  This layout expects ${setSpec.appfilter} under the clone root.`);
}
const iconDir = join(root, setSpec.icons);
if (!existsSync(iconDir)) die(`no icon directory at ${iconDir}`);

const outDir = resolve(opts.out ?? join(process.cwd(), 'tools/icons/out'));
mkdirSync(outDir, { recursive: true });

process.stdout.write(`reading  ${filterPath}\n`);
const { map: pkgToSlug, items } = parseAppFilter(readFileSync(filterPath, 'utf8'));

// Only drawings that exist on disk. An appfilter entry naming a file the set
// does not ship is routine, and carrying it would produce an index that
// promises art the panel then cannot draw.
const onDisk = new Set(
  readdirSync(iconDir).filter((f) => f.endsWith('.svg')).map((f) => basename(f, '.svg')),
);

const slugs = [...new Set([...pkgToSlug.values()].filter((s) => onDisk.has(s)))].sort();
const slugIndex = new Map(slugs.map((s, i) => [s, i]));

const map = {};
let dropped = 0;
for (const [pkg, slug] of pkgToSlug) {
  const i = slugIndex.get(slug);
  if (i === undefined) { dropped++; continue; }
  map[pkg] = i;
}

const revision = readRevision(root);

const index = {
  v: 1,
  source: opts.source,
  revision,
  license: setSpec.license,
  attribution: setSpec.attribution,
  box: setSpec.box,
  strokeWidth: setSpec.strokeWidth,
  slugs,
  map,
};

writeJson(join(outDir, 'index.json'), index);

// ── glyph bundles ───────────────────────────────────────────────────────────
const wanted = opts.packages ? readPackages(opts.packages) : null;
let bundleSlugs;
if (wanted) {
  bundleSlugs = [...new Set(wanted.map((p) => slugs[map[p]]).filter(Boolean))].sort();
  process.stdout.write(`scoped   ${wanted.length} packages -> ${bundleSlugs.length} drawings\n`);
} else {
  bundleSlugs = slugs;
  process.stdout.write(`scoped   no --packages given, bundling the whole set\n`);
}

// ─── AN EMPTY BUNDLE IS A FAILURE, NOT AN OUTPUT ───────────────────────────
//
// This wrote a valid, empty glyphs.json and exited 0, and it was uploaded to
// the CDN before anyone noticed. The cause was ordinary and will recur:
//
//     adb shell pm list packages ... > tools/icons/packages.txt
//
// The shell truncates the redirect target BEFORE running the command, so a
// disconnected phone leaves a zero-byte package list behind. `adb` prints its
// error, this reads an empty file, maps nothing, and reports "0 drawings" in
// the same calm tone it reports thirteen thousand.
//
// Nothing downstream catches it either. An empty object is valid JSON, the
// upload succeeds, and the panel loads a store with an index and no art, which
// presents as every icon silently falling through to the generator. That is a
// long way from the truncated file that caused it.
//
// So: refuse. A run that produced no art did not succeed.
if (bundleSlugs.length === 0) {
  die(
    'scoped to 0 drawings, so nothing would ship.\n' +
    (wanted && wanted.length === 0
      ? `  ${opts.packages} is empty. If it was written by a redirect from adb,\n` +
        '  check the phone is connected: the shell truncates the file even when adb fails.'
      : '  None of the listed packages appear in this set. Check the ids are Android\n' +
        '  application ids, one per line, with no trailing carriage returns.'),
  );
}

const bundle = bundleOf(bundleSlugs);
if (Object.keys(bundle).length === 0) {
  die(`resolved ${bundleSlugs.length} drawings but read none of them from ${iconDir}`);
}

writeJson(join(outDir, 'glyphs.json'), bundle);
if (opts.all && wanted) writeJson(join(outDir, 'glyphs-all.json'), bundleOf(slugs));

// ── report ──────────────────────────────────────────────────────────────────
process.stdout.write(
  `\n  appfilter items   ${items.toLocaleString()}\n` +
  `  packages mapped   ${Object.keys(map).length.toLocaleString()}\n` +
  `  drawings          ${slugs.length.toLocaleString()}\n` +
  (dropped ? `  dropped, no file  ${dropped.toLocaleString()}\n` : '') +
  `  licence           ${setSpec.license}\n` +
  `  attribution       ${setSpec.attribution}\n\n` +
  `Upload with:\n` +
  `  npx wrangler@latest r2 object put mindberzerk-cdn/g-launcher/icons/${opts.source}/index.json \\\n` +
  `    --file ${join(outDir, 'index.json')} --remote --content-type application/json \\\n` +
  `    --cache-control "public, max-age=300"\n`,
);

// ── helpers ─────────────────────────────────────────────────────────────────
function bundleOf(list) {
  const out = {};
  let skipped = 0;
  for (const slug of list) {
    const p = join(iconDir, `${slug}.svg`);
    if (!existsSync(p)) { skipped++; continue; }
    const n = normalise(readFileSync(p, 'utf8'));
    if (n) out[slug] = n; else skipped++;
  }
  if (skipped) process.stdout.write(`  unreadable        ${skipped}\n`);
  return out;
}

function writeJson(path, value) {
  const json = JSON.stringify(value);
  writeFileSync(path, json);
  const raw = Buffer.byteLength(json);
  const gz = gzipSync(json).length;
  process.stdout.write(
    `wrote    ${path}  ${(raw / 1e6).toFixed(2)} MB  (${(gz / 1e6).toFixed(2)} MB gzipped)\n`,
  );
}

function readPackages(path) {
  const p = resolve(path);
  if (!existsSync(p)) die(`no package list at ${p}`);
  // `trim` rather than a newline split alone: `adb shell` on macOS emits CRLF,
  // and a surviving carriage return makes every id miss the map, which reads as
  // "the index is broken" rather than "the file has invisible characters in it".
  return readFileSync(p, 'utf8')
    .split('\n')
    .map((l) => l.trim())
    .filter((l) => l && !l.startsWith('#'));
}

/** Whatever identifies this snapshot. A git ref if there is one, else mtime. */
function readRevision(dir) {
  const head = join(dir, '.git', 'HEAD');
  if (existsSync(head)) {
    const ref = readFileSync(head, 'utf8').trim();
    const m = /^ref: (.+)$/.exec(ref);
    if (m) {
      const p = join(dir, '.git', m[1]);
      if (existsSync(p)) return readFileSync(p, 'utf8').trim().slice(0, 12);
    }
    return ref.slice(0, 12);
  }
  return new Date(statSync(dir).mtime).toISOString().slice(0, 10);
}
