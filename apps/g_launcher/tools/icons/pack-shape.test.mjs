#!/usr/bin/env node
/**
 * The wire contract between build-vector-pack.mjs and BrandIconResolver.kt.
 *
 *   node tools/icons/pack-shape.test.mjs <path-to-pack.json>
 *
 * The Kotlin cannot be compiled without an Android SDK, so this asserts the
 * half of the contract that lives in a file. Every check here corresponds to a
 * line in the streaming reader that would fail SILENTLY if the shape drifted:
 * a reordered key forces the whole pack resident, a string where an array is
 * expected drops a drawing, a missing `style` renders outlines as solids.
 */
import { readFileSync } from 'node:fs';

const path = process.argv[2];
if (!path) { console.error('usage: pack-shape.test.mjs <pack.json>'); process.exit(2); }
const pack = JSON.parse(readFileSync(path, 'utf8'));
const keys = Object.keys(pack);

let pass = 0, fail = 0;
const ok = (n, c, x = '') => c ? pass++ : (fail++, console.log('  FAIL', n, x));

ok('has a version', pack.v === 1);
ok('has an id', typeof pack.id === 'string' && pack.id.length > 0);

/**
 * ─── TWO SHAPES, AND THIS ONLY EVER KNEW ONE ────────────────────────────────
 *
 * A BASE pack carries geometry: `icons` mapping packages to slugs, `glyphs`
 * holding each drawing once, and the ordering between them is load bearing.
 *
 * A DERIVED pack carries a colour and a pointer: `extends` and `tint`, about
 * 207 bytes, no art at all. Fourteen of them share one base.
 *
 * This file asserted the base shape unconditionally, so `ship-icons.sh` step 7
 * refused all fourteen with "failed the shape contract" on packs that were
 * perfectly correct. The contract was right; it was checking the wrong one.
 */
const derived = typeof pack.extends === 'string';

if (derived) {
  ok('extends a base pack', pack.extends.length > 0);
  ok('does not extend itself', pack.extends !== pack.id);
  ok('has a tint', /^#[0-9a-f]{6}$/i.test(pack.tint ?? ''));
  ok('has a display name', typeof pack.name === 'string' && pack.name.length > 0);
  // CC BY-SA requires the credit to travel with the work, and a derived pack IS
  // the work as far as a user is concerned. Inheriting it from the base would
  // ship fourteen products with no attribution on any of them.
  ok('carries its own attribution', (pack.attribution ?? '').length > 0);
  ok('carries its own licence id', (pack.license ?? '').length > 0);
  // A pointer that also carried art would be two sources for one drawing, and
  // the resolver would have to pick. It never should.
  ok('carries no geometry', !('glyphs' in pack) && !('icons' in pack));
  console.log(`\n  derived: ${pack.id} extends ${pack.extends} at ${pack.tint}`);
  console.log(`\n  ${pass} passed, ${fail} failed`);
  process.exit(fail ? 1 : 0);
}

ok('viewBox is a number', typeof pack.viewBox === 'number' && pack.viewBox > 0);
ok('style is fill or stroke', pack.style === undefined || ['fill','stroke'].includes(pack.style));
ok('strokeWidth positive when stroked',
   pack.style !== 'stroke' || (typeof pack.strokeWidth === 'number' && pack.strokeWidth > 0));

// THE ORDERING CHECK. Reversing these keys costs a device the whole pack in RAM
// and there is no other symptom until a budget phone runs out of it.
ok('icons precedes glyphs', keys.indexOf('icons') < keys.indexOf('glyphs'),
   `icons@${keys.indexOf('icons')} glyphs@${keys.indexOf('glyphs')}`);

const iconVals = Object.values(pack.icons ?? {});
ok('icons is not empty', iconVals.length > 0);
const stringRefs = iconVals.filter(v => typeof v === 'string');
const inlineObjs = iconVals.filter(v => v && typeof v === 'object');
ok('icon values are all one kind', stringRefs.length === 0 || inlineObjs.length === 0,
   `${stringRefs.length} refs, ${inlineObjs.length} inline`);

if (stringRefs.length) {
  const glyphs = pack.glyphs ?? {};
  const dangling = stringRefs.filter(s => !(s in glyphs));
  ok('every reference resolves', dangling.length === 0, dangling.slice(0,5).join(','));
  const vals = Object.values(glyphs);
  ok('glyph bodies are arrays', vals.every(v => Array.isArray(v)));
  ok('every path is a non-empty string',
     vals.every(v => v.every(d => typeof d === 'string' && d.length > 0)));
  ok('every path starts with a move',
     vals.every(v => v.every(d => /^[Mm]/.test(d.trim()))));
  const orphans = Object.keys(glyphs).filter(g => !stringRefs.includes(g));
  ok('no orphan glyphs', orphans.length === 0, `${orphans.length} unreferenced`);
  console.log(`\n  ${Object.keys(pack.icons).length.toLocaleString()} packages, ` +
              `${vals.length.toLocaleString()} drawings, ` +
              `${vals.reduce((a,v)=>a+v.length,0).toLocaleString()} paths`);
}
if (inlineObjs.length) {
  ok('inline glyphs carry d', inlineObjs.every(o => typeof o.d === 'string' && o.d.length > 0));
}

console.log(`\n  ${pass} passed, ${fail} failed`);
process.exit(fail ? 1 : 0);
