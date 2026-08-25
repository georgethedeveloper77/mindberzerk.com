#!/usr/bin/env node
/**
 * THE PLATE LEGIBILITY DECISION, OUTSIDE ANDROID.
 *
 * `IconContrast.kt` and `IconRenderer.legibilityPlan` cannot be run without a
 * device, and the failure they fix is silent: nothing throws, nothing logs, and
 * the icon is drawn exactly as specified. That is the worst combination to
 * leave untested, so the decision logic is ported here line for line and run
 * against the cases that actually broke on a Galaxy S22.
 *
 * This is a PORT, not the implementation. If the two drift, this file is
 * wrong and the Kotlin is the truth. Its job is to prove the thresholds
 * discriminate: that the three observed failures are corrected and that Gmail,
 * Netflix and a white monochrome layer are left alone.
 *
 *   node tools/icons/contrast-cases.mjs
 */
const chan = v => { const c = v/255; return c <= 0.03928 ? c/12.92 : ((c+0.055)/1.055)**2.4; };
const lum = hex => { const n = parseInt(hex.slice(1),16);
  return 0.2126*chan((n>>16)&255) + 0.7152*chan((n>>8)&255) + 0.0722*(chan(n&255)); };
const ratio = (a,b) => (Math.max(a,b)+0.05)/(Math.min(a,b)+0.05);
const MIN_RATIO = 2.0;
const legibleTint = p => p < 0.35 ? '#FFFFFF' : '#000000';

function plan({plate, gradientEnd=null, inkHex, tint=null, treatment='ROUNDED_SQUARE'}) {
  if (treatment === 'ORIGINAL') return {tint, keepAppBackground:false, why:'original shape'};
  if (!plate) return {tint, keepAppBackground:false, why:'no themed plate'};
  const p = gradientEnd ? (lum(plate)+lum(gradientEnd))/2 : lum(plate);
  const ink = tint ? lum(tint) : lum(inkHex);
  const r = ratio(ink, p);
  if (r >= MIN_RATIO) return {tint, keepAppBackground:false, why:`ratio ${r.toFixed(2)} ok`};
  if (tint) return {tint: legibleTint(p), keepAppBackground:false, why:`ratio ${r.toFixed(2)}, retint`};
  return {tint:null, keepAppBackground:true, why:`ratio ${r.toFixed(2)}, keep app bg`};
}

const KALI = '#0B1220';
const cases = [
  ['Samsung My Files   dark fg, no monochrome', {plate:KALI, inkHex:'#101418'}],
  ['Samsung Music      dark fg, no monochrome', {plate:KALI, inkHex:'#1A1A1E'}],
  ['Dark monochrome + dark tint',               {plate:KALI, inkHex:'#000000', tint:'#12203A'}],
  ['Gmail              bright red/white fg',    {plate:KALI, inkHex:'#D64C3F'}],
  ['Netflix            red on black fg',        {plate:KALI, inkHex:'#B9202B'}],
  ['White monochrome + white tint',             {plate:KALI, inkHex:'#000000', tint:'#FFFFFF'}],
  ['Light plate, dark artwork',                 {plate:'#EEF1F5', inkHex:'#101418'}],
  ['Light plate, light artwork',                {plate:'#EEF1F5', inkHex:'#F2F4F7'}],
  ['Gradient plate, mid artwork',               {plate:'#0B1220', gradientEnd:'#F0F4FF', inkHex:'#8A93A5'}],
  ['No plate set (theme keeps app bg)',         {plate:null, inkHex:'#101418'}],
  ['ORIGINAL treatment',                        {plate:KALI, inkHex:'#101418', treatment:'ORIGINAL'}],
];
let untouched=0, fixed=0;
for (const [name,c] of cases) {
  const r = plan(c);
  const act = r.keepAppBackground ? 'KEEP APP BG' : (r.tint !== (c.tint ?? null) ? `RETINT ${r.tint}` : 'unchanged');
  if (act === 'unchanged') untouched++; else fixed++;
  console.log(`${name.padEnd(44)} ${act.padEnd(16)} ${r.why}`);
}
console.log(`\n${untouched} unchanged, ${fixed} corrected`);
