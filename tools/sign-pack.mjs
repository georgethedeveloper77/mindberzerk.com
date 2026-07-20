#!/usr/bin/env node
/**
 * PHASE C1 — sign a pack directory so G Launcher will accept it.
 *
 *   node tools/sign-pack.mjs keygen
 *   node tools/sign-pack.mjs sign <dir> --type theme --id ubuntu-24-04 \
 *        --version 2 --min-app 6 --key-id mh-2026-07 --key <hex|@file>
 *   node tools/sign-pack.mjs verify <dir> --pub <hex>
 *   node tools/sign-pack.mjs sign-index <index.json> --key <hex|@file>
 *
 * `sign-index` writes a detached `index.sig` beside the file. The index is the
 * signed catalogue at <cdn>/g-launcher/index.json. It is signed for one reason
 * only: an unsigned index cannot forge a pack (each pack carries its own
 * signature) but it CAN lie by omission, dropping or freezing an entry so a
 * device never learns an update exists. A signature plus the client's
 * generatedAt floor closes that.
 *
 * ZERO DEPENDENCIES. Node's built-in crypto has had ed25519 since 16, and this
 * script is going to be lifted almost verbatim into the Next.js admin panel in
 * C4 — a dependency here becomes a dependency there.
 *
 * THIS IS THE REFERENCE PUBLISHER. `PackVerifierTest.buildPackInto` is the
 * reference in Kotlin. They must agree byte for byte on what a manifest looks
 * like, because the signature is over the exact serialised bytes: reorder a key
 * or change the indentation on one side only and every pack fails with
 * BadSignature while looking perfect in an editor. Edit them together.
 *
 * THE PRIVATE KEY NEVER GOES IN THE REPO. Pass it as @path/to/key or via an
 * environment variable; the same secret will live server-side in App Hosting
 * when C4 automates this. If it leaks, every id in PackKeys.kt is dead and the
 * fix is a Play release.
 */

import { createHash, generateKeyPairSync, sign, verify, createPublicKey, createPrivateKey } from 'node:crypto';
import { readFileSync, writeFileSync, readdirSync, statSync, existsSync } from 'node:fs';
import { join, relative, sep } from 'node:path';

const FORMAT_VERSION = 1;
const MANIFEST_NAME = 'manifest.json';
const SIGNATURE_NAME = 'manifest.sig';
const KNOWN_TYPES = ['theme', 'brand', 'hero', 'icon'];

// ── ed25519 raw-key helpers ──────────────────────────────────────────────────
// Node speaks DER/PEM; the app speaks raw 32-byte keys. The DER prefix for an
// ed25519 key is fixed-length, so slicing it is exact rather than a heuristic.
const PUB_DER_PREFIX = Buffer.from('302a300506032b6570032100', 'hex');
const PRIV_DER_PREFIX = Buffer.from('302e020100300506032b657004220420', 'hex');

const rawToPublicKey = (raw) =>
  createPublicKey({ key: Buffer.concat([PUB_DER_PREFIX, raw]), format: 'der', type: 'spki' });

const rawToPrivateKey = (raw) =>
  createPrivateKey({ key: Buffer.concat([PRIV_DER_PREFIX, raw]), format: 'der', type: 'pkcs8' });

// ── path safety, mirroring PackManifest.isSafeRelativePath ───────────────────
function isSafeRelativePath(p) {
  if (!p || p.length > 200) return false;
  if (p.startsWith('/') || p.endsWith('/')) return false;
  if (p.includes('\\') || p.includes('\0')) return false;
  if (p.length >= 2 && p[1] === ':') return false;
  return p.split('/').every(
    (s) => s && s !== '.' && s !== '..' && !s.startsWith(' ') && !s.endsWith(' ') && /^[A-Za-z0-9._-]+$/.test(s),
  );
}

function isSafePackId(id) {
  return !!id && id.length <= 64 && !id.startsWith('.') && /^[a-z0-9._-]+$/.test(id);
}

// ── walking ──────────────────────────────────────────────────────────────────
function walk(root, dir = root, out = []) {
  for (const name of readdirSync(dir).sort()) {
    const full = join(dir, name);
    if (statSync(full).isDirectory()) walk(root, full, out);
    else out.push(relative(root, full).split(sep).join('/'));
  }
  return out;
}

const sha256 = (buf) => createHash('sha256').update(buf).digest('hex');

// ── manifest serialisation ───────────────────────────────────────────────────
// Files are sorted by path so the same directory always produces the same
// manifest. Two-space indent, keys in this order, trailing newline: matched by
// the Kotlin test fixture. Do not reach for JSON.stringify with a replacer and
// hope — write it out.
function buildManifest({ packType, packId, version, minAppVersion, keyId, files }) {
  const entries = files
    .map((f) => `    {"path": "${f.path}", "size": ${f.size}, "sha256": "${f.sha256}"}`)
    .join(',\n');

  return Buffer.from(
    `{
  "formatVersion": ${FORMAT_VERSION},
  "packType": "${packType}",
  "packId": "${packId}",
  "version": ${version},
  "minAppVersion": ${minAppVersion},
  "keyId": "${keyId}",
  "files": [
${entries}
  ]
}`,
    'utf8',
  );
}

// ── commands ─────────────────────────────────────────────────────────────────
function cmdKeygen() {
  const { publicKey, privateKey } = generateKeyPairSync('ed25519');
  const pubRaw = publicKey.export({ format: 'der', type: 'spki' }).subarray(PUB_DER_PREFIX.length);
  const privRaw = privateKey.export({ format: 'der', type: 'pkcs8' }).subarray(PRIV_DER_PREFIX.length);

  const pub = pubRaw.toString('hex');
  const priv = privRaw.toString('hex');

  // Length is printed so a truncated copy/paste is obvious immediately. Both
  // MUST read 64. Anything else means the line was cut, not that the key is
  // short - ed25519 keys are always exactly 32 bytes.
  console.log('');
  console.log(`public  (${pub.length} chars, paste into PackKeys.ACCEPTED_HEX):`);
  console.log(pub);
  console.log('');
  console.log(`private (${priv.length} chars, NEVER commit; write to a file outside the repo):`);
  console.log(priv);
  console.log('');
  console.log('Suggested:');
  console.log('  mkdir -p ~/.mindberzerk && echo ' + priv + ' > ~/.mindberzerk/pack-signing.key');
  console.log('  chmod 600 ~/.mindberzerk/pack-signing.key');
  // $HOME, not ~. The shell only expands a tilde at the START of a word, so
  // `--key @~/.mindberzerk/...` is passed through literally and fails to open.
  console.log('  # then sign with:  --key @$HOME/.mindberzerk/pack-signing.key');
}

function cmdSign(dir, opts) {
  if (!isSafePackId(opts.id)) throw new Error(`unsafe packId '${opts.id}'`);
  if (!KNOWN_TYPES.includes(opts.type)) throw new Error(`unknown packType '${opts.type}'`);

  const paths = walk(dir).filter((p) => p !== MANIFEST_NAME && p !== SIGNATURE_NAME);
  if (paths.length === 0) throw new Error('no payload files; a pack with no payload is not a pack');

  for (const p of paths) {
    if (!isSafeRelativePath(p)) throw new Error(`unsafe path '${p}' — the device will refuse this pack`);
  }

  const files = paths.map((p) => {
    const bytes = readFileSync(join(dir, p));
    return { path: p, size: bytes.length, sha256: sha256(bytes) };
  });

  const manifest = buildManifest({
    packType: opts.type,
    packId: opts.id,
    version: Number(opts.version),
    minAppVersion: Number(opts.minApp ?? 0),
    keyId: opts.keyId,
    files,
  });

  const privRaw = Buffer.from(readKeyArg(opts.key), 'hex');
  if (privRaw.length !== 32) throw new Error('private key must be 32 raw bytes as hex');

  const signature = sign(null, manifest, rawToPrivateKey(privRaw));

  writeFileSync(join(dir, MANIFEST_NAME), manifest);
  writeFileSync(join(dir, SIGNATURE_NAME), signature);

  console.log(`signed ${files.length} file(s) as ${opts.id} v${opts.version} with key '${opts.keyId}'`);
  for (const f of files) console.log(`  ${f.path}  ${f.size}B  ${f.sha256.slice(0, 12)}…`);
}

function cmdSignIndex(file, opts) {
  const body = readFileSync(file);
  const parsed = JSON.parse(body.toString('utf8'));

  // Fail here rather than on ten thousand devices. Every one of these is a
  // field CdnIndex.parseTrusted refuses, and the symptom on-device is an index
  // that silently never updates.
  if (parsed.formatVersion !== FORMAT_VERSION) throw new Error('formatVersion must be ' + FORMAT_VERSION);
  if (!Number.isInteger(parsed.generatedAt) || parsed.generatedAt <= 0) throw new Error('generatedAt must be a positive unix-seconds integer');
  if (!parsed.keyId) throw new Error('missing keyId');
  if (!Array.isArray(parsed.packs) || parsed.packs.length === 0) throw new Error('packs must be a non-empty array');

  // PHASE C3 — bundles. Optional, but validated when present, because a
  // malformed sku silently never matches anything Play reports as owned, which
  // on-device looks exactly like the user not having bought it.
  const skuOk = (s) => typeof s === 'string' && /^[a-z0-9][a-z0-9_]{0,63}$/.test(s);
  if (parsed.entitlements !== undefined) {
    if (!Array.isArray(parsed.entitlements)) throw new Error('entitlements must be an array');
    const seenSkus = new Set();
    for (const e of parsed.entitlements) {
      if (!skuOk(e.sku)) throw new Error(`unsafe sku '${e.sku}' (Play IDs are lowercase a-z 0-9 _, starting alphanumeric)`);
      if (seenSkus.has(e.sku)) throw new Error(`duplicate sku '${e.sku}'`);
      seenSkus.add(e.sku);
      if (!Array.isArray(e.grants) || e.grants.length === 0) throw new Error(`empty grants for '${e.sku}'`);
      for (const g of e.grants) {
        // '*' is legal and means every pack forever. A named grant need NOT
        // exist yet: a bundle may be announced before its packs ship.
        if (g !== '*' && !isSafePackId(g)) throw new Error(`unsafe grant '${g}' for '${e.sku}'`);
      }
    }
  }

  const seen = new Set();
  for (const p of parsed.packs) {
    if (!isSafePackId(p.packId)) throw new Error(`unsafe packId '${p.packId}'`);
    if (seen.has(p.packId)) throw new Error(`duplicate packId '${p.packId}'`);
    seen.add(p.packId);
    if (!KNOWN_TYPES.includes(p.packType)) throw new Error(`unknown packType '${p.packType}' for ${p.packId}`);
    if (!isSafeRelativePath(p.path)) throw new Error(`unsafe path '${p.path}' for ${p.packId}`);
    if (!Number.isInteger(p.version) || p.version < 1) throw new Error(`bad version for ${p.packId}`);
    if (!Number.isInteger(p.minAppVersion) || p.minAppVersion < 0) throw new Error(`bad minAppVersion for ${p.packId}`);
    if (!Number.isInteger(p.sizeBytes) || p.sizeBytes < 0) throw new Error(`bad sizeBytes for ${p.packId}`);
    if (p.sku !== undefined && p.sku !== null && !skuOk(p.sku)) throw new Error(`unsafe sku '${p.sku}' for ${p.packId}`);
  }

  const privRaw = Buffer.from(readKeyArg(opts.key), 'hex');
  if (privRaw.length !== 32) throw new Error('private key must be 32 raw bytes as hex');

  // Signed over the file's EXACT bytes, never a re-serialisation. Reformatting
  // this file after signing invalidates the signature with no visible change.
  writeFileSync(file.replace(/\.json$/, '.sig'), sign(null, body, rawToPrivateKey(privRaw)));
  const bundles = (parsed.entitlements || []).length;
  console.log(`signed index: ${parsed.packs.length} pack(s), ${bundles} bundle(s), generatedAt ${parsed.generatedAt}, key '${parsed.keyId}'`);
}

function cmdVerify(dir, opts) {
  const manifest = readFileSync(join(dir, MANIFEST_NAME));
  const signature = readFileSync(join(dir, SIGNATURE_NAME));
  const pubRaw = Buffer.from(readKeyArg(opts.pub), 'hex');

  if (!verify(null, manifest, rawToPublicKey(pubRaw), signature)) {
    console.error('SIGNATURE FAILED');
    process.exit(1);
  }

  const parsed = JSON.parse(manifest.toString('utf8'));
  for (const f of parsed.files) {
    const full = join(dir, f.path);
    if (!existsSync(full)) {
      console.error(`MISSING ${f.path}`);
      process.exit(1);
    }
    const bytes = readFileSync(full);
    if (bytes.length !== f.size || sha256(bytes) !== f.sha256) {
      console.error(`TAMPERED ${f.path}`);
      process.exit(1);
    }
  }

  const listed = new Set([...parsed.files.map((f) => f.path), MANIFEST_NAME, SIGNATURE_NAME]);
  const extras = walk(dir).filter((p) => !listed.has(p));
  if (extras.length) {
    console.error('UNLISTED FILES (the device will refuse this pack): ' + extras.join(', '));
    process.exit(1);
  }

  console.log(`ok — ${parsed.packId} v${parsed.version}, ${parsed.files.length} file(s), key '${parsed.keyId}'`);
}

/**
 * `@path` reads a file, anything else is the literal hex.
 *
 * The diagnostics below exist because every one of them has actually been hit.
 * A cryptic hex-length error three steps later is much worse than a sentence
 * saying which key you handed it.
 */
function readKeyArg(v) {
  if (!v || v === true) throw new Error('missing --key');

  if (/\.(jks|keystore|p12|pem|der)$/i.test(v)) {
    throw new Error(
      `'${v}' is not an ed25519 pack key.\n` +
      '  A .jks/.keystore is your Android UPLOAD key, which signs the APK and has\n' +
      '  nothing to do with pack signing. They are separate keys with separate jobs.\n' +
      '  Run `sign-pack.mjs keygen` and use the 64-character private hex it prints.',
    );
  }

  if (!v.startsWith('@') && (v.includes('/') || v.includes('\\'))) {
    throw new Error(`'${v}' looks like a path. To read a key FROM a file, prefix it: --key @${v}`);
  }

  const raw = (v.startsWith('@') ? readFileSync(v.slice(1), 'utf8') : v).trim();

  if (!/^[0-9a-f]{64}$/i.test(raw)) {
    throw new Error(
      `key must be exactly 64 hex characters (32 raw bytes); got ${raw.length}.\n` +
      '  If this came from keygen, you may have copied only part of the line.',
    );
  }
  return raw;
}

// ── arg parsing ──────────────────────────────────────────────────────────────
//
// FIXED: the first version filtered anything not starting with '--' into
// `positional`, which swept up FLAG VALUES too. `sign --type brand` put "brand"
// in positional[0], so the tool tried to sign a directory called `brand` and
// reported ENOENT on a path the user never typed. Consuming the value with the
// flag is the fix, and it is why `i++` is inside the branch.
const argv = process.argv.slice(2);
const command = argv[0];
const positional = [];
const opts = {};

for (let i = 1; i < argv.length; i++) {
  const a = argv[i];
  if (!a.startsWith('--')) {
    positional.push(a);
    continue;
  }
  const key = a.slice(2).replace(/-([a-z])/g, (_, c) => c.toUpperCase());
  const next = argv[i + 1];
  if (next !== undefined && !next.startsWith('--')) {
    opts[key] = next;
    i++;
  } else {
    opts[key] = true;
  }
}

function requirePositional(what) {
  if (!positional[0]) throw new Error(`missing ${what}. See usage above.`);
  return positional[0];
}

try {
  if (command === 'keygen') cmdKeygen();
  else if (command === 'sign') cmdSign(requirePositional('<dir>'), opts);
  else if (command === 'verify') cmdVerify(requirePositional('<dir>'), opts);
  else if (command === 'sign-index') cmdSignIndex(requirePositional('<index.json>'), opts);
  else {
    console.error('usage: sign-pack.mjs keygen | sign <dir> [...] | verify <dir> --pub <hex> | sign-index <index.json> --key <hex>');
    process.exit(2);
  }
} catch (e) {
  console.error('error: ' + e.message);
  process.exit(1);
}
