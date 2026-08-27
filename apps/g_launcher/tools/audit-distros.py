#!/usr/bin/env python3
"""Audit every distro's structure and report where two of them collide.

Usage
-----
    tools/audit-distros.py themes/                 # a directory of theme.json
    tools/audit-distros.py a.json b.json c.json    # or a list of them

Pull the live set first:

    cd ~/Downloads && rm -rf themes && mkdir themes && \\
    curl -sfS https://cdn.mindberzerk.com/g-launcher/index.json -o index.json && \\
    python3 -c "
    import json,subprocess
    for x in json.load(open('index.json'))['packs']:
        if x['packType']!='theme': continue
        subprocess.run(['curl','-sfS',
            'https://cdn.mindberzerk.com/g-launcher/'+x['path']+'/theme.json',
            '-o','themes/%s.json'%x['packId']])
    "

WHAT IT CHECKS, AND WHY ONLY THIS
---------------------------------
Only fields with NO prefs arm in `LayoutResolver`. That is the whole rule this
catalogue runs on: a field the user can change in Settings cannot be what makes
one distro different from another, because any buyer can reproduce it on any
distro in four taps.

So palette, fonts, corner radius, icon treatment, drawer motion and drawer
grouping are all deliberately absent from the fingerprint. They are reported
separately, as colour, because they matter to how a distro LOOKS and not to
whether it is a different product.

Two distros with the same fingerprint are the same product wearing different
paint. That is the thing this script exists to catch before a buyer does.

Keeping it in step: when a new no-prefs-arm field lands in `ThemeLayout`, add it
to FIELDS below. A field missing here is a difference the audit cannot see, and
an audit that quietly under-reports is worse than none.
"""

import json
import os
import sys
from itertools import combinations

# ── The fingerprint: field name -> (json path, default when absent) ──────────
#
# The default has to match `LayoutResolver`'s, or a distro that authors nothing
# will look different from one that authored the default explicitly, when on the
# device they are identical.
#
# ─── THE TEST FOR MEMBERSHIP IS ONE GREP ────────────────────────────────────
#
# A field belongs here only if `LayoutResolver.resolve` reads it WITHOUT
# consulting prefs. Two that did not pass and were here anyway:
#
#   * `dock` resolves through `prefs.dockSide`.
#   * `panels` resolves through `prefs.panelModules`.
#
# Both are reported below instead. Getting this wrong flatters the catalogue:
# pairs that "differed" on a settings row are pairs a buyer can make identical
# in four taps, which is the entire thing this script exists to measure.
FIELDS = [
    ('shell',        ('shell',),                  None),
    ('chrome',       ('chromeFamily',),           'auto'),
    ('drawer',       ('layout', 'appDrawer'),     'grid'),
    ('apps',         ('layout', 'appsSurface'),   'overlay'),
    ('home',         ('layout', 'homeLayout'),    'grid'),
    ('deskIcons',    ('layout', 'desktopIcons'),  False),
    ('dockStyle',    ('layout', 'dockStyle'),     'magnified'),
    ('dockReveal',   ('layout', 'dockReveal'),    'always'),
    ('launcher',     ('layout', 'tilingLauncher'), 'rofi'),
    ('kickoffRail',  ('layout', 'kickoffRail'),   'tabs'),
    ('panelEdit',    ('layout', 'panelEdit'),     False),
    ('wsAxis',       ('layout', 'workspaceAxis'), 'vertical'),
    ('workspaces',   ('layout', 'workspaces'),    3),
]

# Reported but NOT part of the fingerprint. Every one of these has a prefs arm,
# so a buyer can set it on any distro; they describe the look, not the product.
LOOK = [
    # `dock` resolves as `prefs.dockSide` first, so the position is a setting
    # and a distro's choice is only a default. It was in the fingerprint and
    # should not have been: several pairs in the fourteen-distro run "differed"
    # on it, which is a difference any buyer erases from a Settings row.
    ('dockSide',  ('layout', 'dock'),           'bottom'),
    ('accent',    ('palette', 'accent'),        None),
    ('treatment', ('icons', 'treatment'),       None),
    ('radius',    ('icons', 'cornerRadius'),    None),
    ('font',      ('typography', 'display'),    None),
]


def dig(d, path, default=None):
    for k in path:
        if not isinstance(d, dict) or k not in d:
            return default
        d = d[k]
    return d if d is not None else default


def panel_of(t):
    """Whichever panel this distro authored, or how the bar is otherwise decided.

    Reported, NOT fingerprinted. `LayoutResolver` resolves `panels` from
    `prefs.panelModules` first, so a user in panel-edit mode can rebuild the bar
    and a distro's modules are a default like any other. Two distros whose only
    difference is their panel are two distros a buyer can make identical.
    """
    panels = dig(t, ('layout', 'panels'))
    if isinstance(panels, list) and panels:
        # Every side, not just top. Plasma's panel is at the BOTTOM, so a
        # top-only report said "(no top panel)" for three distros that had
        # authored one, which reads as nothing authored.
        return ' | '.join(
            f"{p.get('side', 'top')}: "
            f"{','.join(p.get('modules', [])) or '(empty)'}"
            for p in panels
        )
    # `ThemeSpec._panels` synthesises one from the legacy flag, so an absent
    # `panels` is not the same as an absent bar.
    return 'legacy topBar' if dig(t, ('layout', 'topBar')) else 'none'


def surfaces_of(t):
    skins = dig(t, ('desklets', 'skins'), {}) or {}
    return ','.join(sorted({v.get('surface', '?') for v in skins.values()})) or '-'


def load(paths):
    """Expand directories, and say plainly when a path is not there.

    A missing directory used to surface as a JSON parse error on the directory
    name itself, which reads as a corrupt theme rather than as a typo. The three
    cases below are the three that actually happen, and each gets its own
    sentence.
    """
    out = []
    for p in paths:
        if not os.path.exists(p):
            print(f'  no such path: {p}', file=sys.stderr)
            continue
        if os.path.isdir(p):
            found = [os.path.join(p, f) for f in sorted(os.listdir(p))
                     if f.endswith('.json')]
            if not found:
                print(f'  no .json files in: {p}', file=sys.stderr)
            out += found
        else:
            out.append(p)

    themes = []
    for f in out:
        try:
            t = json.load(open(f))
        except Exception as e:
            print(f'  skipped {os.path.basename(f)}: {e}', file=sys.stderr)
            continue
        # index.json and pack manifests live beside theme.json in some dumps.
        if 'shell' not in t or 'layout' not in t:
            continue
        themes.append((t.get('name', os.path.basename(f)), t))
    return sorted(themes, key=lambda x: x[0].lower())


def table(headers, rows):
    w = [max(len(h), *(len(str(r[i])) for r in rows)) if rows else len(h)
         for i, h in enumerate(headers)]
    line = '  '.join(h.ljust(w[i]) for i, h in enumerate(headers))
    print(line)
    print('  '.join('-' * x for x in w))
    for r in rows:
        print('  '.join(str(c).ljust(w[i]) for i, c in enumerate(r)))


def main(argv):
    if not argv:
        print(__doc__)
        return 2

    themes = load(argv)
    if not themes:
        print(
            'No theme.json files found. Pull the live set with the command in '
            'this file\'s docstring, then point at that directory.',
            file=sys.stderr,
        )
        return 1

    names = [n for n, _ in themes]
    prints = {n: tuple(dig(t, p, d) for _, p, d in FIELDS) for n, t in themes}

    print(f'\n{len(themes)} distros\n')

    print('── STRUCTURE (fields with no prefs arm) ' + '─' * 32)
    table(
        ['distro'] + [f for f, _, _ in FIELDS],
        [[n] + list(prints[n]) for n in names],
    )

    print('\n── PANEL AND SURFACES ' + '─' * 50)
    table(
        ['distro', 'top panel modules', 'desklet surfaces'],
        [[n, panel_of(t), surfaces_of(t)] for n, t in themes],
    )

    print('\n── LOOK (has a prefs arm; NOT differentiation) ' + '─' * 26)
    table(
        ['distro'] + [f for f, _, _ in LOOK],
        [[n] + [dig(t, p, d) for _, p, d in LOOK] for n, t in themes],
    )

    # ── Collisions ──────────────────────────────────────────────────────────
    print('\n── COLLISIONS ' + '─' * 58)
    groups = {}
    for n in names:
        groups.setdefault(prints[n], []).append(n)

    dupes = [g for g in groups.values() if len(g) > 1]
    if dupes:
        for g in dupes:
            print(f'  IDENTICAL: {", ".join(g)}')
            print('             same product, different paint')
    else:
        print('  none: every distro has a unique structure')

    # ── Thin pairs ──────────────────────────────────────────────────────────
    #
    # Three or fewer differing fields is the line, and it is a judgement rather
    # than a law. Below it a buyer who owns one is unlikely to feel the other is
    # a separate thing, whatever the palette does.
    print('\n── THIN PAIRS (3 or fewer differing fields) ' + '─' * 28)
    thin = []
    for a, b in combinations(names, 2):
        diff = [FIELDS[i][0] for i in range(len(FIELDS))
                if prints[a][i] != prints[b][i]]
        if len(diff) <= 3:
            thin.append((len(diff), a, b, diff))
    if thin:
        for n, a, b, diff in sorted(thin):
            print(f'  {n}/{len(FIELDS)}  {a} vs {b}')
            print(f'         differ only on: {", ".join(diff) or "NOTHING"}')
    else:
        print('  none')

    # ── Fields nobody uses ──────────────────────────────────────────────────
    #
    # A field every distro leaves at its default is a lever that was built and
    # is spending nothing, which is the failure this whole run kept finding.
    print('\n── UNUSED LEVERS (every distro on the default) ' + '─' * 25)
    idle = []
    for i, (field, _, default) in enumerate(FIELDS):
        if all(prints[n][i] == default for n in names):
            idle.append(f'{field} (all on {default!r})')
    print('  ' + ('\n  '.join(idle) if idle else 'none: every field is doing work'))

    # ── Distros that author nothing structural ──────────────────────────────
    print('\n── DISTROS ON EVERY DEFAULT ' + '─' * 43)
    defaults = tuple(d for _, _, d in FIELDS)
    bare = [n for n in names
            if all(prints[n][i] == defaults[i]
                   for i in range(1, len(FIELDS)))]
    if bare:
        for n in bare:
            print(f'  {n}: differs from a stock install only by shell and paint')
    else:
        print('  none')

    print()
    return 1 if dupes else 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
