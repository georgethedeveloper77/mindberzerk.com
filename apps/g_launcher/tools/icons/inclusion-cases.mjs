#!/usr/bin/env node
/**
 * THE INCLUSION RULE, OUTSIDE ANDROID.
 *
 *   node tools/icons/inclusion-cases.mjs
 *
 * `CdnIndex.isIncludedWith` decides whether a device is shown a Buy button on
 * the icon pack that came free with the distro it is running. Getting it wrong
 * in one direction charges people for something they already have; in the other
 * it gives away thirteen paid products.
 *
 * It cannot be compiled here, so the rule is ported line for line and run
 * against all fourteen distros plus the cases that would be embarrassing. This
 * is a PORT, not the implementation: if the two drift, the Kotlin is the truth.
 */
// Line-for-line port of CdnIndex.isIncludedWith. If this is wrong the Kotlin is
// wrong in the same way. Kotlin cannot be compiled without an Android SDK.
const isIncludedWith = (packId, activeThemeId) => {
  if (!activeThemeId) return false;
  const base = activeThemeId.replace(/-theme$/, '');
  if (!base) return false;
  if (packId === base) return false;
  return packId.startsWith(`${base}-`);
};
let p=0,f=0; const ok=(n,c)=>c?p++:(f++,console.log('  FAIL',n));

// the fourteen, running their own distro
const pairs = [
  ['kde-plasma-6','kde-plasma-6-icons'],['terminal','terminal-icons'],
  ['ubuntu-24-04','ubuntu-24-04-icons'],['arch-linux-theme','arch-linux-icons'],
  ['deepin-23-theme','deepin-23-icons'],['elementary-os-8-theme','elementary-os-8-icons'],
  ['endeavouros-theme','endeavouros-icons'],['fedora-40-theme','fedora-40-icons'],
  ['garuda-dr460nized-theme','garuda-dr460nized-icons'],['kali-2024-theme','kali-2024-icons'],
  ['linux-mint-22-theme','linux-mint-22-icons'],['manjaro-kde-theme','manjaro-kde-icons'],
  ['pop-os-2204-theme','pop-os-2204-icons'],['zorin-os-17-theme','zorin-os-17-icons'],
];
ok('all fourteen include their own icons', pairs.every(([t,i])=>isIncludedWith(i,t)));
ok('the three bundled ones work too',
   isIncludedWith('terminal-icons','terminal') &&
   isIncludedWith('ubuntu-24-04-icons','ubuntu-24-04') &&
   isIncludedWith('kde-plasma-6-icons','kde-plasma-6'));

// cross-distro must NOT be free
let cross = 0;
for (const [t] of pairs) for (const [,i] of pairs) if (!i.startsWith(t.replace(/-theme$/,'')+'-') && isIncludedWith(i,t)) cross++;
ok('no cross-distro pack is included', cross===0);
ok('ubuntu icons are not free on kali', !isIncludedWith('ubuntu-24-04-icons','kali-2024-theme'));

// edges
ok('no active theme includes nothing', !isIncludedWith('kali-2024-icons', null));
ok('empty theme includes nothing', !isIncludedWith('kali-2024-icons', ''));
ok('a theme does not include itself', !isIncludedWith('kali-2024','kali-2024-theme'));
ok('the base geometry is never included', !isIncludedWith('arcticons-line','kali-2024-theme'));
ok('a third-party pack on a shelf IS included', isIncludedWith('kali-2024-mine','kali-2024-theme'));
// the near-miss: terminal is short and a prefix of nothing here, but check anyway
ok('terminal does not include another distro', !isIncludedWith('terminalx-icons','terminal'));
console.log(`\n  ${p} passed, ${f} failed`);
process.exit(f?1:0);
