#!/usr/bin/env bash
# SnackBar is banned. Every transient message goes through GMessenger, which
# carries the brand mark, clears the bottom nav, and replaces rather than
# silently drops a queued message.
#
# The one permitted mention is the SnackBarThemeData in app_theme.dart, which
# exists only to contain a stray SnackBar thrown by a third party package.
set -euo pipefail
cd "$(dirname "$0")/.."

# Matches real usage only: a constructor call or a ScaffoldMessenger lookup.
# The bare word appears in doc comments explaining the ban and must not fail.
hits=$(grep -rn --include='*.dart' -E 'ScaffoldMessenger|SnackBar\(|showSnackBar' lib/ \
  | grep -v 'lib/app/theme/app_theme.dart' \
  | grep -v '// no_snackbars: allow' || true)

if [ -n "$hits" ]; then
  echo "no_snackbars FAILED"
  echo "$hits"
  exit 1
fi
echo "no_snackbars    ok"
