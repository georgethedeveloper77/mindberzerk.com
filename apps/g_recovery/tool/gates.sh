#!/usr/bin/env bash
# Every gate, in the order a failure is cheapest to fix.
set -euo pipefail
cd "$(dirname "$0")/.."

./tool/check_appid.sh
./tool/no_constants.sh
./tool/no_snackbars.sh
./tool/no_bare_update.sh
./tool/no_ellipsis.sh

echo "analyze"
flutter analyze --no-fatal-infos

echo "all gates passed"
