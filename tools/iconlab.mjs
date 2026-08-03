#!/usr/bin/env node
/**
 * ICONLAB - find reference art for the roles the builders actually need.
 *
 * Run it with no arguments from anywhere in the repo:
 *
 *   node tools/iconlab.mjs
 *
 * It reads every folder and .zip under `iconlab/sources/`, matches files
 * against the ROLES in the icon builder (Phone, Messages, Files, App store and
 * the rest), copies the best candidate per source into
 * `iconlab/matches/<role>/`, and writes `iconlab/index.html` so the whole haul
 * can be judged at a glance.
 *
 * ── WHY THE SEARCH TERMS LIVE HERE ──────────────────────────────────────────
 *
 * Desktop icon themes are keyed by DESKTOP names, and Android is keyed by
 * package roles, and the two barely overlap. "gallery" finds nothing in
 * Papirus because the concept is `photos`, `shotwell`, `eog` or `gwenview`;
 * the app store is `software-center`, `snap-store`, `mintinstall` or
 * `discover`; files is `nautilus`, `dolphin` or `thunar` depending on which
 * desktop authored the set. So each role carries its Linux vocabulary as well
 * as its obvious name, which is the difference between a search that returns
 * nothing and one that returns the icon that was there the whole time.
 *
 * The role list mirrors CORE_ROLES in admin/src/lib/g-launcher/icon-pack.ts.
 * It is duplicated rather than imported because that file is TypeScript inside
 * the Next app and this is a zero-dependency script; when a role is added
 * there, add its search terms here.
 *
 * ── AND THE THING THIS SCRIPT IS NOT ────────────────────────────────────────
 *
 * It is a REFERENCE tool. Papirus, Numix, Qogir, Mint-Y and friends are GPL,
 * so their files cannot ship in a pack: the panel's own intake scans SVGs for
 * licence markers and refuses them, and the publish attestation asks you to
 * confirm the art is yours. What this is for is seeing how a set solves
 * "Settings" or "Files" before drawing your own, and for finding the CC0 and
 * MIT sets that CAN ship. Nothing here copies into the app.
 */

import { promises as fs } from 'node:fs';
import { execFileSync } from 'node:child_process';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const REPO = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const LAB = path.join(REPO, 'iconlab');
const SOURCES = path.join(LAB, 'sources');
const MATCHES = path.join(LAB, 'matches');

/** role id -> every name a desktop icon set might have used for it. */
const ROLE_TERMS = {
  phone: ['phone', 'dialer', 'call', 'telephone'],
  messages: ['message', 'sms', 'chat', 'conversation'],
  contacts: ['contact', 'people', 'addressbook', 'address-book'],
  camera: ['camera', 'cheese', 'photo-camera'],
  gallery: ['photos', 'gallery', 'shotwell', 'eog', 'gwenview', 'image-viewer'],
  settings: ['settings', 'preferences', 'systemsettings', 'configure', 'control-center'],
  clock: ['clock', 'alarm', 'time', 'chronometer'],
  calculator: ['calculator', 'calc', 'galculator', 'kcalc'],
  files: ['files', 'nautilus', 'dolphin', 'thunar', 'pcmanfm', 'nemo', 'filemanager', 'folder'],
  calendar: ['calendar', 'korganizer', 'evolution-calendar'],
  browser: ['browser', 'firefox', 'chromium', 'chrome', 'web', 'epiphany', 'konqueror'],
  store: ['software-center', 'software-store', 'snap-store', 'mintinstall', 'discover', 'synaptic', 'gnome-software', 'appstore'],
  voice: ['sound-recorder', 'recorder', 'audio-recorder', 'voice'],
  notes: ['notes', 'notepad', 'gnote', 'xpad', 'text-editor', 'gedit'],
  search: ['search', 'find', 'system-search'],
  youtube: ['youtube'],
  gmail: ['mail', 'thunderbird', 'evolution', 'geary', 'kmail', 'gmail'],
  maps: ['maps', 'map', 'marble', 'gnome-maps'],
  music: ['music', 'rhythmbox', 'audacious', 'clementine', 'amarok', 'spotify'],
  whatsapp: ['whatsapp', 'whatsie'],
  tiktok: ['tiktok'],
  facebook: ['facebook'],
  messenger: ['messenger', 'caprine'],
  instagram: ['instagram'],
  x: ['twitter', 'x-twitter'],
  snapchat: ['snapchat'],
  telegram: ['telegram'],
  opera: ['opera'],
  spotify: ['spotify'],
  boomplay: ['boomplay'],
  audiomack: ['audiomack'],
  netflix: ['netflix'],
  capcut: ['capcut'],
  shareit: ['shareit'],
  xender: ['xender'],
  mpesa: ['mpesa', 'm-pesa'],
  opay: ['opay'],
  palmpay: ['palmpay'],
  grecovery: ['recovery', 'rescue', 'backup', 'timeshift', 'deja-dup'],
};

const IMAGE_EXT = new Set(['.svg', '.png', '.webp', '.jpg', '.jpeg']);

/** Bigger is better, and a scalable SVG beats every raster. */
function score(file) {
  const m = file.match(/(?:^|\/)(\d+)x\1(?:@2x)?\//);
  const px = m ? parseInt(m[1], 10) : 0;
  if (file.endsWith('.svg')) return 10000 + px;
  return px || 1;
}

async function* walk(dir) {
  let entries;
  try {
    entries = await fs.readdir(dir, { withFileTypes: true });
  } catch {
    return;
  }
  for (const e of entries) {
    if (e.name.startsWith('.') || e.name === '__MACOSX') continue;
    const full = path.join(dir, e.name);
    if (e.isDirectory()) yield* walk(full);
    else yield full;
  }
}

/** Expand any .zip sitting in sources/, once. */
async function expandZips() {
  let entries;
  try {
    entries = await fs.readdir(SOURCES, { withFileTypes: true });
  } catch {
    return;
  }
  for (const e of entries) {
    if (!e.isFile() || path.extname(e.name).toLowerCase() !== '.zip') continue;
    const out = path.join(SOURCES, path.basename(e.name, path.extname(e.name)));
    try {
      await fs.access(out);
      continue; // already expanded
    } catch {
      // not expanded yet
    }
    try {
      execFileSync('unzip', ['-q', '-o', path.join(SOURCES, e.name), '-d', out]);
      console.log(`  unzipped ${e.name}`);
    } catch {
      console.log(`  could not unzip ${e.name}; expand it by hand`);
    }
  }
}

// ── run ─────────────────────────────────────────────────────────────────────

await fs.mkdir(SOURCES, { recursive: true });
await fs.rm(MATCHES, { recursive: true, force: true });
await fs.mkdir(MATCHES, { recursive: true });

console.log(`Sources: ${path.relative(REPO, SOURCES)}`);
await expandZips();

const sets = (await fs.readdir(SOURCES, { withFileTypes: true }))
  .filter((e) => e.isDirectory() && !e.name.startsWith('.'))
  .map((e) => e.name);

if (sets.length === 0) {
  console.log('\nNothing to scan. Drop an icon theme folder or a .zip into iconlab/sources/ and run again.');
  process.exit(0);
}
console.log(`Scanning ${sets.length} set(s): ${sets.join(', ')}\n`);

// role -> set -> best candidate
const hits = new Map(Object.keys(ROLE_TERMS).map((r) => [r, new Map()]));

for (const set of sets) {
  const root = path.join(SOURCES, set);
  for await (const file of walk(root)) {
    const ext = path.extname(file).toLowerCase();
    if (!IMAGE_EXT.has(ext)) continue;
    const stem = path.basename(file, ext).toLowerCase();

    for (const [role, terms] of Object.entries(ROLE_TERMS)) {
      if (!terms.some((t) => stem === t || stem.includes(t))) continue;

      let real;
      try {
        real = await fs.realpath(file);
      } catch {
        continue; // dangling symlink, of which these sets have thousands
      }

      const bucket = hits.get(role);
      const prev = bucket.get(set);
      const s = score(file);
      // One candidate per set per role: the best one. Twenty sizes of the same
      // drawing is not twenty options, it is one option and nineteen copies.
      if (!prev || s > prev.score) {
        bucket.set(set, { real, score: s, stem, ext });
      }
    }
  }
}

const sections = [];
let copied = 0;
let covered = 0;

for (const [role, bySet] of hits) {
  if (bySet.size === 0) {
    sections.push(`<h2>${role} <span class="none">nothing found</span></h2>`);
    continue;
  }
  covered++;
  const dir = path.join(MATCHES, role);
  await fs.mkdir(dir, { recursive: true });

  const cards = [];
  for (const [set, cand] of [...bySet].sort((a, b) => b[1].score - a[1].score)) {
    const name = `${set}__${cand.stem}${cand.ext}`;
    try {
      await fs.copyFile(cand.real, path.join(dir, name));
      copied++;
    } catch {
      continue;
    }
    cards.push(
      `<figure><img src="matches/${role}/${encodeURIComponent(name)}" alt="${cand.stem}">` +
        `<figcaption>${set}<br><span>${cand.stem}${cand.ext}</span></figcaption></figure>`,
    );
  }
  sections.push(`<h2>${role} <span class="count">${cards.length}</span></h2><div class="grid">${cards.join('')}</div>`);
  console.log(`${role.padEnd(12)} ${bySet.size} set(s)`);
}

const html = `<!doctype html>
<meta charset="utf-8">
<title>iconlab</title>
<style>
  body { background:#15121a; color:#e8e4f0; font:14px/1.5 system-ui, sans-serif; padding:32px; }
  h1 { font-size:20px; margin:0 0 4px; }
  .lead { color:#8b83a0; margin:0 0 28px; }
  h2 { margin:30px 0 10px; font-size:16px; text-transform:capitalize; }
  .count, .none { font-weight:normal; font-size:12px; color:#8b83a0; }
  .grid { display:grid; grid-template-columns:repeat(auto-fill,minmax(130px,1fr)); gap:12px; }
  figure { margin:0; background:#1e1a26; border:1px solid #2c2738; border-radius:12px; padding:12px; text-align:center; }
  figure img { width:64px; height:64px; object-fit:contain; }
  figcaption { margin-top:8px; font-size:11px; color:#cfc9dd; word-break:break-all; }
  figcaption span { color:#8b83a0; }
</style>
<h1>iconlab</h1>
<p class="lead">${covered} of ${Object.keys(ROLE_TERMS).length} roles found across ${sets.length} set(s): ${sets.join(', ')}.
Reference only: GPL sets cannot ship in a pack.</p>
${sections.join('\n')}`;

await fs.writeFile(path.join(LAB, 'index.html'), html);

console.log(`\n${copied} file(s) into ${path.relative(REPO, MATCHES)}`);
console.log(`Coverage: ${covered}/${Object.keys(ROLE_TERMS).length} roles`);
console.log(`Open: open ${path.relative(REPO, path.join(LAB, 'index.html'))}`);
