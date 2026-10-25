#!/usr/bin/env bash
# Lists on-screen text still written in code instead of lib/i18n/en.json.
#
#   bash tool/untranslated.sh          # every file
#   bash tool/untranslated.sh tools    # one folder under lib/
#
# Matches text in the places users see it (Text, titles, labels, hints,
# tooltips, sheet sections). Run from apps/g_vpn; empty output means done.
set -euo pipefail
DIR="lib/${1:-}"
grep -rnE "(Text\(|title: |subtitle: |label: |labelText: |hintText: |tooltip: |error: |SheetSection(\.text)?\(|ScanChip\(|=> )('[A-Z][^']*[a-z ][^']*'|\"[A-Z][^\"]*[a-z ][^\"]*\")" "$DIR" \
  --include='*.dart' \
  | grep -v "lib/i18n/" \
  | grep -v "/// " \
  | sed -E 's/^([^:]+):([0-9]+):[[:space:]]*/\1:\2  /' \
  || echo "Nothing left to translate in $DIR"
