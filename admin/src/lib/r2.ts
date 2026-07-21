import 'server-only';

import {
  DeleteObjectCommand,
  GetObjectCommand,
  ListObjectsV2Command,
  PutObjectCommand,
  S3Client,
} from '@aws-sdk/client-s3';

/**
 * PHASE C4 — R2, through the S3 API.
 *
 * `import 'server-only'` again, first line, for the same reason as sign.ts: the
 * credentials here can rewrite the CDN every installed launcher reads.
 *
 * ## Why S3 and not the Workers binding
 *
 * A Workers R2 binding would be tighter, but this runs on Firebase App Hosting,
 * not on Cloudflare, so the S3-compatible endpoint is the only door. It is also
 * the same door `wrangler` and every backup script uses, which means one set of
 * credentials to rotate rather than two.
 *
 * ## The publish ordering rule, enforced by putPack below
 *
 * PAYLOAD FIRST, MANIFEST SECOND, SIGNATURE LAST.
 *
 * There is no transaction here: a publish is several independent PUTs and any
 * one can fail. So the order is chosen so that every intermediate state is a
 * state the device handles correctly:
 *
 *   - payload uploaded, no manifest  → PackDownloader never looks, sees nothing
 *   - manifest uploaded, no signature → verify fails MissingSignature, refused
 *   - all three → installs
 *
 * Reverse it and the middle state is "a signature that does not match the
 * manifest beside it", which reads to a device as tampering and is exactly the
 * alarm you do not want firing because an upload timed out.
 */

let client: S3Client | null = null;

function s3(): S3Client {
  if (client) return client;

  const accessKeyId = process.env.R2_ACCESS_KEY_ID;
  const secretAccessKey = process.env.R2_SECRET_ACCESS_KEY;
  if (!accessKeyId || !secretAccessKey) {
    throw new Error(
      'R2 credentials are missing. Check the Secret Manager bindings in apphosting.yaml.',
    );
  }

  client = new S3Client({
    // R2 ignores the region but the SDK insists on one.
    region: 'auto',
    endpoint: process.env.R2_ENDPOINT,
    credentials: { accessKeyId, secretAccessKey },
  });
  return client;
}

const bucket = () => process.env.R2_BUCKET ?? 'mindberzerk-cdn';

export async function putObject(key: string, body: Buffer, contentType: string) {
  await s3().send(
    new PutObjectCommand({
      Bucket: bucket(),
      Key: key,
      Body: body,
      ContentType: contentType,
      // ── CACHING, AND WHY THE VERSIONED PATH IS LOAD-BEARING ──────────────
      //
      // The index is no-cache: it is small, it is the ONE thing that must be
      // fresh, and PackDownloader sends an ETag so a repeat fetch is a 304.
      //
      // Everything else is immutable for a year, which is only safe because a
      // pack lives at `<type>/<packId>/<version>/…`. Without the version in the
      // path this is a serious bug: `brandpacks/simple-icons/manifest.sig` is
      // the same URL for v2 and v3, so an edge would serve the OLD manifest for
      // a year after publishing. The mixed state is worse than the stale one —
      // a fresh payload file against a cached old manifest is a hash mismatch,
      // and PackVerifier correctly reports that as tampering.
      //
      // With the version in the path, every object really is immutable, cache
      // busting is free, and old versions stay reachable so a device that read
      // the index a minute ago and is mid-download still finds its files.
      CacheControl: key.endsWith('index.json') || key.endsWith('index.sig')
        ? 'no-cache'
        : 'public, max-age=31536000, immutable',
    }),
  );
}

export async function getObject(key: string): Promise<Buffer | null> {
  try {
    const res = await s3().send(new GetObjectCommand({ Bucket: bucket(), Key: key }));
    const body = res.Body as unknown as AsyncIterable<Uint8Array>;
    const chunks: Uint8Array[] = [];
    for await (const chunk of body) chunks.push(chunk);
    return Buffer.concat(chunks);
  } catch (e: unknown) {
    // Genuinely absent is the normal case on a first publish.
    const name = (e as { name?: string })?.name;
    if (name === 'NoSuchKey' || name === 'NotFound') return null;
    throw e;
  }
}

export async function listPrefix(prefix: string): Promise<string[]> {
  const out: string[] = [];
  let token: string | undefined;
  do {
    const res = await s3().send(
      new ListObjectsV2Command({
        Bucket: bucket(),
        Prefix: prefix,
        ContinuationToken: token,
      }),
    );
    for (const o of res.Contents ?? []) if (o.Key) out.push(o.Key);
    token = res.NextContinuationToken;
  } while (token);
  return out;
}

export async function deleteObject(key: string) {
  await s3().send(new DeleteObjectCommand({ Bucket: bucket(), Key: key }));
}

/**
 * Upload a signed pack in the safe order. See the ordering rule above.
 *
 * [remoteDir] is the directory under the app prefix, e.g.
 * `g-launcher/brandpacks/simple-icons`.
 */
export async function putPack(
  remoteDir: string,
  objects: { path: string; bytes: Buffer; contentType: string }[],
) {
  const manifest = objects.find((o) => o.path === 'manifest.json');
  const signature = objects.find((o) => o.path === 'manifest.sig');
  const payload = objects.filter(
    (o) => o.path !== 'manifest.json' && o.path !== 'manifest.sig',
  );

  if (!manifest || !signature) {
    throw new Error('putPack requires a manifest and its signature');
  }

  for (const o of payload) {
    await putObject(`${remoteDir}/${o.path}`, o.bytes, o.contentType);
  }
  await putObject(`${remoteDir}/manifest.json`, manifest.bytes, manifest.contentType);
  await putObject(`${remoteDir}/manifest.sig`, signature.bytes, signature.contentType);

  // Files left behind by a PREVIOUS version that this one no longer lists are
  // deleted last. They would fail the device's unlisted-files check and refuse
  // the whole pack, and that failure looks like a signature problem rather than
  // a leftover wallpaper.
  const listed = new Set([
    ...payload.map((o) => `${remoteDir}/${o.path}`),
    `${remoteDir}/manifest.json`,
    `${remoteDir}/manifest.sig`,
  ]);
  for (const key of await listPrefix(`${remoteDir}/`)) {
    if (!listed.has(key)) await deleteObject(key);
  }
}
