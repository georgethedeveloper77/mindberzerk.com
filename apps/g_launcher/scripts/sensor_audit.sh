#!/usr/bin/env bash
# sensor_audit.sh: finds what keeps sensors registered while G Launcher is
# in the background.
#
# 1. Removes the stray probe files left in lib/ by the previous drop.
# 2. Resolves packages if package_config.json is missing.
# 3. Scans the app and every plugin for native sensor registration.
# 4. If a device is attached, puts the launcher in the background and lists
#    the sensors it still holds, by name.
#
# Usage (from apps/g_launcher): scripts/sensor_audit.sh
set -euo pipefail

readonly PKG="com.mindhunter.g_launcher"

cd "$(dirname "$0")/.."

# Untracked leftovers from the last drop; the gate now ships in lib/core/.
rm -f lib/idle_frame_meter.dart lib/visibility_gate.dart

# Pub workspaces keep package_config.json at the workspace root.
has_config() {
  local dir="$PWD"
  while [[ "$dir" != "/" ]]; do
    [[ -f "$dir/.dart_tool/package_config.json" ]] && return 0
    dir="$(dirname "$dir")"
  done
  return 1
}
has_config || flutter pub get

printf '== Native sensor usage (app + plugins) ==\n'
python3 scripts/find_sensor_users.py

printf '\n== Sensors held in background ==\n'
if ! adb get-state >/dev/null 2>&1; then
  echo 'No device attached. Reconnect, check `adb devices`, then rerun.'
  exit 0
fi

adb shell am start -a android.settings.SETTINGS >/dev/null
sleep 3  # let the launcher reach the stopped state
adb shell dumpsys sensorservice | tr -d '\r' | grep -B1 -A8 "$PKG" \
  || echo 'none (sensors are released in the background)'
adb shell input keyevent KEYCODE_HOME
