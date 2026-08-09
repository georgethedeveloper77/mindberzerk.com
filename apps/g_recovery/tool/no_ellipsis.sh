#!/usr/bin/env bash
# No em dashes and no ellipsis characters in authored copy or comments.
# TextOverflow.ellipsis is runtime truncation and stays.
set -euo pipefail
cd "$(dirname "$0")/.."

hits=$(grep -rn --include='*.dart' -e $'\u2014' -e $'\u2026' lib/ || true)

if [ -n "$hits" ]; then
  echo "no_ellipsis FAILED"
  echo "$hits"
  exit 1
fi
echo "no_ellipsis     ok"
