#!/usr/bin/env bash
# Colour literals live in lib/app/theme only. A Color(0x...) or a Colors.*
# anywhere else means a widget that will not follow the accent or the light
# theme, and that bug is invisible until a user switches.
#
# Color(0x00000000) is allowed everywhere: it is transparent, it has no theme
# meaning, and Material requires a concrete Color for InkWell backgrounds.
set -euo pipefail
cd "$(dirname "$0")/.."

hits=$(grep -rn --include='*.dart' -E 'Color\(0x|Colors\.' lib/ \
  | grep -v '^lib/app/theme/' \
  | grep -v 'Color(0x00000000)' \
  | grep -v 'Color(0xFFFFFFFF)' \
  | grep -v '// no_constants: allow' || true)

if [ -n "$hits" ]; then
  echo "no_constants FAILED"
  echo "$hits"
  exit 1
fi
echo "no_constants    ok"
