#!/usr/bin/env node
/**
 * BUILD A VECTOR ICON PACK.
 *
 * ─── WHY NOT RASTERS ────────────────────────────────────────────────────────
 *
 * Measured across the full Arcticons set, at the compression this pipeline
 * actually achieves:
 *
 *                              13,623 drawings
 *     PNG-8 at 256                  48.7 MB     x6 distros = 292.2 MB
 *     PNG-8 at 192                  27.4 MB     x6 distros = 164.4 MB
 *     vector, gzipped                5.4 MB     x6 distros =   5.4 MB
 *
 * The last row does not multiply, and that is the whole argument. A raster
 * bakes its colour, so six distros means six copies of one drawing. A vector
 * carries geometry and the distro supplies the colour at render time, so six
 * distros is one pack and five hex values.
 *
 * There is a second reason, less obvious and just as decisive. A raster pack of
 * this size cannot be BUILT in a browser: composing 13,623 icons through a
 * canvas is not something a tab survives. This script does no rasterising at
 * all, so a full pack takes seconds.
 *
 * ─── IT IS A BRAND PACK, WHICH IS WHY THERE IS NO NEW RESOLVER ──────────────
 *
 * `BrandIconResolver` already resolves path data by package id, already carries
 * a pack-level `viewBox`, already loads from `PackPaths` with a bundled
 * fallback, and already has the load/reload lifecycle wired into
 * `IconCache.onPackChanged`. `brandPack` is already a field on `IconStyle`,
 * already in `iconCacheId` on the Dart side and already in `fingerprint()` on
 * the Kotlin side.
 *
 * So this emits that same `pack.json`, with two additions:
 *
 *   "style": "stroke"    the glyphs are outlines, not solids
 *   "strokeWidth": 1     in viewBox units, pack-level
 *
 * No new IconStyle field, no Pigeon regeneration, no eight-place ritual, and
 * no third `BrandTreatment` case renumbering every downstream codec id.
 *
 * ─── THE INDIRECTION IS NOT OPTIONAL ────────────────────────────────────────
 *
 * 32,951 packages share 13,623 drawings, so the average drawing is referenced
 * 2.4 times. Inlining path data under each package would take the file from
 * roughly 26 MB to 58 MB to say the same thing. So `icons` maps a package to a
 * SLUG, and `glyphs` holds each drawing once.
 *
 *   { v, id, name, viewBox, style, strokeWidth, license, attribution,
 *     icons:  { "com.whatsapp": "whatsapp", ... },
 *     glyphs: { "whatsapp": ["M...", "M..."], ... } }
 *
 * `icons` comes BEFORE `glyphs`, deliberately. The device streams with
 * `android.util.JsonReader`, reads the package map, intersects it with what is
 * actually installed, and then skips every glyph body it does not need. A phone
 * with 250 apps keeps 250 drawings, about 450 KB, and never holds the other
 * 13,373 in memory. Reversing these two keys would force the whole file
 * resident, which a 2 GB device cannot afford.
 *
 * A Simple Icons pack keeps working unchanged: its `icons` values are OBJECTS
 * (`{d, hex}`) rather than slug strings, and the resolver branches on the type.
 *
 * `glyphs` values are ARRAYS. A drawing is typically one path plus two or three
 * lines and circles, and each is a separate `PathParser.createPathFromPathData`
 * call on the device. Concatenating them into one string would work for fills
 * and break for strokes, because a `M` that starts a new subpath is not the
 * same as a fresh path when round caps are involved.
 *
 * ─── USAGE ──────────────────────────────────────────────────────────────────
 *
 *   node tools/icons/build-vector-pack.mjs \
 *     --set "$HOME/Downloads/iconpacks/Arcticons-main" \
 *     --id arcticons-line --name "Arcticons"
 *
 *   --packages   scope to a package list, as sync-arcticons.mjs does
 *   --out        output directory, default tools/icons/out
 */

import { readFileSync, writeFileSync, readdirSync, existsSync, mkdirSync, statSync } from 'node:fs';
import { join, resolve, basename } from 'node:path';
import { gzipSync } from 'node:zlib';

import { svgToPaths, viewBoxOf, strokeWidthOf } from './svg-to-path.mjs';

const SETS = {
  arcticons: {
    appfilter: 'app/src/main/res/xml/appfilter.xml',
    icons: 'icons/white',
    viewBox: 48,
    // No file declares one, so the SVG default of 1 applies. Recorded on the
    // PACK rather than per glyph, because it is a property of how the set was
    // drawn and a per-glyph copy of the same number 13,623 times is 100 KB of
    // nothing.
    strokeWidth: 1,
    license: 'CC-BY-SA-4.0',
    attribution: 'Arcticons by Donnnno, CC BY-SA 4.0',
  },
};

/**
 * Flags to an options object.
 *
 * KEBAB IS CONVERTED TO CAMEL, because `--match-index` otherwise arrives as
 * `opts['match-index']` while the code reads `opts.matchIndex`, which is
 * `undefined`, which took the no-appfilter branch and refused a set it had just
 * been told how to map. No error, no warning, and the message it printed was
 * the exact instruction the user had already followed.
 */
function args(argv) {
  const out = { source: 'arcticons' };
  for (let i = 2; i < argv.length; i++) {
    const a = argv[i];
    if (!a.startsWith('--')) continue;
    const key = a.slice(2).replace(/-([a-z])/g, (_, c) => c.toUpperCase());
    out[key] = argv[++i];
  }
  return out;
}

/** The directory with the most SVGs. See the layout note at the call site. */
/**
 * Most files wins; on a tie, prefer a `white` or `light` directory.
 *
 * Sets that ship both variants have identical geometry in each, so the pack is
 * correct either way. Naming the one a launcher would actually use keeps the
 * report honest.
 */
function tieBreak(a, b) {
  if (b[1] !== a[1]) return b[1] - a[1];
  const rank = (p) => (/\b(white|light)\b/i.test(p) ? 0 : /\b(black|dark)\b/i.test(p) ? 2 : 1);
  return rank(a[0]) - rank(b[0]);
}

function findArtDir(dir) {
  const counts = new Map();
  (function walk(d, depth) {
    if (depth > 5) return;
    let entries;
    try { entries = readdirSync(d, { withFileTypes: true }); } catch { return; }
    for (const e of entries) {
      if (e.name === '.git' || e.name === 'node_modules') continue;
      if (e.isDirectory()) walk(join(d, e.name), depth + 1);
      else if (e.name.endsWith('.svg')) counts.set(d, (counts.get(d) ?? 0) + 1);
    }
  })(dir, 0);
  if (counts.size === 0) return null;
  return [...counts.entries()].sort(tieBreak)[0][0];
}

/** Any appfilter.xml under [dir], or null. Shallowest wins. */
function findAppFilter(dir) {
  const found = [];
  (function walk(d, depth) {
    if (depth > 5) return;
    let entries;
    try { entries = readdirSync(d, { withFileTypes: true }); } catch { return; }
    for (const e of entries) {
      if (e.name === '.git' || e.name === 'node_modules') continue;
      if (e.isDirectory()) walk(join(d, e.name), depth + 1);
      else if (e.name.toLowerCase() === 'appfilter.xml') found.push({ p: join(d, e.name), depth });
    }
  })(dir, 0);
  if (found.length === 0) return null;
  return found.sort((a, b) => a.depth - b.depth)[0].p;
}

function die(msg) {
  process.stderr.write(`build-vector-pack: ${msg}\n`);
  process.exit(1);
}

/** Same parser as sync-arcticons.mjs, and the same reasons. First entry wins. */
function parseAppFilter(xml) {
  const map = new Map();
  const item = /<item\b([^>]*)>/gi;
  let m;
  let items = 0;
  while ((m = item.exec(xml)) !== null) {
    items++;
    const component = /component\s*=\s*"([^"]*)"/i.exec(m[1])?.[1];
    const drawable = /drawable\s*=\s*"([^"]*)"/i.exec(m[1])?.[1];
    if (!component || !drawable) continue;
    const pkg = /\{([^/}]+)\//.exec(component)?.[1];
    if (!pkg) continue;
    if (!map.has(pkg)) map.set(pkg, drawable.toLowerCase());
  }
  return { map, items };
}

const opts = args(process.argv);
const spec = { ...(SETS[opts.source] ?? SETS.arcticons) };
if (!opts.set) die('--set is required');

const root = resolve(opts.set.replace(/^~/, process.env.HOME ?? '~'));
if (!existsSync(root)) die(`no such directory: ${root}`);

// ─── LAYOUT IS FOUND, NOT ASSUMED ───────────────────────────────────────────
//
// The hardcoded paths above are right for Arcticons and wrong for everything
// else. Every set names its directories differently: `icons`, `res/drawable`,
// `svg`, `scalable/apps`, or the repository root. Assuming produces a clean
// "no icon directory" refusal on a set that is sitting right there, which sends
// somebody looking for a bug in the set rather than in this script.
//
// `--icons` and `--appfilter` override, for the case where a set ships two art
// directories and the larger one is not the one wanted.
const iconDir = opts.icons
  ? resolve(root, opts.icons)
  : existsSync(join(root, spec.icons)) ? join(root, spec.icons) : findArtDir(root);
if (!iconDir || !existsSync(iconDir)) {
  die(`no directory of SVGs under ${root}. Run inspect-iconset.mjs to see what is there.`);
}

const filterPath = opts.appfilter
  ? resolve(root, opts.appfilter)
  : existsSync(join(root, spec.appfilter)) ? join(root, spec.appfilter) : findAppFilter(root);

// ─── NO APPFILTER IS NOT A DEAD END ─────────────────────────────────────────
//
// A desktop icon theme has drawings and no idea which Android app each one is
// for. But the Arcticons index already maps 13,623 drawing NAMES to 32,951
// packages, and icon sets overwhelmingly agree on those names: `whatsapp.svg`
// is whatsapp everywhere. So `--match-index` borrows that mapping.
//
// It is a GUESS where an appfilter is a STATEMENT, and it is labelled as one in
// the report, because a name collision here silently puts the wrong drawing on
// an app rather than failing.
if (!filterPath && !opts.matchIndex) {
  die(
    `no appfilter under ${root}.\n` +
    '  This looks like a desktop icon theme rather than an Android icon pack.\n' +
    '  Map it by drawing name instead:  --match-index tools/icons/out/index.json',
  );
}

const outDir = resolve(opts.out ?? join(process.cwd(), 'tools/icons/out'));
mkdirSync(outDir, { recursive: true });

let pkgToSlug;
let items = 0;
let mappedBy;
if (filterPath) {
  process.stdout.write(`reading  ${filterPath}\n`);
  ({ map: pkgToSlug, items } = parseAppFilter(readFileSync(filterPath, 'utf8')));
  mappedBy = 'appfilter';
} else {
  const indexPath = resolve(opts.matchIndex);
  if (!existsSync(indexPath)) die(`no index at ${indexPath}`);
  process.stdout.write(`matching by name against  ${indexPath}\n`);
  const index = JSON.parse(readFileSync(indexPath, 'utf8'));
  const have = new Set(
    readdirSync(iconDir).filter((f) => f.endsWith('.svg')).map((f) => basename(f, '.svg')),
  );
  pkgToSlug = new Map();
  for (const [pkg, i] of Object.entries(index.map ?? {})) {
    const slug = index.slugs?.[i];
    if (slug && have.has(slug)) pkgToSlug.set(pkg, slug);
  }
  items = Object.keys(index.map ?? {}).length;
  mappedBy = 'name match';
}

const wanted = opts.packages ? new Set(readPackages(opts.packages)) : null;
const onDisk = new Set(
  readdirSync(iconDir).filter((f) => f.endsWith('.svg')).map((f) => basename(f, '.svg')),
);

// ── convert ─────────────────────────────────────────────────────────────────
const glyphs = {};
const problems = { noViewBox: [], wrongBox: [], empty: [], skipped: new Map(), odd: [] };

const neededSlugs = new Set();
for (const [pkg, slug] of pkgToSlug) {
  if (wanted && !wanted.has(pkg)) continue;
  if (!onDisk.has(slug)) continue;
  neededSlugs.add(slug);
}

for (const slug of [...neededSlugs].sort()) {
  const svg = readFileSync(join(iconDir, `${slug}.svg`), 'utf8');

  const box = viewBoxOf(svg);
  if (box === null) { problems.noViewBox.push(slug); continue; }
  // A set that mixed 24 and 48 would render half its icons at double size with
  // no error anywhere, so the box is checked per file rather than assumed once.
  if (box !== spec.viewBox) { problems.wrongBox.push(`${slug}(${box})`); continue; }

  const declared = strokeWidthOf(svg);
  if (declared !== null && declared !== spec.strokeWidth) problems.odd.push(`${slug}(${declared})`);

  const { paths, skipped } = svgToPaths(svg);
  for (const s of skipped) problems.skipped.set(s, (problems.skipped.get(s) ?? 0) + 1);
  if (paths.length === 0) { problems.empty.push(slug); continue; }

  glyphs[slug] = paths;
}

// ── map, restricted to drawings that survived ───────────────────────────────
const slugs = Object.keys(glyphs).sort();
const haveGlyph = new Set(slugs);
const map = {};
let dropped = 0;
// Sorted so the file is byte-stable across runs: an unsorted object key order
// follows insertion, which follows the appfilter, which changes upstream. A
// pack that differs only in key order still re-signs, re-uploads and re-
// downloads to every device for no change in content.
for (const pkg of [...pkgToSlug.keys()].sort()) {
  const slug = pkgToSlug.get(pkg);
  if (wanted && !wanted.has(pkg)) continue;
  if (!haveGlyph.has(slug)) { dropped++; continue; }
  map[pkg] = slug;
}

if (slugs.length === 0) {
  die('produced no glyphs, so nothing would ship. Check --set points at a full clone.');
}

// KEY ORDER IS PART OF THE FORMAT. `icons` must precede `glyphs` so the device
// can stream-read the package map and skip the bodies it does not need.
// `JSON.stringify` preserves insertion order for string keys, so this object
// literal IS the wire order. Reordering these two lines would silently force
// the whole pack resident on every device that installs it.
const pack = {
  v: 1,
  id: opts.id ?? `${opts.source}-line`,
  name: opts.name ?? 'Arcticons',
  revision: readRevision(root),
  viewBox: spec.viewBox,
  style: 'stroke',
  strokeWidth: spec.strokeWidth,
  license: spec.license,
  attribution: spec.attribution,
  icons: map,
  glyphs,
};

const json = JSON.stringify(pack);

// ─── ITS OWN DIRECTORY, NAMED FOR THE PACK ──────────────────────────────────
//
// `sign-pack.mjs sign <dir>` walks the WHOLE directory and lists every file it
// finds in the manifest. Writing `pack.json` beside `index.json` and
// `glyphs.json`, which is what `out/` already holds, would sign all three into
// one pack: 15 MB of build artifacts shipped to every device, and a verify that
// still passes because the manifest honestly describes what is there.
//
// `pack.json`, not `vector.json`: this IS a brand pack, and both the resolver
// and the verifier already look for that name inside an installed pack.
const packDir = join(outDir, pack.id);
mkdirSync(packDir, { recursive: true });
writeFileSync(join(packDir, 'pack.json'), json);

// ── report ──────────────────────────────────────────────────────────────────
const raw = Buffer.byteLength(json);
const gz = gzipSync(json).length;
const pathCount = Object.values(glyphs).reduce((a, p) => a + p.length, 0);

process.stdout.write(
  `\nwrote    ${join(packDir, 'pack.json')}\n` +
  `         ${(raw / 1e6).toFixed(2)} MB raw, ${(gz / 1e6).toFixed(2)} MB gzipped\n\n` +
  `  mapped by         ${mappedBy}${mappedBy === 'name match' ? '  (a guess, review before publishing)' : ''}\n` +
  `  source entries    ${items.toLocaleString()}\n` +
  `  packages mapped   ${Object.keys(map).length.toLocaleString()}\n` +
  `  drawings          ${slugs.length.toLocaleString()}\n` +
  `  paths             ${pathCount.toLocaleString()}  (${(pathCount / slugs.length).toFixed(1)} per drawing)\n` +
  `  bytes per drawing ${Math.round(raw / slugs.length)}\n` +
  (dropped ? `  dropped, no file  ${dropped.toLocaleString()}\n` : '') +
  report(problems) +
  `  licence           ${spec.license}\n` +
  `  attribution       ${spec.attribution}\n` +
  `\nSign and publish:\n` +
  `  ./tools/icons/publish-pack.sh ${packDir} --version <n>\n`,
);

function report(p) {
  let out = '';
  const line = (label, list) =>
    list.length ? `  ${label.padEnd(17)} ${list.length}  ${list.slice(0, 6).join(', ')}${list.length > 6 ? ' and more' : ''}\n` : '';
  out += line('no viewBox', p.noViewBox);
  out += line('wrong viewBox', p.wrongBox);
  out += line('drew nothing', p.empty);
  out += line('odd stroke width', p.odd);
  if (p.skipped.size) {
    const s = [...p.skipped.entries()].map(([k, n]) => `${k} x${n}`).join(', ');
    out += `  skipped elements  ${s}\n`;
  }
  return out;
}

function readPackages(path) {
  const p = resolve(path);
  if (!existsSync(p)) die(`no package list at ${p}`);
  return readFileSync(p, 'utf8')
    .split('\n')
    .map((l) => l.trim().replace(/^package:/, ''))
    .filter((l) => l && !l.startsWith('#'));
}

function readRevision(dir) {
  const head = join(dir, '.git', 'HEAD');
  if (existsSync(head)) {
    const ref = readFileSync(head, 'utf8').trim();
    const m = /^ref: (.+)$/.exec(ref);
    if (m && existsSync(join(dir, '.git', m[1]))) {
      return readFileSync(join(dir, '.git', m[1]), 'utf8').trim().slice(0, 12);
    }
    return ref.slice(0, 12);
  }
  return new Date(statSync(dir).mtime).toISOString().slice(0, 10);
}
