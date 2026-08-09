#!/usr/bin/env bash
set -euo pipefail

# Guards the three things that cannot be wrong at upload time:
#   1. applicationId and namespace both read com.mindhunter.g_recovery
#   2. versionCode exceeds the one live on Play
#   3. release builds are not signing with debug keys
#
# LIVE_VERSION_CODE is read from Play Console, never guessed.
# Raise it whenever a new build goes live on production.

EXPECTED_APP_ID="com.mindhunter.g_recovery"
LIVE_VERSION_CODE=6

root="$(cd "$(dirname "$0")/.." && pwd)"
gradle="$root/android/app/build.gradle.kts"
pubspec="$root/pubspec.yaml"
keyprops="$root/android/key.properties"

status=0
pass() { printf '  ok    %s\n' "$1"; }
fail() { printf '  FAIL  %s\n' "$1"; status=1; }

echo "check_appid"

for f in "$gradle" "$pubspec"; do
  if [ ! -f "$f" ]; then
    fail "missing $f"
    exit 1
  fi
done

namespace="$(sed -nE 's/^[[:space:]]*namespace[[:space:]]*=[[:space:]]*"(.*)".*/\1/p' "$gradle" | head -1)"
appid="$(sed -nE 's/^[[:space:]]*applicationId[[:space:]]*=[[:space:]]*"(.*)".*/\1/p' "$gradle" | head -1)"
version="$(sed -nE 's/^version:[[:space:]]*(.*)$/\1/p' "$pubspec" | head -1)"
code="${version##*+}"

if [ "$namespace" = "$EXPECTED_APP_ID" ]; then
  pass "namespace $namespace"
else
  fail "namespace is '$namespace', expected $EXPECTED_APP_ID"
fi

if [ "$appid" = "$EXPECTED_APP_ID" ]; then
  pass "applicationId $appid"
else
  fail "applicationId is '$appid', expected $EXPECTED_APP_ID"
fi

case "$code" in
  ''|*[!0-9]*)
    fail "versionCode '$code' is not an integer, pubspec version is '$version'"
    ;;
  *)
    if [ "$code" -gt "$LIVE_VERSION_CODE" ]; then
      pass "versionCode $code exceeds live $LIVE_VERSION_CODE"
    else
      fail "versionCode $code must exceed live $LIVE_VERSION_CODE, Play will reject it"
    fi
    ;;
esac

if [ -f "$keyprops" ]; then
  missing=""
  for k in storeFile storePassword keyAlias keyPassword; do
    grep -qE "^[[:space:]]*$k[[:space:]]*=" "$keyprops" || missing="$missing $k"
  done
  if [ -z "$missing" ]; then
    pass "key.properties complete"
  else
    fail "key.properties missing:$missing"
  fi
else
  fail "android/key.properties not found, release would sign with debug keys"
fi

if grep -q 'signingConfig = signingConfigs.getByName("debug")' "$gradle"; then
  fail "release build type is hardwired to debug signing"
else
  pass "release signing is not hardwired to debug"
fi

exit "$status"
