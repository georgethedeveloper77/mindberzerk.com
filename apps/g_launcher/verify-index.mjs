#!/usr/bin/env node
// verify-index.mjs
// Answers one question: would a device accept the live index?
// Run: node verify-index.mjs

import { createPublicKey, verify as edVerify } from 'node:crypto';

const BASE = 'https://cdn.mindberzerk.com/g-launcher';
// The pubkey baked into the APK (PackKeys.ACCEPTED_HEX, key mh-2026-07).
const ACCEPTED_HEX =
  'a5482077e685b0078706166a55836e094fd63143c926f097e7f340fe9781bea0';

let failures = 0;
const check = (ok, label, detail = '') => {
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${label}${detail ? `  (${detail})` : ''}`);
  if (!ok) failures++;
};

const get = async (path) => {
  const res = await fetch(`${BASE}/${path}`, { cache: 'no-store' });
  if (!res.ok) return null;
  return Buffer.from(await res.arrayBuffer());
};

const body = await get('index.json');
check(!!body, 'index.json downloads');
const sig = await get('index.sig');
check(!!sig, 'index.sig downloads');
if (!body || !sig) process.exit(1);

let index;
try {
  index = JSON.parse(body.toString('utf8'));
  check(true, 'index.json parses');
} catch (e) {
  check(false, 'index.json parses', e.message);
  process.exit(1);
}

check(index.keyId === 'mh-2026-07', 'keyId is mh-2026-07', String(index.keyId));
check(Array.isArray(index.packs) && index.packs.length > 0, 'packs present', `${index.packs?.length ?? 0}`);
check('entitlements' in index, 'entitlements field present', 'entitlements' in index ? 'yes' : 'ABSENT, native parser may refuse');

// ── the one that decides everything ─────────────────────────────────────────
const spki = Buffer.concat([
  Buffer.from('302a300506032b6570032100', 'hex'),
  Buffer.from(ACCEPTED_HEX, 'hex'),
]);
const key = createPublicKey({ key: spki, format: 'der', type: 'spki' });
const sigOk = edVerify(null, body, key, sig);
check(sigOk, 'index.sig verifies against the APK pubkey',
  sigOk ? 'the panel signs with the SAME key as publish-index.sh'
        : 'PANEL KEY MISMATCH: App Hosting is signing with a different private key');

// Every listed pack must be reachable AND carry a signature the APK trusts.
// Reachability alone let a wrong-key pack pass this script while every device
// refused it with 'failed verification and was discarded'.
for (const p of index.packs ?? []) {
  const m = await get(`${p.path}/manifest.json`);
  check(!!m, `${p.packId} manifest reachable`, p.path);
  const s = await get(`${p.path}/manifest.sig`);
  check(!!s, `${p.packId} manifest.sig reachable`);
  if (m && s) {
    const ok = edVerify(null, m, key, s);
    check(ok, `${p.packId} manifest.sig verifies against the APK pubkey`,
      ok ? `v${p.version}` : 'republish this pack; devices are discarding it');
  }
}

console.log(failures === 0 ? '\nAll checks passed. The fault is on-device: pull logcat.'
                           : `\n${failures} check(s) failed. Fix above before touching the device.`);
process.exit(failures === 0 ? 0 : 1);
