#!/usr/bin/env bash
#
# "No SnackBars. Ever." — enforced, because a convention that lives only in a
# handoff doc has a half-life of about three weeks.
#
# v2. The first version grepped raw source and so flagged its own documentation:
# branded_message.dart *explains* why it isn't a ScaffoldMessenger, and the word
# appears in a comment. A linter that cries wolf on its own docs gets commented
# out within a day, which is worse than having no linter.
#
# So: strip `//` comments before matching, and exempt the replacement component
# itself.
#
#   ./scripts/no_snackbars.sh

set -uo pipefail
cd "$(dirname "$0")/.."

exempt='lib/design/branded_message.dart'
pattern='(ScaffoldMessenger|SnackBar)'

found=0

while IFS= read -r file; do
  [[ "$file" == "$exempt" ]] && continue

  # Drop full-line comments and doc comments, then everything after a trailing
  # `//`. Crude, and it will not survive a `//` inside a string literal — which
  # is fine, because a URL is not a SnackBar.
  hits=$(sed -e 's|//.*$||' "$file" | grep -nE "$pattern" || true)

  if [[ -n "$hits" ]]; then
    found=1
    while IFS= read -r line; do
      echo "  $file:$line"
    done <<< "$hits"
  fi
done < <(find lib -name '*.dart' -type f | sort)

if [[ $found -eq 1 ]]; then
  cat <<'EOF'

❌ SnackBar / ScaffoldMessenger in real code (comments are ignored).

Use the branded scaffold message — it carries the app logo and reads the active
EffectiveTheme:

    import 'package:g_launcher/design/branded_message.dart';

    context.showMessage('Wallpaper set', tone: MessageTone.success);

EOF
  exit 1
fi

echo "✅ No SnackBars."
