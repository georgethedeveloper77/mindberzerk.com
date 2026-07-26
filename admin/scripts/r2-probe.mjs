/**
 * WHY R2 SAYS Unauthorized.
 *
 * `Unauthorized` is the least informative thing R2 returns. It is the same word
 * for a wrong secret, a revoked token, a token minted in a different Cloudflare
 * account, and a bucket in a jurisdiction whose endpoint you are not using. The
 * panel cannot tell them apart, and neither can a single failing list call.
 *
 * Three probes DO tell them apart, because they fail at different layers:
 *
 *   ListBuckets    account-level. Passes when the credential itself is valid
 *                  and the endpoint points at the right account.
 *   HeadBucket     this bucket. Passes when the token is permitted on it.
 *   ListObjectsV2  this bucket's contents, which is what the panel actually does.
 *
 * Read the COMBINATION, not the first failure, because one of these fails
 * harmlessly by design:
 *
 *   all three fail         → the credential or the ENDPOINT is wrong. Almost
 *                            always the account ID in R2_ENDPOINT belongs to a
 *                            different Cloudflare account than the token, or
 *                            the token was rolled and .env.local kept the old
 *                            secret. A bucket with a jurisdiction (EU, FedRAMP)
 *                            also lands here: its endpoint carries the
 *                            jurisdiction, e.g. <account>.eu.r2.cloudflarestorage.com,
 *                            and the plain host rejects everything.
 *   ListBuckets fails but
 *   HeadBucket passes      → NORMAL, not a fault. ListBuckets is account-level
 *                            and a token scoped to specific buckets is not
 *                            allowed to enumerate the account. Ignore it.
 *   ListBuckets passes,
 *   HeadBucket fails       → the credential is fine and the bucket is the
 *                            problem: either R2_BUCKET names a bucket that does
 *                            not exist (404 rather than 401), or the token was
 *                            scoped to other buckets and not this one (401).
 *   HeadBucket passes,
 *   ListObjectsV2 fails    → permissions. An object-read token can list; a token
 *                            scoped to a PREFIX cannot list the bucket root.
 *
 * Run from admin/:
 *   node --env-file=.env.local scripts/r2-probe.mjs
 *
 * Reads only. It cannot change anything, so it is safe to run against the live
 * bucket. It prints no secrets, only their lengths, so its output can be pasted
 * anywhere.
 */

import {
  HeadBucketCommand,
  ListBucketsCommand,
  ListObjectsV2Command,
  S3Client,
} from '@aws-sdk/client-s3';

const endpoint = process.env.R2_ENDPOINT;
const bucket = process.env.R2_BUCKET ?? 'mindberzerk-cdn';
const accessKeyId = process.env.R2_ACCESS_KEY_ID;
const secretAccessKey = process.env.R2_SECRET_ACCESS_KEY;

console.log('endpoint  ', endpoint ?? '(unset — the SDK will talk to AWS, not R2)');
console.log('bucket    ', bucket);
console.log('key id    ', accessKeyId ? `${accessKeyId.length} chars` : '(unset)', '(R2 uses 32)');
console.log('secret    ', secretAccessKey ? `${secretAccessKey.length} chars` : '(unset)', '(R2 uses 64)');

// The account ID is the first label of the endpoint host. Printed so it can be
// compared against the account the token was created in, which is the single
// most common cause of a valid-looking credential being refused.
if (endpoint) {
  try {
    console.log('account   ', new URL(endpoint).hostname.split('.')[0]);
  } catch {
    console.log('account    (R2_ENDPOINT is not a URL)');
  }
}
console.log('');

if (!accessKeyId || !secretAccessKey) {
  console.log('Credentials are missing. Nothing to probe.');
  process.exit(1);
}

const s3 = new S3Client({
  region: 'auto',
  endpoint,
  credentials: { accessKeyId, secretAccessKey },
});

async function probe(label, command) {
  try {
    const res = await s3.send(command);
    return { label, ok: true, res };
  } catch (e) {
    return {
      label,
      ok: false,
      name: e?.name ?? 'Error',
      status: e?.$metadata?.httpStatusCode ?? '?',
      message: e?.message ?? '',
    };
  }
}

const buckets = await probe('ListBuckets', new ListBucketsCommand({}));
if (buckets.ok) {
  const names = (buckets.res.Buckets ?? []).map((b) => b.Name);
  console.log(`ListBuckets    OK   ${names.length ? names.join(', ') : '(no buckets)'}`);
  if (names.length && !names.includes(bucket)) {
    console.log(`               ↳ R2_BUCKET is '${bucket}', which is not in that list.`);
  }
} else {
  // Deliberately NOT called a failure yet. A bucket-scoped token is refused
  // here by design, and saying "the credential is wrong" at this point sends
  // you to re-mint a token that was never the problem.
  console.log(`ListBuckets    ${buckets.status} ${buckets.name} (expected for a bucket-scoped token)`);
}

const head = await probe('HeadBucket', new HeadBucketCommand({ Bucket: bucket }));
console.log(
  head.ok ? 'HeadBucket     OK' : `HeadBucket     FAIL ${head.status} ${head.name}`,
);
if (!head.ok) {
  if (head.status === 404) {
    console.log(`               ↳ No bucket named '${bucket}' in this account.`);
  } else if (buckets.ok) {
    console.log('               ↳ The token is valid but not permitted on this bucket.');
  } else {
    // Both account-level and bucket-level refused: nothing about this
    // credential reaches this account, which points at the endpoint or the
    // secret rather than at any permission setting.
    console.log('               ↳ Nothing about this credential reaches this account.');
    console.log('               ↳ Compare the account label above with the token\'s account, and');
    console.log('                 check the bucket page in Cloudflare for its exact S3 endpoint,');
    console.log('                 jurisdiction included. Then confirm the token is still live.');
  }
}

const list = await probe('ListObjectsV2', new ListObjectsV2Command({ Bucket: bucket, MaxKeys: 5 }));
if (list.ok) {
  const keys = (list.res.Contents ?? []).map((o) => o.Key);
  console.log(`ListObjectsV2  OK   ${keys.length ? keys.join(', ') : '(bucket is empty)'}`);
} else {
  console.log(`ListObjectsV2  FAIL ${list.status} ${list.name}`);
  if (head.ok) {
    console.log('               ↳ Reachable but not listable. A prefix-scoped token does this.');
  }
}
