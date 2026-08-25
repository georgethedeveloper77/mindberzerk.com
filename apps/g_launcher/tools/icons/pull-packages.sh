#!/bin/bash
#
# PULL THE DEVICE'S PACKAGE LIST, SAFELY.
#
# ─── WHY THIS IS NOT A ONE-LINER ─────────────────────────────────────────────
#
# The obvious command is a redirect:
#
#     adb shell pm list packages | sed 's/^package://' > tools/icons/packages.txt
#
# and it has now destroyed the list twice. The shell TRUNCATES the redirect
# target before running anything, so every failure downstream leaves a zero-byte
# file behind and the error scrolls past above it. The list is gone whether adb
# succeeded or not.
#
# So: everything is written to a temp file, checked, and only then moved into
# place. A failed pull leaves the previous list exactly as it was.
#
# ─── AND WHY --user 0 ────────────────────────────────────────────────────────
#
# On a Samsung with Secure Folder, a work profile or Dual Messenger, the
# foreground user is not user 0, and `pm list packages` defaults to whoever that
# is. adb shell has no permission there, so it throws:
#
#     SecurityException: Shell does not have permission to access user 150
#
# User 0 is the main profile and the one whose apps the pack is for.
#
#   ./tools/icons/pull-packages.sh [output-path]

set -u

OUT="${1:-tools/icons/packages.txt}"
TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT

die() { printf 'pull-packages: %s\n' "$1" >&2; exit 1; }

command -v adb >/dev/null 2>&1 || die 'adb is not on PATH'

# `adb devices` prints a header line even with nothing attached, so the count
# has to skip it. An unauthorised device also lists, hence the state check.
STATE="$(adb devices | awk 'NR>1 && NF {print $2; exit}')"
[ -n "$STATE" ] || die 'no device. Plug the phone in and unlock it.'
[ "$STATE" = "device" ] || die "device is in state '$STATE'. Accept the USB debugging prompt on the phone."

CURRENT="$(adb shell am get-current-user 2>/dev/null | tr -d '\r' | tr -d '[:space:]')"
if [ -n "$CURRENT" ] && [ "$CURRENT" != "0" ]; then
  printf 'note: foreground user is %s, reading user 0 instead\n' "$CURRENT" >&2
fi

# ─── LAUNCHABLE APPS, NOT INSTALLED PACKAGES ─────────────────────────────────
#
# `pm list packages` returns everything on the device, and on a Samsung that is
# mostly things a launcher will never draw:
#
#     com.android.internal.display.cutout.emulation.corner
#     com.android.internal.systemui.navbar.gestural
#     com.android.cts.ctsshim
#     android.autoinstalls.config.samsung
#
# Overlays, shims, providers and config packages. Measured on a real S22: 499
# packages of which only about a quarter have a drawing in Arcticons, which
# reads as terrible coverage and is actually a terrible QUESTION. No icon set
# has a drawing for a display-cutout overlay, and no launcher shows one.
#
# Querying for the LAUNCHER intent asks the thing that matters: what has an
# entry the user can tap. That is the set a pack should cover, and it is the
# set the coverage percentage should be measured against.
#
# `tr -d '\r'` is not cosmetic either. adb shell on macOS emits CRLF, and a
# surviving carriage return makes every id miss the map, which reads as "the
# index is broken" rather than "the file has invisible characters in it".
LAUNCHABLE=0
if adb shell cmd package query-activities --brief --user 0 \
     -a android.intent.action.MAIN -c android.intent.category.LAUNCHER \
     2>"$TMP.err" \
   | tr -d '\r' \
   | sed -n 's|^[[:space:]]*\([a-zA-Z][a-zA-Z0-9_.]*\)/.*|\1|p' \
   | sort -u > "$TMP" && [ -s "$TMP" ]; then
  LAUNCHABLE=1
else
  # Older or locked-down builds have no `query-activities`. Falling back is
  # better than failing, and the count in the report says which one ran so a
  # surprising coverage number can be explained rather than puzzled over.
  if ! adb shell pm list packages --user 0 2>"$TMP.err" \
       | sed 's/^package://' | tr -d '\r' | sort -u > "$TMP"; then
    die "adb failed: $(head -2 "$TMP.err" | tr '\n' ' ')"
  fi
fi

if [ -s "$TMP.err" ] && grep -q 'Exception' "$TMP.err"; then
  die "adb reported: $(grep -m1 'Exception' "$TMP.err")"
fi

COUNT="$(wc -l < "$TMP" | tr -d ' ')"
[ "$COUNT" -gt 0 ] || die 'read zero packages. The previous list has been left alone.'

# A list of package ids should look like package ids. A shell error captured
# into the file would still be non-empty, and would then be reported downstream
# as "malformed ids" rather than as a failed pull.
VALID="$(grep -c '^[a-z][a-z0-9_]*\(\.[a-z0-9_]\+\)\+$' "$TMP" || true)"
[ "$VALID" -gt $(( COUNT / 2 )) ] || die "only $VALID of $COUNT lines look like package ids. Nothing written."

mkdir -p "$(dirname "$OUT")"
mv "$TMP" "$OUT"
if [ "$LAUNCHABLE" = "1" ]; then
  printf 'wrote %s  (%s launchable apps, %s valid ids)\n' "$OUT" "$COUNT" "$VALID"
else
  printf 'wrote %s  (%s installed packages, %s valid ids)\n' "$OUT" "$COUNT" "$VALID"
  printf 'note: query-activities was unavailable, so this includes overlays and\n' >&2
  printf '      providers no launcher draws. Coverage will read low.\n' >&2
fi
