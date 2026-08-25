#!/usr/bin/env node
// apps/g_launcher/tools/icons/audit-live-icons.mjs
//
// Answers three questions against the published index, nothing local:
//   1. does any live theme name a brandPack
//   2. does the derived "-line" id for each theme actually exist
//   3. do the fourteen line packs carry sku, requires and tint
//
// node audit-live-icons.mjs
// CDN_ROOT=... node audit-live-icons.mjs

const ROOT = process.env.CDN_ROOT || 'https://cdn.mindberzerk.com/g-launcher';

async function j(url) {
  const r = await fetch(url);
  if (!r.ok) throw new Error(`${r.status} ${url}`);
  return r.json();
}

const index = await j(`${ROOT}/index.json`);
const list = Array.isArray(index.packs)
  ? index.packs
  : Array.isArray(index)
    ? index
    : Object.values(index.packs ?? index);

const typeOf = (p) => p.packType ?? p.type ?? '';
const ids = new Set(list.map((p) => p.id));
const themes = list.filter((p) => typeOf(p) === 'theme');
const lines = list.filter((p) => typeof p.id === 'string' && p.id.endsWith('-line'));

console.log(`root      ${ROOT}`);
console.log(`index     ${list.length} packs, ${themes.length} themes, ${lines.length} line packs`);
console.log(`base      arcticons-line ${ids.has('arcticons-line') ? 'present' : 'MISSING'}\n`);

// same rule as defaultLinePackFor and CdnIndex.isIncludedWith
const derive = (themeId) => `${themeId.replace(/-theme$/, '')}-line`;

let named = 0;
let resolves = 0;

console.log('themes');
for (const t of themes) {
  let icons = t.icons ?? t.spec?.icons ?? null;
  let where = 'index';
  if (!icons && t.path) {
    for (const f of ['theme.json', 'manifest.json']) {
      try {
        const doc = await j(`${ROOT}/${t.path}/${f}`);
        icons = doc.icons ?? doc.spec?.icons ?? null;
        where = f;
        break;
      } catch {
        /* try the next filename */
      }
    }
  }

  const brand = icons?.brandPack ?? null;
  const hero = icons?.heroPack ?? null;
  const want = derive(t.id ?? '');
  const exists = ids.has(want);

  if (brand) named += 1;
  if (exists) resolves += 1;

  const flags = [];
  if (!brand) flags.push('NO BRANDPACK');
  if (!exists) flags.push('DERIVED ID MISSING');
  if (brand && exists && brand !== want) flags.push(`DISAGREE brand=${brand} derived=${want}`);

  console.log(
    `  ${(t.id ?? '?').padEnd(24)} v${String(t.version ?? '?').padEnd(12)}` +
      ` brand=${String(brand ?? 'none').padEnd(24)}` +
      ` hero=${String(hero ?? '-').padEnd(20)}` +
      ` derived=${want.padEnd(24)}` +
      ` src=${where}` +
      (flags.length ? `  <- ${flags.join(', ')}` : ''),
  );
}

console.log(`\n  ${named}/${themes.length} themes name a brandPack`);
console.log(`  ${resolves}/${themes.length} derived ids exist in the index`);

console.log('\nline packs');
for (const p of lines) {
  const flags = [];
  if (!p.sku && p.id !== 'arcticons-line') flags.push('no sku');
  if (!(p.requires ?? []).includes('arcticons-line') && p.id !== 'arcticons-line') {
    flags.push('MISSING requires');
  }
  if (!p.tint && p.id !== 'arcticons-line') flags.push('no tint');
  if (typeof p.path === 'string' && /\.[a-z0-9]+$/i.test(p.path)) flags.push('PATH IS A FILE');
  console.log(
    `  ${p.id.padEnd(24)} v${String(p.version ?? '?').padEnd(12)}` +
      ` sku=${String(p.sku ?? '-').padEnd(22)}` +
      ` requires=[${(p.requires ?? []).join(',')}]`.padEnd(28) +
      ` tint=${String(p.tint ?? '-').padEnd(9)}` +
      ` path=${p.path ?? '-'}` +
      (flags.length ? `  <- ${flags.join(', ')}` : ''),
  );
}

// packs a theme points at that are not in the index at all
const dangling = themes
  .map((t) => t.icons?.brandPack ?? t.spec?.icons?.brandPack)
  .filter((b) => b && !ids.has(b));
if (dangling.length) {
  console.log(`\ndangling brandPack references: ${[...new Set(dangling)].join(', ')}`);
}
