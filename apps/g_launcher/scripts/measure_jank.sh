#!/usr/bin/env bash
#
# measure_jank.sh - frame-timing probe for an on-device animation.
#
# Browser FPS counters lie about Android: they miss vsync misses, GPU
# composition cost and the SurfaceFlinger queue. This reads the same
# counters the Play Console Android vitals dashboard uses.
#
# Usage:
#   ./measure_jank.sh                       # 15s on G Launcher
#   ./measure_jank.sh com.mindhunter.g_launcher 20
#
# Exercise the animation by hand while the countdown runs.

set -euo pipefail

PKG="${1:-com.mindhunter.g_launcher}"
SECONDS_TO_RECORD="${2:-15}"
OUT_DIR="${TMPDIR:-/tmp}/jank-$(date +%Y%m%d-%H%M%S)"

command -v adb >/dev/null || { echo "adb not on PATH"; exit 1; }

# Fail early rather than reporting zeros for an app that is not running.
adb shell pidof "$PKG" >/dev/null 2>&1 || {
  echo "$PKG is not running. Launch it first, then rerun."
  exit 1
}

mkdir -p "$OUT_DIR"

# Refresh rate decides the frame budget: 16.7ms at 60Hz, 8.3ms at 120Hz.
REFRESH="$(adb shell dumpsys display \
  | grep -om1 'fps=[0-9.]*' \
  | cut -d= -f2 || true)"
REFRESH="${REFRESH:-60}"
BUDGET_MS="$(awk -v r="$REFRESH" 'BEGIN { printf "%.1f", 1000 / r }')"

echo "package     $PKG"
echo "refresh     ${REFRESH}Hz  (budget ${BUDGET_MS}ms)"
echo

# Reset clears the rolling histogram so the numbers describe this run only.
adb shell dumpsys gfxinfo "$PKG" reset >/dev/null

echo "Recording for ${SECONDS_TO_RECORD}s. Drag the scrubber now."
for ((i = SECONDS_TO_RECORD; i > 0; i--)); do
  printf '\r  %2ds remaining ' "$i"
  sleep 1
done
printf '\r%*s\r' 20 ''

adb shell dumpsys gfxinfo "$PKG" framestats > "$OUT_DIR/gfxinfo.txt"

# --- summary counters -------------------------------------------------------

echo "== summary =="
grep -E 'Total frames|Janky frames|Number Missed Vsync|Number High input|Number Slow UI thread|Number Slow bitmap|Number Slow issue draw|percentile' \
  "$OUT_DIR/gfxinfo.txt" || echo "(no summary block; app may have restarted)"

# --- per-frame distribution -------------------------------------------------
#
# The PROFILEDATA block is CSV. Column 2 is INTENDED_VSYNC and the last
# column is FRAME_COMPLETED, both in nanoseconds; their difference is the
# wall-clock cost of that frame. Rows with a zero completion time are
# frames that were dropped before measurement and are skipped.

# Frame costs are extracted first, then sorted externally, so the script
# runs on BSD awk (macOS) as well as gawk.
awk '
  /^---PROFILEDATA---/ { inblock = !inblock; next }
  !inblock || /^Flags/  { next }
  {
    n = split($0, f, ",")
    if (n < 14 || f[2] == 0 || f[n - 1] == 0) next
    ms = (f[n - 1] - f[2]) / 1000000
    if (ms > 0 && ms < 2000) printf "%.3f\n", ms   # discard clock glitches
  }
' "$OUT_DIR/gfxinfo.txt" | sort -n > "$OUT_DIR/frames.txt"

echo
echo "== per-frame =="
awk -v budget="$BUDGET_MS" '
  { ms[NR] = $1; sum += $1; if ($1 > budget) over++; if ($1 > budget * 2) double++ }
  END {
    if (!NR) { print "no frames captured"; exit }
    printf "frames        %d\n", NR
    printf "mean          %.2f ms\n", sum / NR
    printf "p50           %.2f ms\n", ms[int(NR * 0.50) + 0 == 0 ? 1 : int(NR * 0.50)]
    printf "p95           %.2f ms\n", ms[int(NR * 0.95) + 0 == 0 ? 1 : int(NR * 0.95)]
    printf "p99           %.2f ms\n", ms[int(NR * 0.99) + 0 == 0 ? 1 : int(NR * 0.99)]
    printf "worst         %.2f ms\n", ms[NR]
    printf "over budget   %.1f%% (%d frames)\n", over * 100 / NR, over
    printf "dropped 2+    %.1f%% (%d frames)\n", double * 100 / NR, double
  }
' "$OUT_DIR/frames.txt"

echo
echo "raw: $OUT_DIR/gfxinfo.txt"
