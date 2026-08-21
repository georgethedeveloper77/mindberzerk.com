#!/usr/bin/env bash
#
# verify-library.sh — is the App Library actually wired, end to end?
#
#   ./tools/verify-library.sh
#
# WHY THIS EXISTS.
#
# The library drawer is eight edits across seven files plus a republish, and a
# single missing one produces the same symptom as all eight missing: a drawer
# that looks exactly like it always did, with no error anywhere. That failure
# mode has already cost several rounds of guessing.
#
# So this asserts each link separately and says which one is open. Every check
# greps for a marker that only exists if that specific edit landed; none of them
# infer anything from another.
#
# Run from the g_launcher root.

set -uo pipefail

PASS=0
FAIL=0

ok()   { printf '  \033[32mOK\033[0m    %s\n' "$1"; PASS=$((PASS+1)); }
bad()  { printf '  \033[31mMISS\033[0m  %s\n' "$1"; printf '        %s\n' "$2"; FAIL=$((FAIL+1)); }
head_() { printf '\n\033[1m%s\033[0m\n' "$1"; }

# grep_file <path> <pattern> <label> <what to do>
grep_file() {
  local path="$1" pat="$2" label="$3" fix="$4"
  if [[ ! -f "$path" ]]; then
    bad "$label" "no such file: $path"
    return
  fi
  if grep -q -- "$pat" "$path"; then ok "$label"; else bad "$label" "$fix"; fi
}

head_ "1. The value is accepted by the engine"

grep_file lib/engine/theme_spec.dart \
  "'library' => 'library'" \
  "theme_spec parses drawerGrouping: library" \
  "apply aqua_library_drawer.zip. Without this the key is dropped at parse and the theme has no opinion."

grep_file lib/engine/layout_resolver.dart \
  "'none', 'az', 'library'" \
  "layout_resolver allows library" \
  "apply aqua_library_drawer.zip. Without this the resolver rejects the value and falls back to the default."

head_ "2. The folders are built"

grep_file lib/features/drawer/drawer_items.dart \
  "kCategoryFolderPrefix" \
  "drawer_items builds category folders" \
  "apply aqua_library_drawer.zip."

# ORDER MATTERS, not just presence. The library block has to run BEFORE the
# custom early-return, because custom is the default nobody sets and it returns
# the slot grid without ever reaching the bottom of the function.
if [[ -f lib/features/drawer/drawer_items.dart ]]; then
  lib_line=$(grep -n "drawerGrouping == 'library'" lib/features/drawer/drawer_items.dart | head -1 | cut -d: -f1)
  cus_line=$(grep -n "if (mode == 'custom')" lib/features/drawer/drawer_items.dart | head -1 | cut -d: -f1)
  if [[ -n "${lib_line:-}" && -n "${cus_line:-}" ]]; then
    if (( lib_line < cus_line )); then
      ok "library branch runs before the custom early-return (line $lib_line < $cus_line)"
    else
      bad "library branch runs before the custom early-return" \
          "it is at line $lib_line, after custom at $cus_line. apply library_before_custom.zip."
    fi
  else
    bad "library branch runs before the custom early-return" \
        "could not find both markers. apply aqua_library_drawer.zip then library_before_custom.zip."
  fi
fi

head_ "3. The drawer body actually renders them"

# THE ONE THAT WAS SILENTLY WRONG. The custom branch renders
# drawerCustomGridProvider directly and never touches drawerItemsProvider, so
# folders were being built and handed to a provider nobody asked for.
grep_file lib/features/drawer/app_drawer.dart \
  "theme.drawerGrouping == 'library'" \
  "app_drawer redirects away from the custom grid" \
  "apply library_reaches_renderer.zip. THIS IS THE ONE that makes the drawer look unchanged with no error."

head_ "4. Generated folders are read-only"

grep_file lib/features/drawer/folder_overlay.dart \
  "_readOnly" \
  "folder_overlay hides edits on category folders" \
  "apply aqua_library_drawer.zip. Without it, rename and Ungroup appear and silently do nothing."

head_ "5. Settings"

grep_file lib/features/settings/sections/apps_section.dart \
  "'library': 'Library'" \
  "apps_section offers the Library option" \
  "apply aqua_library_drawer.zip."

grep_file lib/features/settings/sections/apps_section.dart \
  "enabled: theme.drawerGrouping != 'library'" \
  "apps_section greys Drawer scrolls under library" \
  "apply library_settings_greying.zip."

grep_file lib/design/setting_previews.dart \
  "this.enabled = true" \
  "PreviewChoice supports a disabled state" \
  "apply library_settings_greying.zip. apps_section will not compile without it."

head_ "6. The distro asks for it"

# The LIVE pack, not the local draft: the device installs what is published.
BASE="${CDN_BASE_URL:-https://cdn.mindberzerk.com}"
IDX="$BASE/g-launcher/index.json"

path=$(curl -fsS "$IDX" 2>/dev/null \
  | python3 -c "
import json,sys
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(1)
for p in d.get('packs', []):
    if p.get('packId') == 'elementary-os-8-theme':
        print(p.get('path',''))
        break
" 2>/dev/null)

if [[ -z "${path:-}" ]]; then
  bad "elementary is in the signed index" \
      "could not read $IDX, or no elementary-os-8-theme entry in it."
else
  ok "elementary is in the signed index at $path"

  spec="$BASE/g-launcher/$path/theme.json"
  body=$(curl -fsS "$spec" 2>/dev/null)
  if [[ -z "${body:-}" ]]; then
    bad "the published theme.json is readable" "could not fetch $spec"
  else
    ok "the published theme.json is readable"
    printf '%s' "$body" | python3 -c "
import json,sys
d = json.load(sys.stdin)
lay = d.get('layout', {})
want = {
    'drawerGrouping': 'library',
    'drawerScrollStyle': 'vertical',
}
for k, v in want.items():
    got = lay.get(k)
    if got == v:
        print('  \033[32mOK\033[0m    published layout.%s = %r' % (k, got))
    else:
        print('  \033[31mMISS\033[0m  published layout.%s is %r, want %r' % (k, got, v))
        print('        republish elementary with the full theme.json.')

dock = d.get('palette', {}).get('dock')
if isinstance(dock, str) and dock.upper().startswith('#1A'):
    print('  \033[32mOK\033[0m    published palette.dock = %s (glass)' % dock)
else:
    print('  \033[31mMISS\033[0m  published palette.dock is %r' % dock)
    print('        a high alpha covers the blur. #1AFFFFFF is the glass value.')
"
  fi
fi

head_ "Result"
printf '  %d local checks passed, %d failed.\n' "$PASS" "$FAIL"
printf '  The CDN checks above print their own lines and are not counted here.\n\n'

if (( FAIL > 0 )); then
  printf '  Fix the MISS lines, then COLD BUILD. Hot restart has silently\n'
  printf '  served stale code twice in this feature already.\n\n'
  exit 1
fi

printf '  Every local edit is in place. If the drawer still shows pages after a\n'
printf '  cold build and a republish, the fault is downstream of all of this and\n'
printf '  the next step is `flutter logs` while opening the drawer.\n\n'
