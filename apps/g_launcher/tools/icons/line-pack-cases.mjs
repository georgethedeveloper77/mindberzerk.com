#!/usr/bin/env node
/**
 * THE DEFAULT LINE PACK RULE, OUTSIDE FLUTTER.
 *
 *   node tools/icons/line-pack-cases.mjs
 *
 * `EffectiveTheme.defaultLinePackFor` decides which icon pack a distro uses when
 * its theme.json names none, which is all fourteen of them. Wrong in one
 * direction and a distro shows no line icons at all; wrong in the other and it
 * shows another distro's colour.
 *
 * A PORT, not the implementation. If the two drift the Dart is the truth.
 */
// Port of EffectiveTheme.defaultLinePackFor.
const f = id => { if(!id) return null;
  const base = id.endsWith('-theme') ? id.slice(0, -'-theme'.length) : id;
  return base ? `${base}-line` : null; };
const THEMES = ['kde-plasma-6','terminal','ubuntu-24-04','arch-linux-theme','deepin-23-theme',
 'elementary-os-8-theme','endeavouros-theme','fedora-40-theme','garuda-dr460nized-theme',
 'kali-2024-theme','linux-mint-22-theme','manjaro-kde-theme','pop-os-2204-theme','zorin-os-17-theme'];
const PACKS = ['kde-plasma-6-line','terminal-line','ubuntu-24-04-line','arch-linux-line','deepin-23-line',
 'elementary-os-8-line','endeavouros-line','fedora-40-line','garuda-dr460nized-line','kali-2024-line',
 'linux-mint-22-line','manjaro-kde-line','pop-os-2204-line','zorin-os-17-line'];
let p=0,x=0; const ok=(n,c)=>c?p++:(x++,console.log('  FAIL',n));
ok('all fourteen resolve to their own pack', THEMES.every((t,i)=>f(t)===PACKS[i]));
ok('bundled three work without -theme', f('terminal')==='terminal-line' && f('ubuntu-24-04')==='ubuntu-24-04-line');
ok('empty id yields null', f('')===null);
ok('a bare -theme yields null', f('-theme')===null);
ok('no theme maps to the base geometry', THEMES.every(t=>f(t)!=='arcticons-line'));
ok('results are unique', new Set(THEMES.map(f)).size===14);
console.log(`\n  ${p} passed, ${x} failed`);
process.exit(x?1:0);
