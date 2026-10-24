#!/usr/bin/env bash
# current_ab.sh: battery draw of G Launcher against another home app, with
# the phone OFF external power and no Wi-Fi adb needed.
#
# Pushes current_ab_device.sh to the phone and starts it detached from adb.
# You unplug, the phone measures on its own, the screen turns off when it is
# finished, you plug back in, and the results are pulled automatically.
#
# Same system wallpaper in both launchers before running.
#
# Usage: scripts/current_ab.sh [window_seconds] [other_home_package]
#   defaults: 60, com.sec.android.app.launcher (One UI Home)
set -euo pipefail

readonly WINDOW="${1:-60}"
readonly HOME_A="com.mindhunter.g_launcher"
readonly HOME_B="${2:-com.sec.android.app.launcher}"
readonly NODE="/sys/class/power_supply/battery/current_now"
readonly REMOTE="/data/local/tmp/current_ab_device.sh"
readonly OUT="/data/local/tmp/current_ab.txt"

here="$(cd "$(dirname "$0")" && pwd)"

adb get-state >/dev/null 2>&1 || { echo 'Plug the phone in over USB first.' >&2; exit 1; }
adb shell cat "$NODE" >/dev/null 2>&1 \
  || { echo "Cannot read $NODE on this device." >&2; exit 1; }

adb push "$here/current_ab_device.sh" "$REMOTE" >/dev/null
adb shell chmod 755 "$REMOTE"
adb shell rm -f "$OUT"
# nohup + background: the payload must outlive the adb session it starts in.
adb shell "nohup sh $REMOTE $WINDOW $HOME_A $HOME_B $OUT >/dev/null 2>&1 &"

minutes=$(( (3 * (WINDOW + 8) + 59) / 60 ))
cat <<MSG
Running on the phone.

  1. Unplug the USB cable now.
  2. Do not touch the phone for about ${minutes} min.
  3. Plug back in when the screen turns OFF.

MSG

adb wait-for-disconnect
echo 'Cable out. Measuring...'
adb wait-for-device
echo 'Cable back. Collecting results...'

# The payload writes "status: done" or "error: ..." as its last line.
until adb shell cat "$OUT" 2>/dev/null | tr -d '\r' | grep -qE '^(status: done|error:)'; do
  sleep 2
done

echo
printf '%-34s %12s\n' 'home app' 'mean current'
adb shell cat "$OUT" | tr -d '\r' | while read -r first second; do
  case "$first" in
    status:) ;;
    error:) echo "error: $second" >&2 ;;
    *) printf '%-34s %12s\n' "$first" "$second" ;;
  esac
done

adb shell rm -f "$REMOTE" "$OUT"
echo
echo "Units are the node's own (uA on most devices, mA on some Samsung builds)."
echo 'Compare rows; the A/B does not depend on the unit.'
