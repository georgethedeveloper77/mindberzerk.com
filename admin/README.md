# admin — the publish panel

Next.js on Firebase App Hosting, at `admin.mindberzerk.com`.

It signs packs and writes them to the R2 bucket every installed launcher reads,
and it holds the ed25519 private key those launchers verify against. Treat it as
the highest-value target in the ecosystem, because it is.

## Scaffold

From the repo root:

```bash
mv admin/README.md /tmp/admin-readme.md
npx create-next-app@latest admin --typescript --app --src-dir --tailwind \
  --eslint --import-alias "@/*" --no-turbopack
mv /tmp/admin-readme.md admin/README.md
```

Then extract this zip over `admin/` and install:

```bash
cd admin
npm i firebase firebase-admin @aws-sdk/client-s3 server-only
```

`--no-turbopack` because App Hosting builds with webpack, and finding a
local/deploy mismatch at deploy time is a bad afternoon.

Melos ignores this directory: the workspace only lists `apps/*` and `packages/*`.

## The security model, in four sentences

1. **`server-only` is load-bearing.** `lib/sign.ts` and `lib/r2.ts` both start
   with it, so the build fails if a client component ever imports them, however
   indirectly. Without it one stray import in a `'use client'` file bundles the
   key handling into the browser, silently.
2. **The middleware is not a security boundary.** It runs on the Edge runtime,
   which cannot run firebase-admin, so it only checks that a cookie exists.
   Every route that touches anything calls `requireAdmin()` itself.
3. **Auth is an allowlist, not a role.** `ADMIN_UIDS` is a Secret Manager
   secret, not a config value, because "who may sign in" here is a credential.
   An empty allowlist means nobody, not everybody.
4. **No `NEXT_PUBLIC_` on anything that matters.** That prefix inlines a value
   into the client bundle. Check it twice before adding a variable.

## Secrets

Create these in Secret Manager, then grant the App Hosting service account
access:

```bash
firebase apphosting:secrets:set pack-signing-key
firebase apphosting:secrets:set r2-access-key-id
firebase apphosting:secrets:set r2-secret-access-key
firebase apphosting:secrets:set admin-uids
```

`pack-signing-key` is the 64-hex private half from
`node tools/sign-pack.mjs keygen`, whose public half is in `PackKeys.kt`. If
they ever diverge, every pack this panel publishes is refused with `UnknownKey`.

`admin-uids` is your Firebase Auth UID. Sign in once, read it from the Auth
console, paste it in.

Fill `NEXT_PUBLIC_FIREBASE_*` in `apphosting.yaml` from the web app config.

## Local development

Copy `.env.example` to `.env.local` and fill it. Never commit the filled copy.
`FIREBASE_SERVICE_ACCOUNT` is only needed locally; in production App Hosting
supplies application-default credentials.

## Publish ordering, and why it is in the code rather than a runbook

A publish is several independent PUTs with no transaction, so `putPack` uploads
**payload first, manifest second, signature last**, and deletes stale files from
the previous version afterwards. Every intermediate state is one the device
handles correctly:

| State | Device behaviour |
|---|---|
| payload only | never looks, sees nothing |
| payload + manifest | `MissingSignature`, refuses cleanly |
| all three | installs |

Reverse the order and the middle state is a signature that does not match the
manifest beside it, which reads to a device as tampering. That is an alarm you
do not want firing because an upload timed out.

The stale-file sweep matters for the same reason: a wallpaper left behind from
version 1 that version 2 no longer lists fails the device's unlisted-files check
and refuses the whole pack, and that failure looks like a signature problem.

## Three implementations of one format

`admin/src/lib/sign.ts`, `tools/sign-pack.mjs`, and
`PackVerifierTest.buildPackInto` in Kotlin all produce manifests. The signature
covers the exact serialised bytes, so reordering a key or changing indentation
in one of them produces packs that look perfect in an editor and fail with
`BadSignature` on every device.

The CLI has no dependencies specifically so this port was a copy. Keep them
edited together.

## Not built yet

- The pack editor UI and its publish route
- The index rebuild route (read live index, bump `generatedAt`, re-sign)
- Multi-app scoping beyond `g-launcher`
