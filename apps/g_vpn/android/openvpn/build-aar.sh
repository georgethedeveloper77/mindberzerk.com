#!/usr/bin/env bash
# Builds the OpenVPN engine G VPN embeds, from the official OpenVPN for
# Android source (GPLv2), as an Android library (.aar).
#
#   bash apps/g_vpn/android/openvpn/build-aar.sh
#
# First run downloads the source with its native submodules (OpenSSL,
# OpenVPN 2/3, LZ4...) and compiles C/C++ for four ABIs: allow 10-20 minutes.
# Later runs reuse the download. The result is checked for Play's 16 KB
# page-size rule before it is copied into the app.
set -euo pipefail

ICS_TAG="v0.7.68"
HERE="$(cd "$(dirname "$0")" && pwd)"
WORK="$HERE/.build"
SRC="$WORK/ics-openvpn"
OUT="$HERE/../app/libs/ics-openvpn.aar"
SDK="${ANDROID_HOME:-$HOME/Library/Android/sdk}"

die() { echo "ERROR: $*" >&2; exit 1; }

# ── tools ──────────────────────────────────────────────────────────────────
command -v git >/dev/null || die "git not found"
command -v python3 >/dev/null || die "python3 not found"
# Upstream generates Java bindings with SWIG for every variant.
command -v swig >/dev/null || die "swig not found. Run: brew install swig"
[[ -d "$SDK" ]] || die "Android SDK not found at $SDK (set ANDROID_HOME)"
if [[ -z "${JAVA_HOME:-}" && -d "/Applications/Android Studio.app/Contents/jbr/Contents/Home" ]]; then
  export JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home"
fi
command -v java >/dev/null || [[ -n "${JAVA_HOME:-}" ]] || die "No JDK. Install Android Studio or set JAVA_HOME"

# ── source ─────────────────────────────────────────────────────────────────
mkdir -p "$WORK"
if [[ ! -d "$SRC/.git" ]]; then
  echo "== Downloading OpenVPN for Android $ICS_TAG (with native submodules)"
  git clone --branch "$ICS_TAG" --depth 1 --recurse-submodules --shallow-submodules \
    https://github.com/schwabe/ics-openvpn.git "$SRC"
else
  echo "== Resetting $ICS_TAG checkout"
  git -C "$SRC" reset -q --hard "$ICS_TAG"
  git -C "$SRC" submodule update -q --init --recursive
fi

# The patch is not idempotent, so it always runs on a clean tree.
git -C "$SRC" checkout -q -- .
python3 "$HERE/patch_ics.py" "$SRC"
echo "sdk.dir=$SDK" > "$SRC/local.properties"

# ── build ──────────────────────────────────────────────────────────────────
# skeleton = no upstream UI; ovpn2 = the OpenVPN 2 engine, which is what
# VPN Gate and most providers' .ovpn files are written for.
echo "== Building (skeleton, OpenVPN 2, release)"
(cd "$SRC" && ./gradlew --no-daemon -q :main:assembleSkeletonOvpn2Release)

AAR="$SRC/main/build/outputs/aar/main-skeleton-ovpn2-release.aar"
[[ -f "$AAR" ]] || die "build finished but $AAR is missing"

# ── 16 KB check ────────────────────────────────────────────────────────────
OBJDUMP=$(ls "$SDK"/ndk/*/toolchains/llvm/prebuilt/*/bin/llvm-objdump 2>/dev/null | tail -1)
[[ -n "$OBJDUMP" ]] || die "llvm-objdump not found in the NDK"
TMP=$(mktemp -d)
unzip -q -o "$AAR" 'jni/arm64-v8a/*' -d "$TMP"
bad=0
for so in "$TMP"/jni/arm64-v8a/*.so; do
  align=$("$OBJDUMP" -p "$so" | awk '/LOAD/{print $NF; exit}')
  printf '   %-28s %s\n' "$(basename "$so")" "$align"
  [[ "$align" == "2**14" || "$align" == "2**16" ]] || bad=1
done
rm -rf "$TMP"
[[ $bad -eq 0 ]] || die "a native library is not 16 KB aligned (above). Not copying."

mkdir -p "$(dirname "$OUT")"
cp "$AAR" "$OUT"
echo
echo "== Done: $(du -h "$OUT" | cut -f1)  ->  ${OUT#$HERE/../../../../}"
