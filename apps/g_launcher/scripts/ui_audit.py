#!/usr/bin/env python3
"""Find the surfaces that were drawn for a desktop screenshot.

Mint's Cinnamon menu shipped with 9.5pt category labels, 17dp app icons and
22dp rows. None of that needed a device to find: every one of them is a numeric
literal sitting next to `fontSize:` or `size:`. This walks the tree and lists
them, worst file first, so the next pass is a queue rather than a hunt.

It reports; it does not judge. A 10pt label on a desklet that imitates conky is
correct, and a 14dp glyph inside a 48dp button is fine because the BUTTON is the
target. So every hit is a place to look, and the file ranking is the useful
output, not the individual line.

    python3 scripts/ui_audit.py            # every shell and drawer
    python3 scripts/ui_audit.py --all      # the whole tree
    python3 scripts/ui_audit.py --file lib/features/drawer/cinnamon_drawer.dart
"""

import argparse
import pathlib
import re
import sys
from collections import defaultdict

# ── thresholds ───────────────────────────────────────────────────────────────
#
# 48 is the touch-target floor this project already uses. 12pt is the smallest
# body text that survives a 3.0 dpr phone at arm's length; below that a label is
# decoration. 20dp is where a bare glyph stops being aimable on its own.
MIN_FONT = 12.0
MIN_ICON = 20.0
MIN_TARGET = 48.0

# `fontSize: 9.5 * theme.textScale` is still 9.5 at scale 1.0, so the multiplier
# is matched and ignored rather than excluded.
NUM = r'(\d+(?:\.\d+)?)'

CHECKS = [
    ('font',   re.compile(rf'\bfontSize:\s*{NUM}'),                 MIN_FONT),
    ('icon',   re.compile(rf'\bsize:\s*{NUM}'),                     MIN_ICON),
    # A minHeight under 12 is a divider, a rule or a progress track, never a
    # control somebody aims at. Reporting those buries the real ones.
    ('target', re.compile(rf'\bminHeight:\s*{NUM}'),                MIN_TARGET),
    ('target', re.compile(rf'\bstatic const _(?:width|height|size|row)\w*\s*=\s*{NUM}'), MIN_TARGET),
]

# Rows and tiles: a symmetric vertical padding under 10 on a Row almost always
# means the row is under 48 once the content is measured.
PAD = re.compile(rf'EdgeInsets\.symmetric\([^)]*vertical:\s*{NUM}')
MIN_PAD = 10.0

# Where the user actually touches things. Everything else is reported only
# under --all, because a 10pt figure on a stat card is a deliberate choice.
SURFACES = ('lib/features/drawer/', 'lib/features/dock/', 'lib/features/home/',
            'lib/features/panel/', 'lib/features/settings/', 'lib/shells/')

SKIP = ('.g.dart', '/generated/', 'lib/design/tokens/')


def scan(path: pathlib.Path):
    """Yield (line_no, kind, value, threshold, text) for one file."""
    for n, line in enumerate(path.read_text().split('\n'), 1):
        code = line.split('//')[0]
        if not code.strip():
            continue

        for kind, rx, floor in CHECKS:
            for m in rx.finditer(code):
                v = float(m.group(1))
                # Zero is a deliberate collapse, not an undersized control, and
                # a "target" in single digits is a divider or a track.
                if kind == 'target' and v < 12:
                    continue
                if 0 < v < floor:
                    yield n, kind, v, floor, line.strip()

        for m in PAD.finditer(code):
            v = float(m.group(1))
            if 0 < v < MIN_PAD:
                yield n, 'padding', v, MIN_PAD, line.strip()


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument('--all', action='store_true',
                    help='scan every file under lib/, not just touch surfaces')
    ap.add_argument('--file', help='scan one file and print every hit')
    ap.add_argument('--root', default='lib')
    args = ap.parse_args()

    if args.file:
        p = pathlib.Path(args.file)
        for n, kind, v, floor, text in scan(p):
            print(f'{p}:{n}  {kind:8} {v:<6} (floor {floor:g})  {text[:90]}')
        return 0

    root = pathlib.Path(args.root)
    if not root.is_dir():
        print(f'no {root}/ here: run from apps/g_launcher', file=sys.stderr)
        return 1

    files = defaultdict(lambda: defaultdict(list))
    for p in sorted(root.rglob('*.dart')):
        rel = str(p)
        if any(s in rel for s in SKIP):
            continue
        if not args.all and not any(rel.startswith(s) for s in SURFACES):
            continue
        for n, kind, v, floor, _ in scan(p):
            files[rel][kind].append((n, v))

    if not files:
        print('nothing under the floors. Suspicious, check the thresholds.')
        return 0

    # Ranked by how far under the floors a file is overall, not by hit count:
    # one 8pt label is worse than four 11pt ones.
    def debt(kinds):
        out = 0.0
        for kind, hits in kinds.items():
            floor = {'font': MIN_FONT, 'icon': MIN_ICON,
                     'target': MIN_TARGET, 'padding': MIN_PAD}[kind]
            out += sum(floor - v for _, v in hits)
        return out

    ranked = sorted(files.items(), key=lambda kv: debt(kv[1]), reverse=True)

    print(f'{"file":<58} {"font":>6} {"icon":>6} {"targ":>6} {"pad":>5}   worst')
    print('-' * 96)
    for rel, kinds in ranked:
        worst = []
        for kind in ('font', 'icon', 'target', 'padding'):
            if kinds.get(kind):
                lo = min(v for _, v in kinds[kind])
                worst.append(f'{kind}={lo:g}')
        counts = {k: len(kinds.get(k, [])) for k in
                  ('font', 'icon', 'target', 'padding')}
        print(f'{rel[-58:]:<58} {counts["font"]:>6} {counts["icon"]:>6} '
              f'{counts["target"]:>6} {counts["padding"]:>5}   {" ".join(worst)}')

    print()
    print(f'{len(ranked)} files with something under the floors '
          f'(font {MIN_FONT:g}, icon {MIN_ICON:g}, target {MIN_TARGET:g}, '
          f'padding {MIN_PAD:g}).')
    print('Run with --file on the top few to see the lines.')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
