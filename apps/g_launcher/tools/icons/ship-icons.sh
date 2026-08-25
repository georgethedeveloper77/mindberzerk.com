#!/bin/bash
#
# EVERY ICON, EVERY DISTRO, ONE COMMAND.
#
#   ./tools/icons/ship-icons.sh
#   ./tools/icons/ship-icons.sh --set ~/Downloads/iconpacks/Arcticons-main
#   ./tools/icons/ship-icons.sh --dry-run
#
#   --set        Arcticons clone. Default ~/Downloads/iconpacks/Arcticons-main
#   --skip-base  do not rebuild or republish arcticons-line, only the fourteen
#   --dry-run    build and sign everything, upload nothing
#
# ─── WHAT IT DOES, IN ORDER ─────────────────────────────────────────────────
#
#   1. licence check on the source set
#   2. convert every SVG to path data and verify nothing was skipped
#   3. build arcticons-line, 13,622 drawings
#   4. check the wire contract
#   5. publish it
#   6. build the fourteen colour packs
#   7. publish each, which merges into the live index one at a time
#   8. read the CDN back and prove all fifteen are there
#
# ─── WHY ONE SCRIPT AND NOT EIGHT COMMANDS ──────────────────────────────────
#
# The eight-command version was run by hand and `arcticons-line` went missing
# between step five and step seven, with nothing to say when. A sequence you run
# by hand is a sequence where step four gets skipped because it passed last
# time, and where the verification at the end is the first thing dropped when
# it is late.
#
# Step 8 is not decoration. It fetches the published index and asserts the count
# and every id, because every earlier step can report success against a local
# file and still leave the CDN wrong.

set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
OUT="$HERE/out"
# The canonical fourteen. Under admin/ because a Next.js bundler cannot import
# from outside it, while node can read anywhere; the constrained reader decides.
TABLE="$ROOT/../../admin/src/lib/g-launcher/distros.json"

SET="${HOME}/Downloads/iconpacks/Arcticons-main"
SKIP_BASE=0
DRY=""
CDN="${MB_CDN:-https://cdn.mindberzerk.com}"
PREFIX="${MB_PREFIX:-g-launcher}"

die() { printf '\nship-icons: %s\n\n' "$1" >&2; exit 1; }
step() { printf '\n\033[1m── %s ──\033[0m\n' "$1"; }

while [ $# -gt 0 ]; do
  case "$1" in
    --set)       SET="$2"; shift 2;;
    --skip-base) SKIP_BASE=1; shift;;
    --dry-run)   DRY="--dry-run"; shift;;
    *)           die "unknown flag $1";;
  esac
done

command -v node >/dev/null 2>&1 || die 'node is not on PATH'
[ -d "$SET" ] || die "no such directory: $SET"
[ -f "$ROOT/../../tools/sign-pack.mjs" ] || die "no sign-pack.mjs at the repo root"
[ -f "$TABLE" ] || die "no distros.json at $TABLE"

cd "$ROOT"

# ── 1. licence ──────────────────────────────────────────────────────────────
step "1. licence"
INSPECT="$(node "$HERE/inspect-iconset.mjs" --set "$SET")"
printf '%s\n' "$INSPECT" | grep -E "art licence|repo licence|art directory|A line set" || true
if printf '%s' "$INSPECT" | grep -q "CANNOT SHIP"; then
  die "the art licence forbids publishing this set. Nothing was built."
fi

# ── 2. converter, against the whole set ─────────────────────────────────────
#
# Not a formality. A skipped element costs a stroke silently, and there is no
# way to notice that across 13,622 drawings except by counting.
step "2. converter"
ART="$(printf '%s' "$INSPECT" | sed -n 's/.*art directory *\([^ ]*\).*/\1/p' | head -1)"
[ -n "$ART" ] || die 'could not find the art directory'
node "$HERE/svg-to-path.test.mjs" "$SET/$ART" | tail -4
node "$HERE/svg-to-path.test.mjs" "$SET/$ART" | grep -q "skipped elements: none" \
  || die 'the converter skipped elements. Fix it before publishing.'

if [ "$SKIP_BASE" = "0" ]; then
  # ── 3. the geometry ───────────────────────────────────────────────────────
  step "3. build arcticons-line"
  node "$HERE/build-vector-pack.mjs" --set "$SET" --id arcticons-line --name "Arcticons" \
    | grep -E "drawings|paths|packages mapped|gzipped|wrote"

  # ── 4. wire contract ──────────────────────────────────────────────────────
  #
  # Asserts `icons` precedes `glyphs`. That ordering is what lets the device
  # stream the map and skip the drawings it has no app for; reversing the two
  # keys looks like formatting and forces the whole pack resident in RAM.
  step "4. wire contract"
  node "$HERE/pack-shape.test.mjs" "$OUT/arcticons-line/pack.json" | tail -3

  # ── 5. publish the geometry ───────────────────────────────────────────────
  step "5. publish arcticons-line"
  "$HERE/publish-pack.sh" "$OUT/arcticons-line" --version "$(date +%s)" $DRY \
    | grep -E "ok|merged|added|updated|published|packs total" || true
else
  step "3-5. skipped, --skip-base"
fi

# ── 6. the fourteen ─────────────────────────────────────────────────────────
step "6. build the fourteen"
node "$HERE/build-official-packs.mjs" | tail -20

# ── 7. publish them ─────────────────────────────────────────────────────────
#
# One at a time, because `publish-pack.sh` reads the live index, merges one
# entry and signs. Each read sees the previous write, so the fourteen accumulate
# rather than racing.
step "7. publish the fourteen"
VERSION="$(date +%s)"
# Read ONCE rather than per pack: fourteen node startups to read the same
# constant is fourteen chances for one of them to differ.
MIN_APP="$(node -e "process.stdout.write(String(require('$TABLE').minAppVersion))")"
BASE_ID="$(node -e "process.stdout.write(require('$TABLE').base.packId)")"
for dir in "$OUT"/*-line; do
  id="$(basename "$dir")"
  [ "$id" = "arcticons-line" ] && continue
  # CommonJS `require` on purpose: `node -e` without `--input-type` is CJS, so
  # this is the form that works. The verifier is a `.mjs` FILE precisely so it
  # can use imports and top-level await without depending on that distinction.
  sku="$(node -e "
    const t = require('$TABLE');
    const d = t.distros.find(x => x.packId === '$id');
    process.stdout.write(d ? d.sku : '');
  ")"
  [ -n "$sku" ] || die "$id is not in distros.json"
  printf '   %s ' "$id"
  # `--requires` is not optional for these. Each is a pointer at the geometry;
  # without the declaration the downloader has no reason to fetch the base and
  # the pack installs, verifies and renders nothing.
  "$HERE/publish-pack.sh" "$dir" --version "$VERSION" --sku "$sku" \
    --min-app "$MIN_APP" --requires "$BASE_ID" \
    $DRY >/dev/null
  printf 'ok\n'
done

if [ -n "$DRY" ]; then
  printf '\ndry run. Nothing was uploaded.\n\n'
  exit 0
fi

# ── 8. prove it from the CDN, not from local files ──────────────────────────
step "8. verify against the CDN"
# A separate file rather than `node -e`. The inline version used `require()`
# inside `--input-type=module`, which does not exist there, and the flag sat
# after the script string where its handling is version-dependent. Both would
# have failed at the one step whose whole job is to catch failure.
node "$HERE/verify-live.mjs"

printf '\n\033[1mdone.\033[0m Delete kali-2024-icons in the panel so the line pack is not\n'
printf 'overridden by 54 hand-drawn icons, then reinstall on the device.\n\n'
