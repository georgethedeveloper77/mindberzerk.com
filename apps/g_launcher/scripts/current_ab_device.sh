#!/system/bin/sh
# current_ab_device.sh: the half of current_ab.sh that runs ON the phone.
#
# Started detached by the host script, so it keeps running after the USB
# cable is pulled. That is the point: a phone on a cable is charging, and a
# discharge reading taken while charging is meaningless.
#
# Sequence: wait for unplug, then G Launcher, other home, G Launcher again,
# each sampled once a second for WINDOW seconds at a fixed brightness. When
# finished it restores every setting it touched and turns the screen off,
# which is the cue to plug back in.
#
# Args: WINDOW HOME_A HOME_B OUT

WINDOW="$1"
HOME_A="$2"
HOME_B="$3"
OUT="$4"

NODE=/sys/class/power_supply/battery/current_now
BRIGHTNESS=128   # mid-scale, identical for every run
SETTLE=8         # seconds for icon loads and entry animations after HOME
UNPLUG_TIMEOUT=300

log() { echo "$*" >> "$OUT"; }

on_power() { dumpsys battery | grep -q 'powered: true'; }

# Component answering HOME, for one package or for the current default.
home_component() {
  if [ -n "$1" ]; then
    cmd package resolve-activity --brief -a android.intent.action.MAIN \
      -c android.intent.category.HOME -p "$1" | tail -n 1
  else
    cmd package resolve-activity --brief -a android.intent.action.MAIN \
      -c android.intent.category.HOME | tail -n 1
  fi
}

# ---- save state, and always restore it ------------------------------------

ORIG_HOME="$(home_component)"
# No default set resolves to the chooser, which is not a valid restore target.
case "$ORIG_HOME" in
  */*ResolverActivity|"") ORIG_HOME="$(home_component "$HOME_A")" ;;
esac
ORIG_TIMEOUT="$(settings get system screen_off_timeout)"
ORIG_MODE="$(settings get system screen_brightness_mode)"
ORIG_LEVEL="$(settings get system screen_brightness)"

restore() {
  cmd package set-home-activity "$ORIG_HOME" >/dev/null 2>&1
  settings put system screen_brightness "$ORIG_LEVEL"
  settings put system screen_brightness_mode "$ORIG_MODE"
  settings put system screen_off_timeout "$ORIG_TIMEOUT"
  input keyevent KEYCODE_HOME
  sleep 2
  input keyevent KEYCODE_SLEEP   # screen off: the cue to plug back in
}
trap restore EXIT

: > "$OUT"
settings put system screen_off_timeout 1800000
settings put system screen_brightness_mode 0
settings put system screen_brightness "$BRIGHTNESS"
input keyevent KEYCODE_WAKEUP

# ---- wait for the cable ---------------------------------------------------

waited=0
while on_power; do
  if [ "$waited" -ge "$UNPLUG_TIMEOUT" ]; then
    log "error: still on external power after ${UNPLUG_TIMEOUT}s"
    exit 1
  fi
  sleep 1
  waited=$((waited + 1))
done

# ---- measure --------------------------------------------------------------

# Mean absolute current over WINDOW one-second samples, in the node's own
# unit. Absolute because OEMs disagree on the sign while discharging.
sample_mean() {
  total=0
  n=0
  while [ "$n" -lt "$WINDOW" ]; do
    v="$(cat "$NODE")"
    total=$((total + ${v#-}))
    n=$((n + 1))
    sleep 1
  done
  echo $((total / WINDOW))
}

measure() {
  component="$(home_component "$1")"
  case "$component" in
    */*) ;;
    *) log "error: $1 has no HOME activity"; exit 1 ;;
  esac

  cmd package set-home-activity "$component" >/dev/null 2>&1
  input keyevent KEYCODE_HOME
  sleep "$SETTLE"

  mean="$(sample_mean)"
  # A cable reconnected mid-window turns the reading into a charge rate.
  if on_power; then
    log "error: plugged back in before the run finished"
    exit 1
  fi
  log "$1 $mean"
}

measure "$HOME_A"
measure "$HOME_B"
measure "$HOME_A"   # repeated so drift across the run is visible
log "status: done"
