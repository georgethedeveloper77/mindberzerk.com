#!/usr/bin/env python3
"""Do the four lists of dock animation ids still agree?

Four files have to know the same words:

  dock_animations.dart   what Settings offers
  theme_spec.dart        what a pack may author
  layout_resolver.dart   what survives resolution
  dock_motion.dart       what actually draws

A word missing from any one of them fails SILENTLY. Settings offers a mode, the
user picks it, the resolver does not recognise it and returns the default, and
the dock animates as though nothing was chosen. Nothing logs, nothing throws.

That is not hypothetical. `PanelModule` shipped with five entries in the admin
importer against ten on the device, so a pack authoring a pager or a clock had
both stripped on the way in and republished without them. This is the same
shape, one layer down.

    python3 scripts/mode_parity.py
"""

import pathlib
import re
import sys

ROOT = pathlib.Path('lib')

AXES = {
    'dockHover': {
        'catalogue': ('features/dock/dock_animations.dart', 'dockHoverModes'),
        'motion': ('features/dock/dock_motion.dart', 'DockSlotMotion'),
    },
    'dockPress': {
        'catalogue': ('features/dock/dock_animations.dart', 'dockPressModes'),
        'motion': ('features/dock/dock_motion.dart', 'DockPressMotion'),
    },
    'dockEntrance': {
        'catalogue': ('features/dock/dock_animations.dart', 'dockEntranceModes'),
        # No widget yet. Reported rather than skipped, so the day it lands the
        # script is already watching it.
        'motion': None,
    },
}


def read(rel: str) -> str:
    p = ROOT / rel
    if not p.exists():
        sys.exit(f'no {p}: run from apps/g_launcher')
    return p.read_text()


def catalogue(rel: str, listname: str) -> set[str]:
    """Ids in a `const dockXModes = [ DockAnimation('id', ...), ... ]`."""
    s = read(rel)
    m = re.search(rf'{listname}\s*=\s*\[(.*?)\];', s, re.S)
    if not m:
        return set()
    return set(re.findall(r"DockAnimation\(\s*'([^']+)'", m.group(1)))


def parsed(axis: str) -> set[str]:
    """Ids the device will accept from a pack."""
    s = read('engine/theme_spec.dart')
    m = re.search(rf"{axis}:\s*switch\s*\([^)]*\)\s*\{{(.*?)\}},", s, re.S)
    if not m:
        return set()
    return set(re.findall(r"'([^']+)'\s*=>", m.group(1)))


def resolved(axis: str) -> set[str]:
    """Ids the resolver's allow-list keeps.

    ─── READ TO THE `default`, NOT TO THE FIRST `),` ──────────────────────────

    The obvious regex ends the call at the first `),` and gets the wrong answer
    on exactly one axis: `dockHover`'s second argument is

        base.dockHover ?? (base.dockStyle == 'magnified' ? 'magnify' : null),

    whose `null),` closes the match before the allow-list is reached. The script
    then reported all seven ids missing from a list that contains all seven,
    which is the same shape of silent misread it exists to catch.

    `_pick`'s last argument is always `defaultDockX`, so that is the honest end
    of the call and cannot appear inside an earlier argument.
    """
    s = read('engine/layout_resolver.dart')
    start = s.find(f'{axis}: _pick(')
    if start < 0:
        return set()
    end = s.find(f'default{axis[0].upper()}{axis[1:]},', start)
    if end < 0:
        return set()
    braces = re.search(r'const \{(.*?)\}', s[start:end], re.S)
    if not braces:
        return set()
    return set(re.findall(r"'([^']+)'", braces.group(1)))


def drawn(rel: str, widget: str) -> set[str]:
    """Ids with a switch arm in the widget that draws them.

    Read from the widget's own `build`, because both widgets live in one file
    and a hover arm is not a press arm.
    """
    s = read(rel)
    start = s.find(f'class _{widget}State')
    if start < 0:
        start = s.find(f'class {widget} extends')
    if start < 0:
        return set()
    body = s[start:]
    end = body.find('\nclass ', 1)
    if end > 0:
        body = body[:end]

    ids = set(re.findall(r"^\s*'([a-z]+)'\s*=>", body, re.M))
    # These two never reach a switch arm: they return early.
    for special in ("'none'", "'sink'"):
        if f'mode == {special}' in body:
            ids.add(special.strip("'"))
    return ids


def main() -> int:
    bad = 0
    for axis, where in AXES.items():
        cat = catalogue(*where['catalogue'])
        par = parsed(axis)
        res = resolved(axis)
        mot = drawn(*where['motion']) if where['motion'] else None

        print(f'\n{axis}  ({len(cat)} offered)')
        print(f'  catalogue {sorted(cat)}')

        for name, got in (('parse', par), ('resolve', res)):
            missing = cat - got
            extra = got - cat
            if missing:
                bad += 1
                print(f'  {name}: MISSING {sorted(missing)}')
            if extra:
                bad += 1
                print(f'  {name}: not offered anywhere {sorted(extra)}')
            if not missing and not extra:
                print(f'  {name}: ok')

        if mot is None:
            print('  draw: no widget yet')
            continue

        missing = cat - mot
        if missing:
            bad += 1
            # The one that reads as working. A mode with no arm falls to the
            # `_ => child` default and rests, which is indistinguishable from a
            # dock that simply is not animating.
            print(f'  draw: MISSING {sorted(missing)}, these will rest')
        else:
            print('  draw: ok')

    print()
    if bad:
        print(f'{bad} mismatch(es). Every one of them is silent at runtime.')
        return 1
    print('All four lists agree.')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
