#!/usr/bin/env bash
# idle_probe.sh: measures G Launcher's idle cost on a connected device.
#
# Phase 1 leaves the launcher untouched on the home screen.
# Phase 2 puts it in the background behind Settings.
# For each phase it reports CPU time burned by the launcher process (all
# threads), plus IDLE_PROBE frame lines when the app was built with
# --dart-define=IDLE_PROBE=true. It ends with the per-app batterystats.
#
# Targets: home ~0 frames and <50 ms CPU per 10 s; background ~0 ms CPU.
#
# Usage: scripts/idle_probe.sh [window_seconds]   (default 30)
set -euo pipefail

readonly PKG="com.mindhunter.g_launcher"
readonly WINDOW="${1:-30}"

# adb shell output carries CRLF on some devices; strip it.
sh_() { adb shell "$@" | tr -d '\r'; }

CLK_TCK="$(sh_ getconf CLK_TCK 2>/dev/null || true)"
[[ "$CLK_TCK" =~ ^[0-9]+$ ]] || CLK_TCK=100

ORIG_TIMEOUT="$(sh_ settings get system screen_off_timeout)"

# Always undo the fake unplug and the screen timeout, even on Ctrl-C.
restore() {
  sh_ dumpsys battery reset >/dev/null || true
  sh_ settings put system screen_off_timeout "$ORIG_TIMEOUT" >/dev/null || true
}
trap restore EXIT

# Total CPU (user + system, every thread) for a pid, in clock ticks.
cpu_ticks() { sh_ cat "/proc/$1/stat" | awk '{print $14 + $15}'; }

measure() {
  local label="$1" pid t0 t1 ms

  pid="$(sh_ pidof "$PKG")"
  [[ -n "$pid" ]] || { echo "$PKG is not running" >&2; exit 1; }

  adb logcat -c
  t0="$(cpu_ticks "$pid")"
  sleep "$WINDOW"
  t1="$(cpu_ticks "$pid")"
  ms=$(( (t1 - t0) * 1000 / CLK_TCK ))

  printf '\n== %s (%ss) ==\n' "$label" "$WINDOW"
  printf 'CPU: %d ms total, %d ms per 10s\n' "$ms" $(( ms * 10 / WINDOW ))
  adb logcat -d -s flutter | grep 'frame probe' \
    || echo 'frames: no frame probe lines (probe disabled in this build?)'
}

# Sensors this app still holds right now. Should be empty in the background.
held_sensors() {
  printf '\n== sensors held by %s ==\n' "$PKG"
  sh_ dumpsys sensorservice | grep -B1 -A8 "$PKG" || echo 'none'
}

sh_ settings put system screen_off_timeout 1800000 >/dev/null
# Over USB the device is charging, and batterystats only records discharge.
sh_ dumpsys battery unplug >/dev/null
sh_ dumpsys batterystats --reset >/dev/null

sh_ input keyevent KEYCODE_WAKEUP
sh_ input keyevent KEYCODE_HOME
sleep 3  # let the home transition settle before sampling
measure "Home, untouched"

sh_ am start -a android.settings.SETTINGS >/dev/null
sleep 3
measure "Background, Settings in front"
held_sensors

sh_ input keyevent KEYCODE_HOME

printf '\n== batterystats: %s ==\n' "$PKG"
sh_ dumpsys batterystats "$PKG" \
  | grep -E 'Wake lock|Wakeup alarm|Job |Sensor [0-9]+: [0-9]|Cpu:|Foreground' \
  || echo 'nothing recorded'
