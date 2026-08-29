#!/usr/bin/env python3
"""Option A: delete authored spans and coordinates from desklets.starter.

WHY THIS IS A DELETION AND NOT A REWRITE
----------------------------------------
Every DeskletKind already declares a defaultSpanX/defaultSpanY in
desklet_spec.dart, and those defaults are correct: clock 4x2, monitor 4x3,
fastfetch 5x3. Twelve distros author spanX 2 / spanY 1-2 on top of them, which
is smaller than the default on every axis and, for monitor, smaller than
minSpanX 3, so _clampSpanX silently raises it and the authored number has never
rendered at all.

Dropping col and row too hands placement to DeskletLayout's packer, which is the
same code path a user's "add widget" tap already uses. That also removes the
collision hazard: placeAt clamps the span first, then calls fits(), and on
failure returns prefs unchanged, so a tile that no longer fits its authored
column is not moved and not shrunk. It is never created, with no log line.

WHAT IT TOUCHES
---------------
Only entries inside desklets.starter, and only the four keys. kind and page are
kept. Everything else in the file is untouched, including desklets.offers and
desklets.skins. Key order and 2-space indentation are preserved.

USAGE
-----
    python3 option-a-spans.py                 # dry run, prints the diff
    python3 option-a-spans.py --write         # apply
    python3 option-a-spans.py --write PATH..  # apply to specific files

With no paths it globs the repo from the current directory. Run it from
~/Documents/Projects/mindberzerk.
"""

import argparse
import glob
import json
import os
import sys

STRIP = ("spanX", "spanY", "col", "row")

DEFAULT_GLOBS = (
    "apps/g_launcher/assets/themes/*/theme.json",
    "apps/g_launcher/tools/icons/out/*/theme.json",
    "backend/content/themes/*/theme.json",
)

SKIP_DIRS = ("node_modules", "/build/", "/.next/", "/.dart_tool/")


def find_files(paths):
    if paths:
        return [p for p in paths if os.path.isfile(p)]
    out = []
    for pattern in DEFAULT_GLOBS:
        out.extend(glob.glob(pattern))
    return sorted(p for p in out if not any(s in p for s in SKIP_DIRS))


def strip_starter(doc):
    """Returns (changed_entries, kinds_touched). Mutates doc in place."""
    desklets = doc.get("desklets")
    if not isinstance(desklets, dict):
        return 0, []
    starter = desklets.get("starter")
    if not isinstance(starter, list):
        return 0, []

    changed = 0
    kinds = []
    for entry in starter:
        if not isinstance(entry, dict):
            continue
        removed = [k for k in STRIP if k in entry]
        if not removed:
            continue
        before = {k: entry[k] for k in removed}
        for k in removed:
            del entry[k]
        changed += 1
        kinds.append(
            "{} ({})".format(
                entry.get("kind", "?"),
                " ".join("{}={}".format(k, v) for k, v in before.items()),
            )
        )
    return changed, kinds


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("paths", nargs="*", help="theme.json files, or empty to glob")
    ap.add_argument("--write", action="store_true", help="apply instead of dry run")
    args = ap.parse_args()

    files = find_files(args.paths)
    if not files:
        print("No theme.json found. Run this from the repo root.", file=sys.stderr)
        return 1

    total_files = 0
    total_entries = 0

    for path in files:
        with open(path, "r", encoding="utf-8") as fh:
            raw = fh.read()
        try:
            doc = json.loads(raw)
        except json.JSONDecodeError as exc:
            print("SKIP  {}  (not valid JSON: {})".format(path, exc))
            continue

        changed, kinds = strip_starter(doc)
        if not changed:
            continue

        total_files += 1
        total_entries += changed
        print("{}  {}".format("WRITE" if args.write else "would", path))
        for k in kinds:
            print("        drop  {}".format(k))

        if args.write:
            trailing = "\n" if raw.endswith("\n") else ""
            out = json.dumps(doc, indent=2, ensure_ascii=False) + trailing
            with open(path, "w", encoding="utf-8") as fh:
                fh.write(out)

    print()
    print(
        "{} {} file(s), {} starter entr{}.".format(
            "Rewrote" if args.write else "Would rewrite",
            total_files,
            total_entries,
            "y" if total_entries == 1 else "ies",
        )
    )
    if not args.write:
        print("Dry run. Re-run with --write to apply.")
    else:
        print("Now republish through the panel. Do NOT renumber packVersion:")
        print("the CDN path embeds the version and a device would read a")
        print("lower number as a downgrade.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
