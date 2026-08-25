#!/usr/bin/env node
/**
 * WHAT IS THIS ZIP, AND CAN IT SHIP.
 *
 * ─── WHY A SEPARATE TOOL ────────────────────────────────────────────────────
 *
 * A folder of icons off the internet is not one thing. It might be an Android
 * icon pack with an appfilter, a GTK desktop theme with no package mapping at
 * all, a set of line drawings, a set of full-colour logos, or a licence that
 * forbids the whole exercise. `build-vector-pack.mjs` assumes the first and the
 * third, and assuming wrongly produces a pack that builds, signs, uploads and
 * looks wrong on a phone.
 *
 * So this answers the four questions in order of how expensive they are to get
 * wrong:
 *
 *   1. Can it legally ship?      A GPL set cannot, at any price, in any form.
 *   2. Where are its files?      appfilter and drawings, or neither.
 *   3. What kind of art is it?   Outlines tint; full-colour logos do not.
 *   4. How much would it cover?  Against a real device list, not in the abstract.
 *
 * Nothing here writes a pack. It reads a directory and tells you whether the
 * next command is worth running.
 *
 *   node tools/icons/inspect-iconset.mjs --set ~/Downloads/iconpacks/Whatever
 *   node tools/icons/inspect-iconset.mjs --set ... --packages tools/icons/packages.txt
 */

import { readFileSync, readdirSync, existsSync, statSync } from 'node:fs';
import { join, resolve, basename, relative } from 'node:path';

import { svgToPaths, viewBoxOf } from './svg-to-path.mjs';

// ── licence ─────────────────────────────────────────────────────────────────
//
// ORDER MATTERS: the first match wins, and the refusals are listed first so a
// dual-licensed file that mentions both GPL and MIT is refused rather than
// waved through on the friendlier of the two.
const LICENCES = [
  { id: 'GPL-3.0', ship: false, re: /GNU GENERAL PUBLIC LICENSE[\s\S]{0,400}Version 3/i },
  { id: 'GPL-2.0', ship: false, re: /GNU GENERAL PUBLIC LICENSE[\s\S]{0,400}Version 2/i },
  { id: 'AGPL-3.0', ship: false, re: /GNU AFFERO GENERAL PUBLIC/i },
  { id: 'LGPL', ship: false, re: /GNU LESSER GENERAL PUBLIC/i },
  { id: 'CC-BY-SA-4.0', ship: 'attributed', re: /Attribution[- ]ShareAlike 4\.0/i, readme: /CC[- ]BY[- ]SA[- ]?4/i },
  { id: 'CC-BY-4.0', ship: 'attributed', re: /Attribution 4\.0 International/i, readme: /CC[- ]BY[- ]?4(?![^\s]*SA)/i },
  { id: 'CC0-1.0', ship: true, re: /CC0 1\.0 Universal/i, readme: /\bCC0\b/i },
  { id: 'MIT', ship: true, re: /MIT License/i, readme: /\bMIT\b/ },
  { id: 'Apache-2.0', ship: true, re: /Apache License[\s\S]{0,200}Version 2\.0/i, readme: /Apache[- ]2/i },
];

const LICENCE_FILES = ['LICENSE', 'LICENSE.md', 'LICENSE.txt', 'COPYING', 'COPYING.txt', 'LICENCE'];
const README_FILES = ['README.md', 'README', 'README.txt', 'readme.md'];

/**
 * ─── THE ROOT LICENCE IS ABOUT THE CODE, NOT THE ART ────────────────────────
 *
 * This read the root LICENSE file and stopped, which reported Arcticons as
 * GPL-3.0 and CANNOT SHIP. That is true of the Arcticons APP and false of its
 * icons, and the repository says so plainly in its own README:
 *
 *     Arcticons uses the GPL-3.0 license.
 *     All icons are licensed under CC BY-SA 4.0.
 *
 * A single-file answer would have sent somebody to abandon a set they were
 * already publishing from legally. Icon repositories routinely license their
 * build scripts and their drawings separately, and the drawings are the only
 * thing being shipped here.
 *
 * So the art licence is looked for in three places, most specific first:
 *
 *   1. a licence file INSIDE the art directory, which is unambiguous
 *   2. a README sentence naming both a licence and the art
 *   3. the root licence, which is the fallback and is reported as such
 */
function findLicence(text) {
  for (const l of LICENCES) if (l.re.test(text)) return l;
  return null;
}

/** A sentence that names a licence AND says it applies to the drawings. */
function readArtLicenceFromReadme(root) {
  for (const name of README_FILES) {
    const p = join(root, name);
    if (!existsSync(p)) continue;
    let text;
    try { text = readFileSync(p, 'utf8'); } catch { continue; }
    for (const raw of text.split(/[\r\n]+/)) {
      // "icons", "artwork", "graphics" or "art" in the same sentence as a
      // licence name. Deliberately narrow: a README that merely MENTIONS a
      // licence elsewhere must not override the file on disk.
      if (!/\b(icons?|artwork|graphics|art)\b/i.test(raw)) continue;
      const hit = LICENCES.find((l) => l.readme && l.readme.test(raw));
      if (hit) return { ...hit, file: `${name} (stated for the art)` };
    }
  }
  return null;
}

function readLicence(root, artDir) {
  // 1. inside the art directory
  if (artDir) {
    for (const name of LICENCE_FILES) {
      const p = join(artDir, name);
      if (!existsSync(p)) continue;
      const hit = findLicence(readFileSync(p, 'utf8'));
      if (hit) return { ...hit, file: `${relative(root, p)} (beside the art)`, scope: 'art' };
    }
  }

  // 2. a README statement about the art
  const stated = readArtLicenceFromReadme(root);

  // 3. the root file, which describes the repository
  let repo = { id: 'none found', ship: null, file: null };
  for (const name of LICENCE_FILES) {
    const p = join(root, name);
    if (!existsSync(p)) continue;
    const hit = findLicence(readFileSync(p, 'utf8'));
    repo = hit ? { ...hit, file: name } : { id: 'unrecognised', ship: null, file: name };
    break;
  }

  if (stated) return { ...stated, scope: 'art', repo };
  return { ...repo, scope: 'repository', repo: null };
}

// ── layout ──────────────────────────────────────────────────────────────────
function walk(dir, depth = 0, out = []) {
  if (depth > 5) return out;
  let entries;
  try { entries = readdirSync(dir, { withFileTypes: true }); } catch { return out; }
  for (const e of entries) {
    if (e.name === '.git' || e.name === 'node_modules' || e.name === 'build') continue;
    const p = join(dir, e.name);
    if (e.isDirectory()) walk(p, depth + 1, out);
    else out.push(p);
  }
  return out;
}

/**
 * The directory holding the drawings.
 *
 * Chosen by COUNT rather than by name. Every set names it differently: `icons`,
 * `res/drawable`, `svg`, `scalable/apps`, or the repository root.
 *
 * ─── WITH ONE TIEBREAK, BECAUSE COUNT IS NOT ENOUGH ─────────────────────────
 *
 * Arcticons ships `icons/black` and `icons/white` with EXACTLY the same 15,057
 * drawings in each, so "most files" is a coin toss and it landed on black. The
 * geometry is identical and this pipeline recolours everything anyway, so the
 * pack would have been correct either way. It would also have reported the
 * wrong directory on screen, which is the kind of detail somebody later spends
 * an hour on.
 *
 * `white` wins ties because a launcher draws on a dark wallpaper far more often
 * than not, so a set inspected but never recoloured still reads.
 */
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

function findArtDir(files) {
  const byDir = new Map();
  for (const f of files) {
    if (!/\.svg$/i.test(f)) continue;
    const d = f.slice(0, f.lastIndexOf('/'));
    byDir.set(d, (byDir.get(d) ?? 0) + 1);
  }
  if (byDir.size === 0) return null;
  return [...byDir.entries()].sort(tieBreak)[0];
}

// ── main ────────────────────────────────────────────────────────────────────
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
  const out = {};
  for (let i = 2; i < argv.length; i++) {
    const a = argv[i];
    if (!a.startsWith('--')) continue;
    const key = a.slice(2).replace(/-([a-z])/g, (_, c) => c.toUpperCase());
    out[key] = argv[++i];
  }
  return out;
}

const opts = args(process.argv);
if (!opts.set) {
  process.stderr.write('usage: inspect-iconset.mjs --set <dir> [--packages <list>]\n');
  process.exit(2);
}
const root = resolve(opts.set.replace(/^~/, process.env.HOME ?? '~'));
if (!existsSync(root) || !statSync(root).isDirectory()) {
  process.stderr.write(`inspect-iconset: not a directory: ${root}\n`);
  process.exit(1);
}

const files = walk(root);
const svgs = files.filter((f) => /\.svg$/i.test(f));
const rasters = files.filter((f) => /\.(png|webp|jpe?g)$/i.test(f));
const appfilters = files.filter((f) => /appfilter\.xml$/i.test(f));
const art = findArtDir(files);
const licence = readLicence(root, art ? art[0] : null);

console.log(`\n  ${basename(root)}\n  ${'='.repeat(basename(root).length)}\n`);

// 1. licence
const verdict =
  licence.ship === false ? 'CANNOT SHIP'
  : licence.ship === 'attributed' ? 'ships with attribution'
  : licence.ship === true ? 'ships freely'
  : 'UNKNOWN, check by hand';
console.log(`  art licence    ${licence.id}  (${verdict})`);
if (licence.file) console.log(`                 from ${licence.file}`);
if (licence.repo && licence.repo.id !== licence.id) {
  console.log(`  repo licence   ${licence.repo.id}  (covers the code, not the drawings)`);
}
if (licence.scope === 'repository' && licence.ship === false) {
  console.log(`                 NOTE: this is the repository licence. Check the README:`);
  console.log(`                 many icon sets license their scripts and their art separately.`);
}
if (licence.ship === false) {
  console.log(
    `\n  A GPL icon set cannot ship over the CDN in any form, including\n` +
    `  recoloured, re-rendered or converted to path data. The output of a\n` +
    `  conversion is a derivative work and inherits the licence. This is the\n` +
    `  same reason Papirus and Numix have never been published here.\n`,
  );
}

// 2. layout
console.log(`\n  files          ${svgs.length.toLocaleString()} svg, ${rasters.length.toLocaleString()} raster`);
if (art) console.log(`  art directory  ${relative(root, art[0]) || '.'}  (${art[1].toLocaleString()} svg)`);
console.log(`  appfilter      ${appfilters.length ? relative(root, appfilters[0]) : 'NONE'}`);
if (!appfilters.length && svgs.length) {
  console.log(
    `\n  No appfilter, so this set does not say which Android app each drawing\n` +
    `  is for. It is a desktop icon theme, not an Android icon pack. Build it\n` +
    `  with --match-index, which maps drawings to packages by NAME against the\n` +
    `  Arcticons index. That is a guess where an appfilter is a statement, so\n` +
    `  expect to review the result rather than publish it.\n`,
  );
}
if (svgs.length === 0) {
  console.log(
    `\n  No vector art at all. A raster set cannot become a tintable vector\n` +
    `  pack; it can only ship as a hero pack of PNGs, which costs roughly\n` +
    `  3.5 KB per icon per distro instead of 0.8 KB once.\n`,
  );
}

// 3. what kind of art
if (art) {
  const sample = readdirSync(art[0]).filter((f) => /\.svg$/i.test(f)).slice(0, 400);
  let stroked = 0, filled = 0, multi = 0, unreadable = 0;
  const boxes = new Set();
  for (const f of sample) {
    let svg;
    try { svg = readFileSync(join(art[0], f), 'utf8'); } catch { unreadable++; continue; }
    const vb = viewBoxOf(svg);
    if (vb !== null) boxes.add(vb);
    const colours = new Set(
      [...svg.matchAll(/(?:fill|stroke)\s*[:=]\s*"?(#[0-9a-f]{3,8})/gi)].map((m) => m[1].toLowerCase()),
    );
    if (colours.size > 2) multi++;
    else if (/fill\s*:\s*none/i.test(svg) || /\bstroke\s*[:=]/i.test(svg)) stroked++;
    else filled++;
  }
  const n = sample.length || 1;
  console.log(`\n  sampled        ${sample.length} drawings`);
  console.log(`  outlines       ${stroked}  (${((stroked / n) * 100).toFixed(0)}%)`);
  console.log(`  solid, 1 tone  ${filled}`);
  console.log(`  multi-colour   ${multi}`);
  console.log(`  viewBoxes      ${boxes.size ? [...boxes].sort((a, b) => a - b).join(', ') : 'none declared'}`);
  if (unreadable) console.log(`  unreadable     ${unreadable}`);

  if (boxes.size > 1) {
    console.log(
      `\n  More than one viewBox. Drawings from different boxes render at\n` +
      `  different sizes with no error anywhere, so this set needs splitting\n` +
      `  or normalising before it can be one pack.\n`,
    );
  }
  if (multi / n > 0.3) {
    console.log(
      `\n  Mostly multi-colour art. A tinted vector pack flattens every drawing\n` +
      `  to ONE colour, so this set would lose the thing that makes it look\n` +
      `  like itself. It belongs in a hero pack, shipped as authored.\n`,
    );
  } else if (stroked / n > 0.66) {
    console.log(`\n  A line set. This is the shape build-vector-pack.mjs is for.\n`);
  }

  // conversion, on the sample
  let converted = 0;
  const skipped = new Map();
  for (const f of sample) {
    try {
      const { paths, skipped: sk } = svgToPaths(readFileSync(join(art[0], f), 'utf8'));
      if (paths.length) converted++;
      for (const s of sk) skipped.set(s, (skipped.get(s) ?? 0) + 1);
    } catch { /* counted as unconverted */ }
  }
  console.log(`  convertible    ${converted}/${sample.length}`);
  if (skipped.size) {
    console.log(`  unknown tags   ${[...skipped.entries()].map(([k, v]) => `${k} x${v}`).join(', ')}`);
  }
}

// 4. coverage against a real device
if (appfilters.length && opts.packages) {
  const xml = readFileSync(appfilters[0], 'utf8');
  const mapped = new Set();
  const re = /<item\b([^>]*)>/gi;
  let m;
  while ((m = re.exec(xml)) !== null) {
    const c = /component\s*=\s*"([^"]*)"/i.exec(m[1])?.[1];
    const pkg = c && /\{([^/}]+)\//.exec(c)?.[1];
    if (pkg) mapped.add(pkg);
  }
  const list = readFileSync(resolve(opts.packages), 'utf8')
    .split('\n').map((l) => l.trim().replace(/^package:/, '')).filter((l) => l && !l.startsWith('#'));
  const hit = list.filter((p) => mapped.has(p));
  console.log(`\n  your device    ${hit.length} of ${list.length} apps covered  (${((hit.length / (list.length || 1)) * 100).toFixed(0)}%)`);
  const miss = list.filter((p) => !mapped.has(p));
  if (miss.length) console.log(`  not covered    ${miss.slice(0, 8).join(', ')}${miss.length > 8 ? ' and more' : ''}`);
}

console.log();
