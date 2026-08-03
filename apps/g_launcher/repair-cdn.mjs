#!/usr/bin/env node
// repair-cdn.mjs
// Fixes the three things the panel-key mismatch left behind, LOCALLY, then
// prints the exact wrangler commands to upload. Nothing touches the bucket
// until you run those commands yourself.
//
//   1. index.json    keeps ONLY ubuntu-24-04-icons (the stray theme pack is
//                    dropped), adds entitlements: [], bumps generatedAt
//   2. index.sig     signed with ~/.mindberzerk/pack-signing.key and VERIFIED
//                    against the APK pubkey before anything is written
//   3. theme-drafts.json  deletes the stray 'ubuntu-24-04-theme' draft and
//                    restores bundled: true on 'ubuntu-24-04'
//
// Run:  node repair-cdn.mjs
// Then: the printed wrangler commands (bucket name is in tools/publish-index.sh)

import { createPrivateKey, createPublicKey, sign as edSign, verify as edVerify } from 'node:crypto';
import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { homedir } from 'node:os';
import { join } from 'node:path';

const BASE = 'https://cdn.mindberzerk.com/g-launcher';
const KEY_PATH = join(homedir(), '.mindberzerk', 'pack-signing.key');
const ACCEPTED_HEX =
  'a5482077e685b0078706166a55836e094fd63143c926f097e7f340fe9781bea0';
const OUT = 'cdn-repair';

const die = (msg) => {
  console.error(`STOP: ${msg}`);
  process.exit(1);
};

const get = async (path) => {
  const res = await fetch(`${BASE}/${path}`, { cache: 'no-store' });
  if (!res.ok) return null;
  return Buffer.from(await res.arrayBuffer());
};

// ── the signing key, proven to be the one the APK trusts ────────────────────
const raw = readFileSync(KEY_PATH);
// The toolchain stores this key as HEX, which is also exactly what the panel's
// PACK_SIGNING_KEY env expects. Accept every shape it could reasonably be:
//   64 hex chars   the raw 32-byte ed25519 seed
//   128 hex chars  seed + public key concatenated; the seed is the first half
//   other hex      PKCS8 DER, hex-encoded
// with PEM and binary DER as fallbacks.
const PKCS8_PREFIX = Buffer.from('302e020100300506032b657004220420', 'hex');
let priv = null;
const txt = raw.toString('utf8').trim();
if (/^[0-9a-fA-F]+$/.test(txt) && txt.length % 2 === 0) {
  const bytes = Buffer.from(txt, 'hex');
  try {
    if (bytes.length === 32) {
      priv = createPrivateKey({ key: Buffer.concat([PKCS8_PREFIX, bytes]), format: 'der', type: 'pkcs8' });
    } else if (bytes.length === 64) {
      priv = createPrivateKey({ key: Buffer.concat([PKCS8_PREFIX, bytes.subarray(0, 32)]), format: 'der', type: 'pkcs8' });
    } else {
      priv = createPrivateKey({ key: bytes, format: 'der', type: 'pkcs8' });
    }
  } catch (e) {
    die(`The key file is hex but none of the known shapes parsed: ${e.message}`);
  }
} else {
  try {
    priv = createPrivateKey(raw);
  } catch {
    try {
      priv = createPrivateKey({ key: raw, format: 'der', type: 'pkcs8' });
    } catch (e) {
      die(`Could not read ${KEY_PATH} as hex, PEM, or DER PKCS8: ${e.message}`);
    }
  }
}
const spki = Buffer.concat([
  Buffer.from('302a300506032b6570032100', 'hex'),
  Buffer.from(ACCEPTED_HEX, 'hex'),
]);
const pub = createPublicKey({ key: spki, format: 'der', type: 'spki' });
{
  const probe = Buffer.from('probe');
  if (!edVerify(null, probe, pub, edSign(null, probe, priv))) {
    die('The key at ~/.mindberzerk/pack-signing.key does NOT match the APK pubkey. Refusing to sign anything with it.');
  }
  console.log('PASS  local key matches the APK pubkey');
}

mkdirSync(OUT, { recursive: true });

// ── index.json: drop the stray theme, keep the icon pack ────────────────────
const indexBytes = await get('index.json');
if (!indexBytes) die('Could not download index.json');
const index = JSON.parse(indexBytes.toString('utf8'));

const keep = (index.packs ?? []).filter((p) => p.packId !== 'ubuntu-24-04-theme');
if (keep.length === (index.packs ?? []).length) {
  console.log('NOTE  ubuntu-24-04-theme was not in the index; nothing to drop');
}
if (keep.length === 0) die('Dropping the stray would empty the index; refusing.');

const fixed = {
  formatVersion: index.formatVersion ?? 1,
  generatedAt: Math.max(Math.floor(Date.now() / 1000), (index.generatedAt ?? 0) + 1),
  keyId: 'mh-2026-07',
  packs: keep,
  // ABSENT in the panel-written index. Every index publish-index.sh ever wrote
  // carried this field, so absence is an untested shape on-device. Empty and
  // present is the known-good shape.
  entitlements: Array.isArray(index.entitlements) ? index.entitlements : [],
};
const body = Buffer.from(JSON.stringify(fixed, null, 2) + '\n', 'utf8');
const sig = edSign(null, body, priv);
if (!edVerify(null, body, pub, sig)) die('Self-verification of the new signature failed.');

writeFileSync(join(OUT, 'index.json'), body);
writeFileSync(join(OUT, 'index.sig'), sig);
console.log(`PASS  new index signed and self-verified (${keep.length} pack(s), generatedAt ${fixed.generatedAt})`);

// ── theme-drafts.json: remove the stray draft, mend the bundled flag ────────
const draftsBytes = await get('admin/theme-drafts.json');
if (!draftsBytes) {
  console.log('WARN  admin/theme-drafts.json could not be read; skipping the draft repair rather than writing from a failed read.');
} else {
  const doc = JSON.parse(draftsBytes.toString('utf8'));
  const drafts = doc.drafts ?? doc;
  if (drafts['ubuntu-24-04-theme']) {
    delete drafts['ubuntu-24-04-theme'];
    console.log('PASS  stray draft ubuntu-24-04-theme removed');
  } else {
    console.log('NOTE  no stray draft ubuntu-24-04-theme found');
  }
  if (drafts['ubuntu-24-04']) {
    drafts['ubuntu-24-04'].bundled = true;
    console.log('PASS  ubuntu-24-04 draft restored to bundled: true');
  } else {
    console.log('WARN  no ubuntu-24-04 draft found to mend');
  }
  const outDoc = doc.drafts ? { ...doc, drafts } : drafts;
  writeFileSync(join(OUT, 'theme-drafts.json'), JSON.stringify(outDoc, null, 2) + '\n');
}

console.log(`
Wrote ${OUT}/. Upload with (bucket name is in tools/publish-index.sh):

  BUCKET=<your-bucket>
  npx wrangler@latest r2 object put "$BUCKET/g-launcher/index.json" --file ${OUT}/index.json --content-type application/json --remote
  npx wrangler@latest r2 object put "$BUCKET/g-launcher/index.sig" --file ${OUT}/index.sig --content-type application/octet-stream --remote
  npx wrangler@latest r2 object put "$BUCKET/g-launcher/admin/theme-drafts.json" --file ${OUT}/theme-drafts.json --content-type application/json --remote

Then re-run verify-index.mjs: every check should pass. Open the Icons screen
on the phone after a refresh and ubuntu-24-04-icons should be on the Ubuntu shelf.
`);
