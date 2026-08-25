#!/bin/bash
#
# SIGN A PACK, UPLOAD IT, AND ADD IT TO THE SIGNED INDEX.
#
#   ./tools/icons/publish-pack.sh tools/icons/out/arcticons-line --version 1
#
#   --version    required, and must be higher than what is published
#   --type       pack type, default brand
#   --min-app    minimum app version, default 6
#   --key        signing key, default @$HOME/.mindberzerk/pack-signing.key
#   --key-id     default mh-2026-07
#   --sku        Play product id, omit for free
#   --requires   comma separated pack ids this one cannot work without
#   --dry-run    do everything except the two uploads
#
# Endpoints come from MB_CDN, MB_BUCKET and MB_PREFIX when set, so this can be
# pointed at a staging bucket or exercised end to end without touching
# production. The defaults are the real thing.
#
# ─── WHY THIS EXISTS RATHER THAN A LIST OF COMMANDS IN A DOC ─────────────────
#
# The sequence is sign, verify, upload the pack, then READ the live index, merge
# one entry into it, bump generatedAt, re-sign and upload that. Seven steps, and
# the fifth is the one that matters: the index is a single object holding every
# pack, so writing a fresh one instead of merging into the live one unpublishes
# everything else. Silently. Devices that already downloaded those packs keep
# them, so nobody notices for a while.
#
# A doc that says "remember to read the index first" is a doc that will be
# followed nine times out of ten.
#
# Every failure below aborts BEFORE anything is uploaded. A half-published pack
# is worse than an unpublished one: the bytes are live, the index does not name
# them, and nothing on a device or in the panel explains why.

set -euo pipefail

DIR=""
VERSION=""
TYPE="brand"
MIN_APP="6"
KEY="@$HOME/.mindberzerk/pack-signing.key"
KEY_ID="mh-2026-07"
SKU=""
REQUIRES=""
DRY=0

BUCKET="${MB_BUCKET:-mindberzerk-cdn}"
PREFIX="${MB_PREFIX:-g-launcher}"
CDN="${MB_CDN:-https://cdn.mindberzerk.com}"

die() { printf 'publish-pack: %s\n' "$1" >&2; exit 1; }

while [ $# -gt 0 ]; do
  case "$1" in
    --version) VERSION="$2"; shift 2;;
    --type)    TYPE="$2";    shift 2;;
    --min-app) MIN_APP="$2"; shift 2;;
    --key)     KEY="$2";     shift 2;;
    --key-id)  KEY_ID="$2";  shift 2;;
    --sku)     SKU="$2";     shift 2;;
    --requires) REQUIRES="$2"; shift 2;;
    --dry-run) DRY=1;        shift;;
    --*)       die "unknown flag $1";;
    *)         DIR="$1";     shift;;
  esac
done

[ -n "$DIR" ] || die 'pass the pack directory, e.g. tools/icons/out/arcticons-line'
[ -d "$DIR" ] || die "not a directory: $DIR"
[ -n "$VERSION" ] || die '--version is required. It must be higher than the published one.'
case "$VERSION" in ''|*[!0-9]*) die "--version must be a positive integer, got '$VERSION'";; esac

PACK_ID="$(basename "$DIR")"
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
REPO="$(cd "$ROOT/../.." && pwd)"
SIGN="$REPO/tools/sign-pack.mjs"
[ -f "$SIGN" ] || die "no sign-pack.mjs at $SIGN"
# ─── TWO KINDS OF PACK, AND THIS ONLY EVER KNEW ONE ─────────────────────────
#
# An ICON pack is exactly one file, `pack.json`, and its shape is checkable.
# A THEME pack is `theme.json` plus wallpapers and previews, and its file list
# is whatever the theme has.
#
# Every check below assumed the first, so republishing a theme died on "no
# pack.json" before doing anything, and would have died again on the stray-file
# guard for having a wallpaper in it.
if [ -f "$DIR/pack.json" ]; then
  KIND="icon"
elif [ -f "$DIR/theme.json" ]; then
  KIND="theme"
  [ "$TYPE" = "brand" ] && TYPE="theme"
else
  die "no pack.json or theme.json in $DIR"
fi

if [ "$KIND" = "icon" ]; then
  # The directory is signed WHOLE, so anything sitting in it ships to every
  # device. An icon pack is one known file, so anything else is a leftover.
  STRAY="$(find "$DIR" -maxdepth 1 -type f ! -name 'pack.json' ! -name 'manifest.json' ! -name 'manifest.sig' | head -5)"
  [ -z "$STRAY" ] || die "unexpected files in $DIR, which would be signed into the pack:
$STRAY"

  echo "── 1. shape ──"
  node "$ROOT/tools/icons/pack-shape.test.mjs" "$DIR/pack.json" >/dev/null \
    || die 'pack.json failed the shape contract. Nothing signed.'
  echo "   ok"
else
  # A theme's file set cannot be enumerated up front, so the equivalent check is
  # the narrow one: a stale manifest from a previous publish must not survive
  # into the directory `sign-pack.mjs` is about to regenerate one for.
  # `strip-hero.mjs` already removes them; this is the floor beneath that.
  rm -f "$DIR/manifest.json" "$DIR/manifest.sig"
  echo "── 1. shape ──"
  echo "   theme pack, $(find "$DIR" -maxdepth 1 -type f | wc -l | tr -d ' ') files"
fi

echo "── 2. sign ──"
node "$SIGN" sign "$DIR" \
  --type "$TYPE" --id "$PACK_ID" --version "$VERSION" \
  --min-app "$MIN_APP" --key-id "$KEY_ID" --key "$KEY" | head -2

echo "── 3. verify ──"
# Derived from the key actually used, not typed from PackKeys.kt. Typing it
# would verify that the pack matches the key you BELIEVE you signed with.
PUB="$(node "$ROOT/tools/icons/pubkey.mjs" "$KEY")"
node "$SIGN" verify "$DIR" --pub "$PUB"

# ─── SIZE IS THE WHOLE PACK, NOT ONE FILE ───────────────────────────────────
#
# It read `pack.json` alone, which is right for an icon pack because that IS the
# pack, and wrong for a theme by the size of its wallpapers. The index uses this
# for the free-space check before a download, so understating it means a device
# starts a transfer it cannot finish.
SIZE="$(find "$DIR" -maxdepth 1 -type f ! -name 'manifest.sig' -exec wc -c {} + | tail -1 | awk '{print $1}')"

# ─── `path` IS A DIRECTORY, AND THIS WROTE A FILE ────────────────────────────
#
# `PackDownloader` builds its URL as:
#
#     val prefix = "$remoteRoot/${remote.path}"
#     client.fetch("$prefix/manifest.json", ...)
#
# so `path` must be the DIRECTORY the pack's files sit in. This script wrote
# `packs/<id>/pack.json`, so every device fetched
# `packs/<id>/pack.json/manifest.json` and got a 404. That is the whole of
# "Could not download garuda-dr460nized-line, try again": the pack was signed
# correctly, uploaded correctly, and advertised at an address that does not
# exist.
#
# The layout has to match `publish-core.ts` exactly, because the panel and this
# script write into the same catalogue and a device follows whichever `path` it
# reads. That is `dirFor(packType)/packId/version`:
#
#     brandpacks/kali-2024-line/1787572574
#     themes/kali-2024-theme/1787574000
#
# The VERSION SEGMENT is not decoration either. Without it a republish
# overwrites the bytes an older index still points at, so a device that has not
# refreshed downloads new files against an old manifest and fails verification.
case "$TYPE" in
  theme)  PACK_DIR="themes";;
  brand)  PACK_DIR="brandpacks";;
  hero)   PACK_DIR="heropacks";;
  icon)   PACK_DIR="iconpacks";;
  *)      die "unknown pack type '$TYPE'";;
esac
PACK_PATH="$PACK_DIR/$PACK_ID/$VERSION"

echo "── 4. read the LIVE index ──"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
# NO `curl -f`. It exits non-zero on a 4xx, which fires the `||` and appends the
# fallback to the code already written: a 403 came back as "403000" and matched
# neither branch, so the abort message was a nonsense number instead of a reason.
HTTP="$(curl -sS -o "$WORK/index.json" -w '%{http_code}' "$CDN/$PREFIX/index.json" 2>/dev/null || echo 000)"
if [ "$HTTP" = "200" ]; then
  echo "   fetched $(wc -c < "$WORK/index.json" | tr -d ' ') bytes"
elif [ "$HTTP" = "404" ]; then
  # A genuinely absent index is the only case where writing a fresh one is
  # correct, and it is worth being loud about: it is indistinguishable from a
  # typo in the URL until it has unpublished everything.
  echo "   no index published yet, starting a new one"
  printf '{"formatVersion":1,"generatedAt":0,"keyId":"%s","packs":[]}' "$KEY_ID" > "$WORK/index.json"
else
  die "could not read the live index (HTTP $HTTP) at $CDN/$PREFIX/index.json

  Refusing to write a fresh one, because the index is a single object holding
  every pack and replacing it would unpublish everything else. Nothing has been
  uploaded. Check the network, then re-run."
fi

echo "── 5. merge ──"
# ─── THE NAME COMES OUT OF THE PACK ─────────────────────────────────────────
#
# An icon pack's `pack.json` and a theme's `theme.json` both carry `name`, which
# is the string a user reads on the card. Without it the index carries no title
# and the device shows the pack id, which is how "Kali Linux Icons" became
# "kali-202...".
SRC="$DIR/pack.json"
[ -f "$SRC" ] || SRC="$DIR/theme.json"
# The colour, out of the pack itself. A derived icon pack authors `tint`; a
# theme and a hero pack do not, and get nothing.
TINT="$(node -e "
  const fs = require('fs');
  try {
    const j = JSON.parse(fs.readFileSync('$SRC', 'utf8'));
    process.stdout.write(String(j.tint || ''));
  } catch { process.stdout.write(''); }
")"

TITLE="$(node -e "
  const fs = require('fs');
  try {
    const j = JSON.parse(fs.readFileSync('$SRC', 'utf8'));
    process.stdout.write(String(j.name || ''));
  } catch { process.stdout.write(''); }
")"

node "$ROOT/tools/icons/merge-index.mjs" "$WORK/index.json" \
  --pack-id "$PACK_ID" --type "$TYPE" --version "$VERSION" \
  --min-app "$MIN_APP" --path "$PACK_PATH" --size "$SIZE" \
  --key-id "$KEY_ID" ${TITLE:+--title "$TITLE"} ${TINT:+--tint "$TINT"} \
  ${SKU:+--sku "$SKU"} ${REQUIRES:+--requires "$REQUIRES"}

echo "── 6. sign the index ──"
node "$SIGN" sign-index "$WORK/index.json" --key "$KEY"

if [ "$DRY" = "1" ]; then
  echo
  echo "dry run, nothing uploaded. The merged index is at:"
  echo "  $WORK/index.json"
  trap - EXIT
  exit 0
fi

echo "── 7. upload the pack ──"
# `--remote` or wrangler v4 acts on the local miniflare simulation and reports
# success. That failure looks exactly like a CDN cache that has not expired.
# EVERY file in the directory, not a hardcoded three. A theme's wallpapers are
# part of the pack and are covered by the same signature, so uploading only the
# json and the manifest would publish a manifest describing files that are not
# there.
for path in "$DIR"/*; do
  [ -f "$path" ] || continue
  f="$(basename "$path")"
  case "$f" in
    *.sig)  CT="application/octet-stream";;
    *.json) CT="application/json";;
    *.webp) CT="image/webp";;
    *.png)  CT="image/png";;
    *.jpg|*.jpeg) CT="image/jpeg";;
    *)      CT="application/octet-stream";;
  esac
  npx wrangler@latest r2 object put "$BUCKET/$PREFIX/$PACK_PATH/$f" \
    --file "$path" --remote --content-type "$CT" >/dev/null
  echo "   $f"
done

echo "── 8. upload the index ──"
# The index LAST. Uploading it before the pack files would advertise bytes that
# are not there yet, and every device polling in between records a failed
# download. Short cache because this is the file that announces every change.
for f in index.json index.sig; do
  if [ "$f" = "index.sig" ]; then CT="application/octet-stream"; else CT="application/json"; fi
  npx wrangler@latest r2 object put "$BUCKET/$PREFIX/$f" \
    --file "$WORK/$f" --remote --content-type "$CT" \
    --cache-control "public, max-age=300" >/dev/null
  echo "   $f"
done

echo
echo "published $PACK_ID v$VERSION  ($(( SIZE / 1024 )) KB)"
echo "  $CDN/$PREFIX/$PACK_PATH"
