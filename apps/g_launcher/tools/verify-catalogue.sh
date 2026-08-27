#!/usr/bin/env bash
#
# Verify the catalogue: what is LIVE, not what is on this laptop.
#
#   tools/verify-catalogue.sh
#
# Two halves, and the second is the one that matters.
#
# STRUCTURE is checkable: pull every published theme.json and run the audit. It
# proves no two distros resolve to the same product, and it exits non-zero if
# any pair collides.
#
# RENDERING is not. `appDrawer` was clamped to {'grid','tools'} in
# `LayoutResolver` for six passes, so `card`, `whisker`, `cinnamon`, `zorin`,
# `query` and `library` all parsed correctly and then fell back to the shared
# grid. Nothing crashed and nothing logged, because the fallback is a working
# drawer. No script would have caught it: the theme.json was right, the code was
# right, and one allow-list in between was not.
#
# So the second half prints a per-distro checklist of the ONE thing on each that
# a human has to look at. A distro is not complete until someone has.
set -u

CDN="https://cdn.mindberzerk.com/g-launcher"
OUT="${TMPDIR:-/tmp}/catalogue-verify"
HERE="$(cd "$(dirname "$0")" && pwd)"

rm -rf "$OUT" && mkdir -p "$OUT/themes"

echo "── pulling the live index ─────────────────────────────────────────"
if ! curl -sfS "$CDN/index.json" -o "$OUT/index.json"; then
  echo "  could not reach the CDN. Nothing below is meaningful; stopping." >&2
  exit 2
fi

python3 - "$OUT" "$CDN" <<'PY'
import json, os, subprocess, sys
out, cdn = sys.argv[1], sys.argv[2]
packs = json.load(open(f'{out}/index.json'))['packs']
themes = [p for p in packs if p['packType'] == 'theme']
print(f'  {len(themes)} themes published')
bad = []
for p in themes:
    dst = f"{out}/themes/{p['packId']}.json"
    r = subprocess.run(['curl', '-sfS', f"{cdn}/{p['path']}/theme.json", '-o', dst])
    if r.returncode != 0:
        bad.append(p['packId'])
if bad:
    print('  FAILED to fetch: ' + ', '.join(bad))
PY

echo
"$HERE/audit-distros.py" "$OUT/themes"
STATUS=$?

echo
echo "── ON DEVICE: the one thing to look at per distro ─────────────────"
echo "   Structure is proved above. These are the things only eyes prove."
echo

python3 - "$OUT" <<'PY'
import json, glob, os, sys
out = sys.argv[1]

# The drawer each distro should be showing, and what it looks like. Five of
# these have NEVER been on screen: `appDrawer` was clamped in LayoutResolver, so
# every value past `tools` resolved to the shared grid.
LOOK = {
    'grid':     'the shared paged grid',
    'tools':    'a numbered rail down the left, thirteen shelves',
    'card':     'a CARD dropping from Applications, never full screen',
    'whisker':  'a narrow popup in the BOTTOM-LEFT corner, category strip at its foot',
    'cinnamon': 'THREE columns: favourites, categories, apps',
    'zorin':    'a pinned grid ABOVE a rule, everything else listed below',
    'query':    'a LINE at the top, ranked results, nothing else',
    'library':  'category BUBBLES, two across, scrolling',
}
# Values that never rendered before the LayoutResolver fix.
NEVER = {'card', 'whisker', 'cinnamon', 'zorin', 'query', 'library'}

rows = []
for f in sorted(glob.glob(f'{out}/themes/*.json')):
    try:
        d = json.load(open(f))
    except Exception:
        continue
    if 'shell' not in d or 'layout' not in d:
        continue
    L = d['layout']
    drawer = L.get('appDrawer', 'grid')
    # The shared grid routes by shell, so name what will actually appear.
    if drawer == 'grid':
        if d['shell'] == 'plasma':
            look = 'Kickoff: a rail beside a list'
        elif d['shell'] == 'tiling':
            look = ('dmenu: one line across the TOP'
                    if L.get('tilingLauncher') == 'dmenu'
                    else 'rofi: a centred card with icons')
        elif d['shell'] == 'tui':
            look = 'the prompt IS the launcher'
        else:
            look = LOOK['grid']
    else:
        look = LOOK.get(drawer, drawer)
    rows.append((d['name'], drawer, look, drawer in NEVER))

w = max(len(r[0]) for r in rows)
for name, drawer, look, never in sorted(rows):
    flag = '  <-- NEVER RENDERED BEFORE' if never else ''
    print(f'  [ ] {name.ljust(w)}  {look}{flag}')

print()
print('  Also worth one look each:')
print('   [ ] Deepin        apps are the FIRST swipe, and the dock must not swell')
print('   [ ] Fedora        NO dock on the desktop; the dash appears in Activities')
print('   [ ] Garuda        top bar, ONE dock at the foot, magnifying')
print('   [ ] KDE           bottom panel and NO dock at all')
print('   [ ] Arch          six gapless tiles, not a spaced grid')
PY

echo
if [ "$STATUS" -eq 0 ]; then
  echo "STRUCTURE: pass. No two distros resolve to the same product."
  echo "COMPLETE:  not until every box above is ticked by a person."
else
  echo "STRUCTURE: FAIL. Two or more distros are identical; see COLLISIONS."
fi
exit "$STATUS"
