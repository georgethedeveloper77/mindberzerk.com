#!/usr/bin/env bash
#
# verify-previews.sh — is the storefront preview chain actually wired?
#
#   ./tools/verify-previews.sh
#
# Same job as verify-library.sh and for the same reason: this feature spans two
# repos, a Pigeon regenerate, a Firebase deploy and a republish, and a single
# missing link produces one symptom, a flat card, with no error anywhere.
#
# It checks the DEVICE side against your working tree, and the PUBLISHED side
# against the live index. Those are different questions and the second one is
# the one that has been failing.
#
# Run from the g_launcher root. Point ADMIN at the admin repo if it is not
# beside this one.

set -uo pipefail

ADMIN="${ADMIN:-../admin}"
PASS=0
FAIL=0

ok()   { printf '  \033[32mOK\033[0m    %s\n' "$1"; PASS=$((PASS+1)); }
bad()  { printf '  \033[31mMISS\033[0m  %s\n' "$1"; printf '        %s\n' "$2"; FAIL=$((FAIL+1)); }
head_() { printf '\n\033[1m%s\033[0m\n' "$1"; }

grep_file() {
  local path="$1" pat="$2" label="$3" fix="$4"
  if [[ ! -f "$path" ]]; then bad "$label" "no such file: $path"; return; fi
  if grep -q -- "$pat" "$path"; then ok "$label"; else bad "$label" "$fix"; fi
}

head_ "1. The schema"

grep_file pigeons/pack_api.dart \
  "previewShell" \
  "PackInfo declares the preview fields" \
  "apply store_previews_part2.zip."

grep_file pigeons/pack_api.dart \
  "this.previewShell" \
  "PackInfo's CONSTRUCTOR takes them" \
  "the fields exist but are not in the constructor. That is a compile error, not a silent one."

# THE REGENERATE. Editing the schema does nothing until pigeon has run, and the
# generated file is what the app actually imports.
grep_file lib/platform/pack_api.g.dart \
  "previewShell" \
  "the generated bindings are current" \
  "run: dart run pigeon --input pigeons/pack_api.dart"

head_ "2. Native"

grep_file android/app/src/main/kotlin/com/mindhunter/g_launcher/cdn/CdnIndex.kt \
  "previewStr" \
  "CdnIndex parses the preview block" \
  "apply store_previews_part2.zip."

grep_file android/app/src/main/kotlin/com/mindhunter/g_launcher/cdn/PackHostApiImpl.kt \
  "previewShell = p.previewShell" \
  "the bridge passes it through" \
  "apply store_previews_part2.zip. Without this the parse is thrown away at the boundary."

head_ "3. The card"

grep_file lib/features/themes/theme_catalog.dart \
  "_previewFromPack" \
  "the card builds a preview from the pack" \
  "apply store_previews_part2.zip."

grep_file lib/features/themes/theme_catalog.dart \
  "PreviewLayout.dockMagnified" \
  "shells map onto REAL layout arms" \
  "an earlier draft used arms named gnome/plasma/aqua, which do not exist."

head_ "4. The panel"

if [[ -d "$ADMIN" ]]; then
  grep_file "$ADMIN/src/lib/core/sign.ts" \
    "IndexPreview" \
    "IndexPack can carry a preview" \
    "apply store_previews_panel.zip."

  grep_file "$ADMIN/src/lib/g-launcher/distro-publish.ts" \
    "preview: {" \
    "publish derives one from the spec" \
    "apply store_previews_panel.zip."

  # DEPLOYED, not just present. `publishDistroAction` is a server action, so it
  # runs whatever Firebase App Hosting built, never your working tree. This is
  # the link that has actually been failing.
  if git -C "$ADMIN" diff --quiet -- src/lib 2>/dev/null &&
     git -C "$ADMIN" diff --cached --quiet -- src/lib 2>/dev/null; then
    ok "admin src/lib is committed"
  else
    bad "admin src/lib is committed" \
        "uncommitted changes under src/lib. App Hosting builds from the pushed commit, so the panel is still running the old bundle and every republish will omit the preview."
  fi
else
  bad "the admin repo was found" \
      "looked in '$ADMIN'. Set ADMIN=/path/to/admin and run again."
fi

head_ "5. What is actually published"

BASE="${CDN_BASE_URL:-https://cdn.mindberzerk.com}"

curl -fsS "$BASE/g-launcher/index.json" 2>/dev/null | python3 -c "
import json, sys

try:
    d = json.load(sys.stdin)
except Exception:
    print('  \033[31mMISS\033[0m  the live index is readable')
    print('        could not fetch or parse it.')
    sys.exit(0)

packs = [p for p in d.get('packs', []) if p.get('packType') == 'theme']
if not packs:
    print('  \033[31mMISS\033[0m  the index advertises any themes')
    sys.exit(0)

withp = [p for p in packs if p.get('preview')]
print('  %s  %d of %d published themes carry a preview' % (
    '\033[32mOK\033[0m  ' if withp else '\033[31mMISS\033[0m',
    len(withp), len(packs)))

if not withp:
    print('        Nothing has been republished since the panel changed, or the')
    print('        panel is not deployed. The preview only lands on republish:')
    print('        existing entries are never rewritten.')

for p in packs:
    pv = p.get('preview')
    if not pv:
        print('        - %s v%s: no preview, card stays flat'
              % (p['packId'], p.get('version')))
        continue
    missing = [k for k in
               ('shell', 'bgTop', 'bgBottom', 'bar', 'dock', 'accent')
               if not pv.get(k)]
    if missing:
        print('        - %s: preview present but missing %s'
              % (p['packId'], ', '.join(missing)))
    else:
        print('        - %s: %s, %s' % (p['packId'], pv['shell'], pv['accent']))
" 2>/dev/null || printf '  \033[31mMISS\033[0m  the live index is readable\n        no route to %s\n' "$BASE"

head_ "Result"
printf '  %d local checks passed, %d failed.\n' "$PASS" "$FAIL"
printf '  Section 5 prints its own lines and is not counted.\n\n'

if (( FAIL > 0 )); then
  printf '  Fix the MISS lines. If they are all in section 4, the code is right\n'
  printf '  and the panel simply is not running it yet.\n\n'
  exit 1
fi

printf '  Every link is in place. Any theme still showing a flat card just needs\n'
printf '  republishing: the preview is written when a pack is published, and\n'
printf '  entries already in the index are never rewritten.\n\n'
