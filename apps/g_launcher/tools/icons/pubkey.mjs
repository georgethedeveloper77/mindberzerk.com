#!/usr/bin/env node
/**
 * The ed25519 PUBLIC key for a private key, as raw hex.
 *
 *   node tools/icons/pubkey.mjs @$HOME/.mindberzerk/pack-signing.key
 *
 * `sign-pack.mjs verify` needs a public key, and typing one from PackKeys.kt
 * defeats the purpose: it would verify that the pack matches the key you
 * BELIEVE you signed with. Deriving it from the private key that was actually
 * used means a wrong or stale key fails at step three, on this machine, rather
 * than as BadSignature on every device that downloads the pack.
 *
 * Same `@path` convention as sign-pack.mjs, and the same DER prefixes: Node
 * speaks DER, the app speaks raw 32-byte keys, and the ed25519 prefix is
 * fixed-length so slicing it is exact rather than a heuristic.
 */

import { createPublicKey, createPrivateKey } from 'node:crypto';
import { readFileSync } from 'node:fs';

const PRIV_DER_PREFIX = Buffer.from('302e020100300506032b657004220420', 'hex');
const PUB_DER_PREFIX_LEN = 12;

const arg = process.argv[2];
if (!arg) {
  process.stderr.write('usage: pubkey.mjs <hex|@file>\n');
  process.exit(2);
}

let hex;
try {
  hex = (arg.startsWith('@') ? readFileSync(arg.slice(1), 'utf8') : arg).trim();
} catch (e) {
  process.stderr.write(`pubkey: cannot read ${arg.slice(1)}: ${e.message}\n`);
  process.exit(1);
}

if (!/^[0-9a-f]{64}$/i.test(hex)) {
  process.stderr.write(
    `pubkey: key must be exactly 64 hex characters (32 raw bytes); got ${hex.length}.\n`,
  );
  process.exit(1);
}

const priv = createPrivateKey({
  key: Buffer.concat([PRIV_DER_PREFIX, Buffer.from(hex, 'hex')]),
  format: 'der',
  type: 'pkcs8',
});

process.stdout.write(
  createPublicKey(priv).export({ format: 'der', type: 'spki' })
    .subarray(PUB_DER_PREFIX_LEN).toString('hex'),
);
