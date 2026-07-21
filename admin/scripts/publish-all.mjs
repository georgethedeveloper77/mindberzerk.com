#!/usr/bin/env node
/**
 * Publish EVERYTHING in backend/content to R2, in one command.
 *
 *   cd admin
 *   node --env-file=.env.local scripts/publish-all.mjs
 *   node --env-file=.env.local scripts/publish-all.mjs --dry-run
 *   node --env-file=.env.local scripts/publish-all.mjs --app g-launcher
 *
 * ## Why this exists alongside the panel's form
 *
 * The form is for publishing ONE pack you just edited. This is for seeding, for
 * re-signing everything after a key rotation, and for the case where the bucket
 * and the repo have drifted and you want the repo to win. Those are batch
 * operations and a form is the wrong shape for them.
 *
 * It runs LOCALLY on purpose. The panel is deployed and cannot see your
 * backend/content directory; this can. Same signing code, same upload ordering,
 * same index rules.
 *
 * ## It reuses tools/sign-pack.mjs rather than reimplementing
 *
 * There are already three implementations of the manifest format (that file,
 * admin/src/lib/sign.ts, and PackVerifierTest.kt). The signature covers exact
 * bytes, so a fourth would be a fourth chance to drift and produce packs that
 * look perfect in an editor and fail with BadSignature on every device.
 *
 * ## Per-pack metadata
 *
 * Each pack directory carries a `pack.meta.json` that is NOT part of the pack —
 * it is stripped before signing. It holds the things the manifest and the index
 * need but the content itself does not express:
 *
 *   { "packType": "brand", "version": 2, "minAppVersion": 6,
 *     "title": "Simple Icons", "summary": "…", "sku": null }
 *
 * A pack without one is SKIPPED with a warning rather than published with
 * guessed values. Guessing a version is how you publish v1 over a live v3.
 */

import { readFileSync, readdirSync, statSync, existsSync } from 'node:fs';
import { join, dirname, relative, sep } from 'node:path';
import { fileURLToPath } from 'node:url';
import {
  PutObjectCommand,
  GetObjectCommand,
  ListObjectsV2Command,
  DeleteObjectCommand,
  S3Client,
} from '@aws-sdk/client-s3';

import {
  MANIFEST_NAME,
  SIGNATURE_NAME,
  buildManifest,
  isSafePackId,
  isSafeRelativePath,
  rawToPrivateKey,
  readKeyArg,
  sha256,
} from '../../tools/sign-pack.mjs';
import { sign as nodeSign } from 'node:crypto';

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..', '..');
const META = 'pack.meta.json';

const args = process.argv.slice(2);
const DRY = args.includes('--dry-run');
const APP = args[args.indexOf('--app') + 1] || 'g-launcher';

const KEY_ID = process.env.PACK_KEY_ID || 'mh-2026-07';
const BUCKET = process.env.R2_BUCKET || 'mindberzerk-cdn';

// Which content directory maps to which pack type. Must match the launcher and
// admin/src/lib/sign.ts dirFor(); a mismatch produces 404s on device that read
// as a network problem rather than a layout problem.
const DIRS = {
  themes: 'theme',
  brandpacks: 'brand',
  heropacks: 'hero',
  iconpacks: 'icon',
};

// ── R2 ───────────────────────────────────────────────────────────────────────

const s3 = new S3Client({
  region: 'auto',
  endpoint: process.env.R2_ENDPOINT,
  credentials: {
    accessKeyId: process.env.R2_ACCESS_KEY_ID ?? '',
    secretAccessKey: process.env.R2_SECRET_ACCESS_KEY ?? '',
  },
});

async function put(key, body, contentType) {
  if (DRY) return console.log(`    [dry] PUT ${key} (${body.length} B)`);
  await s3.send(
    new PutObjectCommand({
      Bucket: BUCKET,
      Key: key,
      Body: body,
      ContentType: contentType,
      CacheControl: key.endsWith('.json') && key.includes('index')
        ? 'no-cache'
        : 'public, max-age=31536000, immutable',
    }),
  );
  console.log(`    PUT ${key} (${body.length} B)`);
}

async function get(key) {
  try {
    const res = await s3.send(new GetObjectCommand({ Bucket: BUCKET, Key: key }));
    const chunks = [];
    for await (const c of res.Body) chunks.push(c);
    return Buffer.concat(chunks);
  } catch (e) {
    if (e?.name === 'NoSuchKey' || e?.name === 'NotFound') return null;
    throw e;
  }
}

async function listPrefix(prefix) {
  const out = [];
  let token;
  do {
    const res = await s3.send(
      new ListObjectsV2Command({ Bucket: BUCKET, Prefix: prefix, ContinuationToken: token }),
    );
    for (const o of res.Contents ?? []) out.push(o.Key);
    token = res.NextContinuationToken;
  } while (token);
  return out;
}

// ── walking ──────────────────────────────────────────────────────────────────

function walkFiles(root, dir = root, out = []) {
  for (const name of readdirSync(dir).sort()) {
    const full = join(dir, name);
    if (statSync(full).isDirectory()) walkFiles(root, full, out);
    else out.push(relative(root, full).split(sep).join('/'));
  }
  return out;
}

function contentTypeFor(p) {
  if (p.endsWith('.json')) return 'application/json';
  if (p.endsWith('.webp')) return 'image/webp';
  if (p.endsWith('.png')) return 'image/png';
  if (p.endsWith('.svg')) return 'image/svg+xml';
  if (p.endsWith('.ttf')) return 'font/ttf';
  return 'application/octet-stream';
}

// ── main ─────────────────────────────────────────────────────────────────────

async function main() {
  const privHex = readKeyArg(
    process.env.PACK_SIGNING_KEY ? process.env.PACK_SIGNING_KEY : '@' + join(process.env.HOME, '.mindberzerk/pack-signing.key'),
  );
  const privKey = rawToPrivateKey(Buffer.from(privHex, 'hex'));
  const signBytes = (msg) => nodeSign(null, msg, privKey);

  const contentRoot = join(ROOT, 'backend', 'content', APP);
  if (!existsSync(contentRoot)) {
    console.error(`No such directory: ${contentRoot}`);
    process.exit(1);
  }

  console.log(`app     ${APP}`);
  console.log(`bucket  ${BUCKET}`);
  console.log(`key     ${KEY_ID}`);
  if (DRY) console.log('MODE    dry run, nothing will be written\n');
  else console.log('');

  // ── read the LIVE index first, always ──────────────────────────────────────
  // Never build the next index from the repo alone. generatedAt has to increase
  // from what is actually deployed, and a publish is additive: anything put
  // there by the panel or by a second machine must survive.
  const liveBytes = await get(`${APP}/index.json`);
  let live = { generatedAt: 0, packs: [], entitlements: [] };
  if (liveBytes) {
    try {
      live = JSON.parse(liveBytes.toString('utf8'));
    } catch {
      console.error(`${APP}/index.json exists but does not parse. Refusing to overwrite it.`);
      process.exit(1);
    }
  }

  const packsById = new Map((live.packs ?? []).map((p) => [p.packId, p]));
  let published = 0;
  let skipped = 0;

  for (const [dirName, packType] of Object.entries(DIRS)) {
    const typeRoot = join(contentRoot, dirName);
    if (!existsSync(typeRoot)) continue;

    for (const packId of readdirSync(typeRoot).sort()) {
      const packDir = join(typeRoot, packId);
      if (!statSync(packDir).isDirectory()) continue;

      if (!isSafePackId(packId)) {
        console.warn(`!! ${packId}: unsafe pack id, skipped`);
        skipped++;
        continue;
      }

      const metaPath = join(packDir, META);
      if (!existsSync(metaPath)) {
        // Skipped, not guessed. Inventing a version is how you publish v1 over
        // a live v3 and quietly stop every device from ever updating again.
        console.warn(`!! ${packId}: no ${META}, skipped`);
        skipped++;
        continue;
      }
      const meta = JSON.parse(readFileSync(metaPath, 'utf8'));

      // Everything except the metadata and any previously generated signature
      // artefacts. Those are OUTPUT; letting a stale one ride along is how a
      // pack ends up describing itself wrongly.
      const paths = walkFiles(packDir).filter(
        (p) => p !== META && p !== MANIFEST_NAME && p !== SIGNATURE_NAME,
      );

      if (paths.length === 0) {
        console.warn(`!! ${packId}: no payload files, skipped`);
        skipped++;
        continue;
      }

      const bad = paths.find((p) => !isSafeRelativePath(p));
      if (bad) {
        console.warn(`!! ${packId}: unsafe path '${bad}', skipped`);
        skipped++;
        continue;
      }

      const version = Number(meta.version);
      const existing = packsById.get(packId);
      if (existing && version <= existing.version) {
        // The rollback floor, enforced before anything is written. A device
        // refuses a pack that does not increase its version, SILENTLY, so
        // publishing this would upload bytes nobody ever receives.
        console.warn(
          `-- ${packId}: v${version} is not newer than the published v${existing.version}, skipped`,
        );
        skipped++;
        continue;
      }

      const files = paths.map((p) => ({ path: p, bytes: readFileSync(join(packDir, p)) }));
      const total = files.reduce((n, f) => n + f.bytes.length, 0);

      const manifest = buildManifest({
        packType,
        packId,
        version,
        minAppVersion: Number(meta.minAppVersion ?? 0),
        keyId: KEY_ID,
        files: files.map((f) => ({ path: f.path, size: f.bytes.length, sha256: sha256(f.bytes) })),
      });
      const signature = signBytes(manifest);

      // VERSION IN THE PATH, so every object under it is genuinely immutable
      // and cacheable for a year. See admin/src/lib/r2.ts for the failure this
      // avoids. Old versions are left behind on purpose.
      const packPath = `${dirName}/${packId}/${version}`;
      const remoteDir = `${APP}/${packPath}`;
      console.log(`>> ${packId} v${version} (${packType}, ${files.length} files, ${(total / 1024).toFixed(1)} KB)`);

      // PAYLOAD, THEN MANIFEST, THEN SIGNATURE. No transaction here, so the
      // order is chosen so every intermediate state is one the device handles:
      // payload alone is invisible, payload+manifest fails MissingSignature
      // cleanly, all three installs. Reversed, the middle state is a signature
      // that does not match the manifest beside it, which reads as tampering.
      for (const f of files) {
        await put(`${remoteDir}/${f.path}`, f.bytes, contentTypeFor(f.path));
      }
      await put(`${remoteDir}/${MANIFEST_NAME}`, manifest, 'application/json');
      await put(`${remoteDir}/${SIGNATURE_NAME}`, signature, 'application/octet-stream');

      // Sweep anything in THIS version's directory that is not in this build.
      // Normally nothing, since the directory is new; it matters when a publish
      // is re-run after a partial failure. Earlier versions are untouched.
      //
      // A leftover file would fail the device's unlisted-files check and refuse
      // the WHOLE pack, and that failure looks like a signature problem rather
      // than a stray wallpaper.
      if (!DRY) {
        const keep = new Set([
          ...files.map((f) => `${remoteDir}/${f.path}`),
          `${remoteDir}/${MANIFEST_NAME}`,
          `${remoteDir}/${SIGNATURE_NAME}`,
        ]);
        for (const key of await listPrefix(`${remoteDir}/`)) {
          if (!keep.has(key)) {
            await s3.send(new DeleteObjectCommand({ Bucket: BUCKET, Key: key }));
            console.log(`    DEL ${key} (not in this version)`);
          }
        }
      }

      packsById.set(packId, {
        packId,
        packType,
        path: packPath,
        version,
        minAppVersion: Number(meta.minAppVersion ?? 0),
        sizeBytes: total,
        title: meta.title ?? packId,
        summary: meta.summary ?? '',
        ...(meta.sku ? { sku: meta.sku } : {}),
      });
      published++;
    }
  }

  if (published === 0) {
    console.log(`\nNothing to publish. ${skipped} skipped.`);
    return;
  }

  // ── the index, AFTER every pack is fully up ────────────────────────────────
  // Advertising a pack whose files are still uploading produces a wave of
  // failed installs across the whole base at once.
  const now = Math.floor(Date.now() / 1000);
  const generatedAt = now > (live.generatedAt ?? 0) ? now : (live.generatedAt ?? 0) + 1;

  // Entitlements come from the repo when present, otherwise from the live
  // index. Bundle membership is content and belongs in git, but a locally
  // stale copy must not silently drop bundles someone added in the panel.
  const entPath = join(contentRoot, 'entitlements.json');
  const entitlements = existsSync(entPath)
    ? JSON.parse(readFileSync(entPath, 'utf8'))
    : (live.entitlements ?? []);

  const index = Buffer.from(
    JSON.stringify(
      {
        formatVersion: 1,
        generatedAt,
        keyId: KEY_ID,
        packs: [...packsById.values()].sort((a, b) => a.packId.localeCompare(b.packId)),
        ...(entitlements.length ? { entitlements } : {}),
      },
      null,
      2,
    ) + '\n',
    'utf8',
  );

  console.log(`\n>> index: ${packsById.size} packs, ${entitlements.length} bundles, generatedAt ${live.generatedAt ?? 0} -> ${generatedAt}`);
  await put(`${APP}/index.json`, index, 'application/json');
  await put(`${APP}/index.sig`, signBytes(index), 'application/octet-stream');

  console.log(`\nDone. ${published} published, ${skipped} skipped.`);
}

main().catch((e) => {
  console.error('\nFailed: ' + e.message);
  process.exit(1);
});
