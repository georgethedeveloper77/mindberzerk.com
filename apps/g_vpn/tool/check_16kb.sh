#!/usr/bin/env bash
# Checks a release build for Play's 16 KB page-size rule: every native
# library's LOAD segments must be aligned to 16 KB (2**14) or more.
#
#   bash tool/check_16kb.sh                 # builds the release APK, then checks it
#   bash tool/check_16kb.sh path/to/app.apk # checks an existing APK
#
# Run from apps/g_vpn. Exits non-zero if any library fails.
set -euo pipefail
SDK="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
APK="${1:-}"

if [[ -z "$APK" ]]; then
  flutter build apk --release --dart-define-from-file=env/dev.json
  APK="build/app/outputs/flutter-apk/app-release.apk"
fi
[[ -f "$APK" ]] || { echo "No APK at $APK"; exit 1; }

OBJDUMP=$(ls "$SDK"/ndk/*/toolchains/llvm/prebuilt/*/bin/llvm-objdump 2>/dev/null | sort -V | tail -1)
[[ -n "$OBJDUMP" ]] || { echo "llvm-objdump not found under $SDK/ndk"; exit 1; }

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
unzip -q -o "$APK" 'lib/*' -d "$TMP" || { echo "No native libraries in $APK"; exit 0; }

bad=0
for abi in arm64-v8a x86_64; do
  [[ -d "$TMP/lib/$abi" ]] || continue
  echo "== $abi"
  for so in "$TMP/lib/$abi"/*.so; do
    # Smallest alignment among the LOAD segments decides it.
    worst=$("$OBJDUMP" -p "$so" | awk '/LOAD/{print $NF}' | sed 's/2\*\*//' | sort -n | head -1)
    status=OK
    if [[ -z "$worst" || "$worst" -lt 14 ]]; then status=FAIL; bad=1; fi
    printf '   %-6s 2**%-3s %s\n' "$status" "${worst:-?}" "$(basename "$so")"
  done
done

echo
if [[ $bad -eq 0 ]]; then
  echo "All native libraries are 16 KB aligned."
else
  echo "Some libraries are NOT 16 KB aligned (FAIL above): update or rebuild them before release."
  exit 1
fi
