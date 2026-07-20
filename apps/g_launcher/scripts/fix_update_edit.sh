#!/usr/bin/env bash
#
# THE PERSISTENCE BUG, fixed in place. v2 — perl, because v1 used sed -E syntax
# that BSD sed (macOS) parses differently and it died with "parentheses not
# balanced" before touching anything. perl -pi behaves identically on macOS and
# Linux, which is the whole reason it's used here.
#
# What it fixes: PrefsNotifier's mutator is `edit()`, but call sites saying
# `.update(` still COMPILE — they resolve to the inherited AsyncNotifier.update(),
# which awaits state.future first (the settings lag) and never writes to disk
# (every preference lost on restart).
#
#   ./scripts/fix_update_edit.sh

set -euo pipefail
cd "$(dirname "$0")/.."

targets=$(grep -rlE '\.notifier\)[[:space:]]*\.update\(|(^|[^.[:alnum:]_])notifier\.update\(' lib --include='*.dart' || true)

if [[ -z "$targets" ]]; then
  echo "✅ No stray .update( calls on prefs notifiers."
  exit 0
fi

for f in $targets; do
  perl -pi -e 's/\.notifier\)(\s*)\.update\(/.notifier)$1.edit(/g; s/([^.\w])notifier\.update\(/${1}notifier.edit(/g' "$f"
  echo "fixed: $f"
done

echo
echo "flutter analyze is the real confirmation — a mis-rewrite cannot compile,"
echo "because only PrefsNotifier has edit()."
