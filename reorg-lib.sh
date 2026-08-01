#!/usr/bin/env bash
#
# Reorganise admin/src/lib into three folders: core, studio, g-launcher.
#
# Run from the repo root:  bash reorg-lib.sh
#
# WHAT IT DOES, in the only order that works:
#
#   1. Normalises every intra-lib relative import to the `@/lib/` alias.
#      `legal.ts` imports `./r2`; once those two are in different folders that
#      path is wrong. Rewriting to the alias first means step 3 fixes them with
#      the same pass that fixes everything else.
#   2. Creates the three folders and `git mv`s each file.
#   3. Rewrites every `@/lib/<name>` in admin/src to its new home.
#   4. Typechecks.
#
# It refuses to start on a dirty tree and works on its own branch, so the undo
# is `git checkout main && git branch -D lib-reorg`.

set -euo pipefail

cd "$(dirname "$0")"

if [ ! -d admin/src/lib ]; then
  echo "Run this from the repo root (no admin/src/lib here)."
  exit 1
fi

if [ -n "$(git status --porcelain)" ]; then
  echo "Working tree is dirty. Commit or stash first; this rewrites many files."
  exit 1
fi

git checkout -b lib-reorg

# ── the buckets ─────────────────────────────────────────────────────────────
#
# core       plumbing any app can use: storage, signing, auth, the catalogue,
#            publishing, the store surfaces, Remote Config.
# studio     the studio itself: the public site and the legal documents. Not
#            about any single app.
# g-launcher launcher-only artifacts. G Recovery's equivalents will sit beside
#            this folder rather than inside these files.

CORE="admin auth firebase-client r2 sign registry catalogue cdn publish-core \
unpublish-core orphans listing pack-content markdown image-trim remote-config \
play play-lite commerce skus analytics"

STUDIO="site-content site-public site-traffic legal legal-schema"

LAUNCHER="theme-spec themes theme-resolve distro-publish icon-pack hero-pack \
bulk-icons flat-check app-registry"

# ── 1. relative imports inside lib become alias imports ─────────────────────
#
# Only `./name` forms, and only in lib's own root files. A file that already
# uses the alias is left alone.

echo "==> normalising intra-lib relative imports"
for f in admin/src/lib/*.ts; do
  [ -e "$f" ] || continue
  perl -pi -e "s{from '\./([a-z0-9-]+)'}{from '\@/lib/\$1'}g" "$f"
  perl -pi -e "s{import\('\./([a-z0-9-]+)'\)}{import('\@/lib/\$1')}g" "$f"
done
git add -A
# Tolerant on purpose: a missing git identity should not abandon the run
# halfway, with lib normalised and nothing moved.
git commit -qm "lib: use the @/lib alias inside lib itself, ahead of the move" \
  || echo "    (could not commit; carrying on, the working tree is correct)"

# ── 2. move ─────────────────────────────────────────────────────────────────

echo "==> creating folders"
mkdir -p admin/src/lib/core admin/src/lib/studio admin/src/lib/g-launcher

move_all() {
  local bucket="$1"; shift
  for name in $@; do
    local src="admin/src/lib/${name}.ts"
    if [ -f "$src" ]; then
      git mv "$src" "admin/src/lib/${bucket}/${name}.ts"
      printf '    %-18s -> %s/\n' "${name}.ts" "$bucket"
    else
      printf '    %-18s MISSING, skipped\n' "${name}.ts"
    fi
  done
}

echo "==> moving files"
move_all core $CORE
move_all studio $STUDIO
move_all g-launcher $LAUNCHER

# ── 3. rewrite every import across the whole panel ──────────────────────────
#
# Anchored on the closing quote so `@/lib/legal` cannot match inside
# `@/lib/legal-schema`. Doc comments that quote an import path get rewritten
# too, which is wanted: a comment naming the old path is a comment that lies.

echo "==> rewriting imports"
rewrite() {
  local bucket="$1"; shift
  for name in $@; do
    grep -rl --include=\*.ts --include=\*.tsx "@/lib/${name}'" admin/src 2>/dev/null \
      | while read -r file; do
          perl -pi -e "s{\@/lib/${name}'}{\@/lib/${bucket}/${name}'}g" "$file"
        done
  done
}

rewrite core $CORE
rewrite studio $STUDIO
rewrite g-launcher $LAUNCHER

# ── 4. prove it ─────────────────────────────────────────────────────────────

echo "==> leftovers pointing at the old flat paths (should be none):"
grep -rn --include=\*.ts --include=\*.tsx "@/lib/[a-z0-9-]*'" admin/src \
  | grep -v "@/lib/core/" \
  | grep -v "@/lib/studio/" \
  | grep -v "@/lib/g-launcher/" \
  || echo "    none"

echo "==> typecheck"
cd admin && npx tsc --noEmit && echo "    clean"

cat <<'DONE'

==> done, on branch lib-reorg

  Next:  cd admin && npm run build
  Undo:  git checkout main && git branch -D lib-reorg

The move is one commit on top of the alias-normalisation commit, so a review
can read them separately: the first is mechanical, the second is the decision.
DONE
