#!/usr/bin/env bash
#
# PHASE C2 — stamp, sign and check the CDN index before you upload it.
#
#   ./tools/publish-index.sh
#   ./tools/publish-index.sh --key @$HOME/.mindberzerk/pack-signing.key
#
# WHY THIS EXISTS RATHER THAN "EDIT THE JSON AND RUN sign-index".
#
# `generatedAt` is the rollback floor. The device REFUSES an index older than
# the one it already holds, which is what stops a stale CDN edge (or a replay)
# from hiding an update forever. That protection has one failure mode, and it is
# entirely on the publisher: forget to bump the timestamp, and every device that
# already synced ignores your new index silently. Nothing errors, nothing logs,
# the packs just never appear. This script removes the chance to forget.
#
# It also re-signs every time, because the signature covers the file's EXACT
# bytes. Changing generatedAt without re-signing produces an index that looks
# perfect in an editor and fails verification on every device.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INDEX="$ROOT/cdn/index.json"
SIG="$ROOT/cdn/index.sig"
KEY="${2:-@$HOME/.mindberzerk/pack-signing.key}"

if [ ! -f "$INDEX" ]; then
  echo "no $INDEX" >&2
  exit 1
fi

# Stamp with now, in unix seconds. `date +%s` is identical on macOS and Linux,
# unlike almost every other date invocation.
NOW="$(date +%s)"
PREV="$(node -e "process.stdout.write(String(JSON.parse(require('fs').readFileSync('$INDEX')).generatedAt))")"

if [ "$NOW" -le "$PREV" ]; then
  # Only reachable with a badly wrong system clock, but a clock that is a day
  # behind would publish an index every device refuses, and the symptom is
  # indistinguishable from the upload having failed.
  echo "system clock says $NOW, which is not after the previous $PREV. Fix the clock." >&2
  exit 1
fi

node -e "
  const fs = require('fs');
  const p = '$INDEX';
  const o = JSON.parse(fs.readFileSync(p, 'utf8'));
  o.generatedAt = $NOW;
  // Two-space indent and a trailing newline, matching what sign-index signs.
  fs.writeFileSync(p, JSON.stringify(o, null, 2) + '\n');
"

node "$ROOT/tools/sign-pack.mjs" sign-index "$INDEX" --key "$KEY"

echo
echo "generatedAt: $PREV -> $NOW"
echo
echo "Upload BOTH to the bucket root at g-launcher/ :"
echo "  $INDEX   -> g-launcher/index.json"
echo "  $SIG     -> g-launcher/index.sig"
echo
echo "Upload them TOGETHER. An index.json without a matching index.sig fails"
echo "verification on every device, and the launcher keeps the index it had."
