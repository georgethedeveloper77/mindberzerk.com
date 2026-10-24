#!/usr/bin/env bash
# Screen-off battery cost of G Launcher, measured over a fixed window.
#
# Both earlier dumps were taken seconds after --reset, so every figure in them
# was the noise of the reset itself: "Computed drain: 0" and a per-uid 0.0235
# mAh over a few minutes say nothing about a night in a pocket. This waits.
#
#   ./measure_battery.sh before 120
#   (install the fixed build)
#   ./measure_battery.sh after 120
#   diff ~/Desktop/glauncher-battery-before.txt ~/Desktop/glauncher-battery-after.txt
#
# Reports land in ~/Desktop by default; set OUTDIR to change it.
#
# Conditions must match between the two runs: same charge level band, no
# charger, screen off the whole time, phone untouched, same distro and same
# desklets on the home screen.

set -euo pipefail

LABEL="${1:-run}"
MINUTES="${2:-120}"
PKG="${3:-com.mindhunter.g_launcher}"

SERIAL="$(adb devices | awk '/\tdevice$/ {print $1; exit}')"
if [ -z "$SERIAL" ]; then
  echo "No device. Connect one, or disconnect the duplicate wireless transport." >&2
  exit 1
fi
adb() { command adb -s "$SERIAL" "$@"; }

# `pm list packages -U` is the stable source for the uid. Parsing dumpsys for
# "userId=" broke here: awk exiting early closed the pipe under pipefail, so the
# assignment came back empty on a package that was installed all along.
if ! adb shell pm path "$PKG" | grep -q "package:"; then
  echo "$PKG is not installed on $SERIAL." >&2
  exit 1
fi

APPUID="$(adb shell pm list packages -U "$PKG" \
  | tr -d '\r' \
  | grep -F "package:$PKG " \
  | sed -n 's/.*uid://p')"
if [ -z "$APPUID" ]; then
  echo "Could not read the uid for $PKG." >&2
  exit 1
fi
# batterystats writes u0aNNN where NNN is the uid minus the 10000 app base.
UIDTAG="u0a$((APPUID - 10000))"
OUTDIR="${OUTDIR:-$HOME/Desktop}"
mkdir -p "$OUTDIR"
OUT="$OUTDIR/glauncher-battery-$LABEL.txt"
RAW="$OUTDIR/glauncher-batterystats-$LABEL.txt"

# Charger attached means no battery stats worth reading, and adb over USB is a
# charger. Use wireless adb, or unplug and connect over tcpip, for a real run.
# A charging run records nothing: batterystats only accumulates on battery, so
# the window that ran from 12% to 95% came back with "Computed drain: 0" and a
# per-uid figure that was pure charging-period noise. Abort instead of warning.
if adb shell dumpsys battery | grep -qE "^  (AC|USB|Wireless) powered: true"; then
  echo "Device is charging. Unplug, use wireless adb, and rerun (FORCE=1 to override)." >&2
  [ "${FORCE:-0}" = "1" ] || exit 1
fi

# Which build is being measured. An install that failed with
# INSTALL_FAILED_VERSION_DOWNGRADE leaves the previous APK in place, so a run
# labelled "before" can silently measure the same code as "after".
VERSION="$(adb shell dumpsys package "$PKG" | tr -d "\r" \
  | sed -n "s/.*versionCode=\([0-9]*\).*/\1/p" | head -1)"
echo "Measuring versionCode ${VERSION:-unknown}"

echo "Device $SERIAL, $PKG is $UIDTAG, window ${MINUTES}m, output $OUT"

# Home first, so the launcher is the resumed activity, then screen off.
adb shell input keyevent KEYCODE_HOME
sleep 2
if adb shell dumpsys deviceidle get screen | grep -q true; then
  adb shell input keyevent KEYCODE_POWER
fi

adb shell dumpsys batterystats --reset >/dev/null
START_LEVEL="$(adb shell dumpsys battery | awk -F': ' '/^  level:/{print $2}' | tr -d '\r')"
echo "Start level ${START_LEVEL}%. Leave the phone alone until $(date -v+"${MINUTES}"M '+%H:%M' 2>/dev/null || date -d "+${MINUTES} minutes" '+%H:%M')."

sleep $((MINUTES * 60))

END_LEVEL="$(adb shell dumpsys battery | awk -F': ' '/^  level:/{print $2}' | tr -d '\r')"
adb shell dumpsys batterystats > "$RAW"

{
  echo "=== $LABEL: ${MINUTES}m, battery ${START_LEVEL}% to ${END_LEVEL}%, versionCode ${VERSION:-unknown} ==="
  echo
  echo "--- whole device ---"
  grep -E "Capacity:.*Computed drain" "$RAW" || true
  echo
  echo "--- $PKG ($UIDTAG) estimated power ---"
  grep -E "UID $UIDTAG:" "$RAW" || echo "no power attributed"
  grep -A2 "^  $UIDTAG:" "$RAW" | grep -E "screen=|cpu=" || true
  echo
  echo "--- $UIDTAG detail (cpu, wakelocks, jobs, alarms) ---"
  awk "/^  $UIDTAG:/{f=1} f&&/^  [a-zA-Z0-9]+:/&&!/^  $UIDTAG:/{f=0} f" \
    "$RAW" \
    | grep -iE "cpu|wake|job|alarm|sensor|foreground|wifi|mobile" || echo "nothing recorded"
  echo
  echo "--- top ten power users, for context ---"
  grep -E "^  UID u0a[0-9]+: " "$RAW" | sort -t: -k2 -g -r | head -10 || true
} | tee "$OUT"
