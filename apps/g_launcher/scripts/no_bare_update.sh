#!/usr/bin/env bash
#
# Guard against the persistence bug recurring. AsyncNotifier defines update(),
# so a mutator call that says .update( on one of OUR notifiers compiles and
# silently doesn't save. Our notifiers are named edit()/record() for exactly
# this reason — enforce it.
#
# CI + pre-commit, alongside no_snackbars.sh.

set -uo pipefail
cd "$(dirname "$0")/.."

hits=$(grep -rnE '\.notifier\)\s*\.update\(|([^.[:alnum:]_])notifier\.update\(' lib --include='*.dart' || true)

if [[ -n "$hits" ]]; then
  echo "❌ .update( on a prefs/usage notifier — this does not persist:"
  echo "$hits"
  echo
  echo "Use .edit( (PrefsNotifier) or .record( (UsageNotifier)."
  echo "Run ./scripts/fix_update_edit.sh"
  exit 1
fi

echo "✅ No bare .update( calls."
