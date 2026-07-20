#!/usr/bin/env bash
#
# Verifies assets/fonts/ is complete.
#
# The fonts are now COMMITTED (see assets/fonts/). They came from
# github.com/google/fonts/ufl/ubuntu + /ufl/ubuntumono — the Ubuntu Font Licence
# 1.0 family, Copyright 2011 Canonical Ltd. This script no longer downloads
# anything; it just fails loudly if a file goes missing, because the failure mode
# it protects against is silent: a missing TTF does not error, Flutter simply
# renders Roboto and your "faithful Ubuntu theme" ships in Google's typeface.

set -euo pipefail
cd "$(dirname "$0")/.."

required=(
  Ubuntu-Regular.ttf
  Ubuntu-Italic.ttf
  Ubuntu-Medium.ttf
  Ubuntu-Bold.ttf
  UbuntuMono-Regular.ttf
  UbuntuMono-Bold.ttf
  UBUNTU-FONT-LICENCE-1.0.txt
)

missing=0
for f in "${required[@]}"; do
  if [[ ! -f "assets/fonts/$f" ]]; then
    echo "missing: assets/fonts/$f"
    missing=1
  fi
done

if [[ $missing -eq 1 ]]; then
  echo
  echo "Re-fetch from https://github.com/google/fonts/tree/main/ufl/ubuntu"
  exit 1
fi

echo "✅ assets/fonts/ complete — ${#required[@]} files."
