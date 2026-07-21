#!/usr/bin/env bash
#
# Cleans up three layout mistakes, two of them mine.
#
#  1. admin/admin/  — create-next-app was run from inside admin/ rather than
#     from the repo root, so the project nested one level down.
#  2. lib/features/{drawer,settings}/ — a LITERAL directory with braces in its
#     name, from a brace expansion that ran under sh instead of bash. The same
#     mistake already left a `{apps,icons}` directory in the Kotlin tree.
#  3. Stray planning docs at the repo root.
#
# Idempotent: safe to run twice.
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."
ROOT="$(pwd)"
echo "repo root: $ROOT"

# ── 1. flatten admin/admin ───────────────────────────────────────────────────
if [ -d "admin/admin" ]; then
  echo "==> flattening admin/admin"

  # The nested project is the real one; the outer admin/ holds only the files
  # I shipped plus a node_modules from a stray install. Keep both sets: move
  # the scaffold up, then re-apply the shipped files over it.
  mkdir -p /tmp/admin-shipped
  for f in apphosting.yaml README.md .env.example; do
    [ -e "admin/$f" ] && cp "admin/$f" /tmp/admin-shipped/ || true
  done
  [ -d "admin/src" ] && cp -R admin/src /tmp/admin-shipped/ || true

  # Discard the outer shell entirely, including the node_modules that was
  # installed into the wrong directory.
  rm -rf admin/node_modules admin/package.json admin/package-lock.json
  rm -rf admin/src admin/apphosting.yaml admin/README.md admin/.env.example

  # Promote the scaffold.
  shopt -s dotglob
  mv admin/admin/* admin/
  shopt -u dotglob
  rmdir admin/admin

  # Re-apply the shipped files, merging src rather than replacing it so the
  # scaffold's app/layout.tsx and app/page.tsx survive.
  cp -R /tmp/admin-shipped/src/. admin/src/ 2>/dev/null || true
  for f in apphosting.yaml README.md .env.example; do
    [ -e "/tmp/admin-shipped/$f" ] && cp "/tmp/admin-shipped/$f" "admin/$f" || true
  done
  rm -rf /tmp/admin-shipped

  echo "    done. Reinstall inside admin/:"
  echo "      cd admin && npm i && npm i firebase firebase-admin @aws-sdk/client-s3 server-only"
else
  echo "==> admin/admin not present, nothing to flatten"
fi

# ── 2. literal brace directories ─────────────────────────────────────────────
# `mkdir -p a/{b,c}` under sh creates a directory NAMED "{b,c}". Under zsh and
# bash it expands. Any script that might run under sh should spell the paths.
echo "==> removing literal brace directories"
find . -depth -type d -name '*{*}*' -not -path './*/node_modules/*' -print | while read -r d; do
  if [ -z "$(find "$d" -type f -print -quit)" ]; then
    echo "    rm $d"
    rmdir "$d" 2>/dev/null || rm -rf "$d"
  else
    echo "    SKIPPED (not empty, look at it yourself): $d"
  fi
done

# ── 3. stray root docs ───────────────────────────────────────────────────────
echo "==> filing planning docs under docs/"
mkdir -p docs
for f in INTEGRATION.md PLAY_PRODUCTS.md README_CLEANUP.md MONETIZATION.md; do
  [ -e "$f" ] && mv "$f" "docs/$f" && echo "    docs/$f" || true
done

echo
echo "Remaining checks:"
echo "  find . -type d -name '*{*}*' -not -path '*/node_modules/*'   # should be empty"
echo "  ls admin                                                      # should show package.json, src, apphosting.yaml"
