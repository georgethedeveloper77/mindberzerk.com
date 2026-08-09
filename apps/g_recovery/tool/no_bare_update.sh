#!/usr/bin/env bash
# A bare .update() on a notifier hides what changed at the call site and makes
# every state transition unreviewable. Notifiers expose named intent methods
# instead: setAccent, select, record.
set -euo pipefail
cd "$(dirname "$0")/.."

hits=$(grep -rn --include='*.dart' -E '\.notifier\)\.update\(|^\s*state\s*=\s*state\.copyWith' lib/ \
  | grep -v '// no_bare_update: allow' || true)

if [ -n "$hits" ]; then
  echo "no_bare_update FAILED"
  echo "$hits"
  exit 1
fi
echo "no_bare_update  ok"
