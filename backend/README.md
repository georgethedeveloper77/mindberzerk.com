# backend/ — the source of truth for everything on the CDN

## The rule

**This directory mirrors the bucket exactly.** `backend/content/g-launcher/` is
what ends up at `cdn.mindberzerk.com/g-launcher/`, path for path. If the two
shapes ever drift, the launcher fetches 404s and the failure looks like a
network problem rather than a layout problem, which is a bad hour.

That is why the app prefix is a real directory here and not implied. The bucket
serves five apps out of one origin, so `content/index.json` with no prefix was
ambiguous the moment G Recovery needed one of its own.

```
backend/
  content/
    g-launcher/
      index.json               <- the signed catalogue
      themes/<id>/
        theme.json
        wallpapers/*.webp
      brandpacks/<id>/pack.json
      heropacks/<id>/{pack.json,*.png}
    g-recovery/
      index.json
      oem-guides/*.json        <- per-brand recovery guidance (Infinix, Tecno…)
  schema/
    *.schema.json
  dist/                        <- BUILD OUTPUT, gitignored
```

## What is source and what is not

**Source, committed:** `theme.json`, `pack.json`, wallpapers, icon art,
`index.json` without its signature, and the PUBLIC key.

**Build output, gitignored:** `manifest.json`, `manifest.sig`, `index.sig`,
everything under `dist/`.

Signatures are derived from content plus a private key. Committing them means
the repo carries signatures that go stale the moment anyone edits the content
beside them, and a stale signature in git is worse than none: it looks
authoritative, verifies against nothing, and the next person assumes the content
is what was signed.

The private key never comes near this repo. It lives outside it during
development and becomes a server-side secret in App Hosting once C4 automates
publishing.

## Publishing, today

```bash
# one pack
node tools/sign-pack.mjs sign backend/content/g-launcher/brandpacks/simple-icons \
  --type brand --id simple-icons --version 2 --min-app 6 \
  --key-id mh-2026-07 --key @$HOME/.mindberzerk/pack-signing.key

# the catalogue (stamps generatedAt, re-signs, tells you what to upload)
./tools/publish-index.sh
```

Then upload the pack directory and the two index files to the bucket, preserving
paths.

## Publishing, after C4

The admin panel does all of the above server-side and writes straight to R2. The
format does not change; the only difference is who runs the signer. Which is
exactly why the signer is a zero-dependency Node script: it lifts into the
Next.js route almost verbatim.

## The one thing that will bite you

`generatedAt` in `index.json` MUST increase on every publish. The device refuses
an index older than the one it holds, which is what stops a stale CDN edge from
hiding an update forever. Forget to bump it and every device that already synced
ignores your new index silently: nothing errors, nothing logs, the packs just
never appear.

`publish-index.sh` stamps it for you. Use it rather than editing the field.
