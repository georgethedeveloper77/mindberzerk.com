#!/usr/bin/env python3
"""
Audit every distro's `starter` desktop against the desklet engine.

A starter placement fails SILENTLY. `DeskletLayout.placeAt` returns the prefs
unchanged when `fits` says no, so an overlapping or oversized entry does not
throw, does not log, and does not appear. The desktop is simply emptier than the
pack author drew, and nothing anywhere says which tile went missing.

This mirrors the engine's own arithmetic rather than approximating it:

  desklet grid   cols * DeskletLayout.colFactor, rows * DeskletLayout.rowFactor
  span           authored, else DeskletKind.defaultSpan*
  clamp          _clampSpanX / _clampSpanY, including the max-below-min case
  fits           bounds check plus rectangle overlap, in starter order

Reported per pack:

  DROPPED     the entry does not place. It is not on the desktop.
  SHRUNK      an authored span was clamped up or down off the kind's default
  PANE-ONLY   a kind that occupies cells and never draws on a graphical shell
  REDUNDANT   an authored span equal to the default, which is drift waiting

Run from the monorepo root, or pass roots:

    python3 tools/starter_audit.py
    python3 tools/starter_audit.py apps/g_launcher/assets/themes themes
    python3 tools/starter_audit.py --fix        # rewrite starters in place
"""

import argparse
import json
import os
import re
import sys

# ─── MIRRORED FROM DeskletLayout ────────────────────────────────────────────
#
# Hardcoded rather than parsed, because these two are documented constants with
# a long argument attached and they do not move. The KIND table below is parsed,
# because it grows.
COL_FACTOR = 2
ROW_FACTOR = 3

SPEC = "apps/g_launcher/lib/engine/desklet_spec.dart"

KIND_BLOCK = re.compile(r"DeskletKind\((.*?)\n  \);", re.S)


def read_kinds(spec_path):
    """Parse `DeskletKind(...)` blocks out of the Dart source.

    Parsed rather than duplicated so a kind added tomorrow is audited without
    anyone remembering this file exists. A block missing any field it needs is
    skipped loudly rather than defaulted, since a silent default here would
    reproduce the exact class of bug the script is looking for.
    """
    src = open(spec_path, encoding="utf-8").read()
    kinds = {}
    for block in KIND_BLOCK.findall(src):
        def field(name, cast=int):
            m = re.search(rf"\b{name}:\s*([^,\n]+)", block)
            if not m:
                return None
            raw = m.group(1).strip().strip("'\"")
            if cast is bool:
                return raw == "true"
            try:
                return cast(raw)
            except ValueError:
                return None

        kid = field("id", str)
        if not kid:
            continue
        entry = {k: field(k) for k in
                 ("minSpanX", "minSpanY", "maxSpanX", "maxSpanY",
                  "defaultSpanX", "defaultSpanY")}
        if any(v is None for v in entry.values()):
            print(f"  ! kind '{kid}' is missing span fields, skipped",
                  file=sys.stderr)
            continue
        entry["paneOnly"] = field("paneOnly", bool) or False
        kinds[kid] = entry
    return kinds


def clamp(want, lo, hi, extent):
    """`_clampSpanX` verbatim, including the case that surprises people.

    When the grid is narrower than the kind's minimum, `min` is lowered to
    `max` rather than the clamp throwing. So a 5-wide kind on a 4-column grid
    becomes 4, not a refusal, and the pack author never learns their tile was
    cut down.
    """
    hi = min(hi, extent)
    lo = min(lo, hi)
    return max(lo, min(want, hi))


def overlaps(a, b):
    return not (a["col"] + a["sx"] <= b["col"] or b["col"] + b["sx"] <= a["col"]
                or a["row"] + a["sy"] <= b["row"] or b["row"] + b["sy"] <= a["row"])


def audit(path, kinds):
    try:
        spec = json.load(open(path, encoding="utf-8"))
    except json.JSONDecodeError as e:
        return {"path": path, "error": str(e)}

    layout = spec.get("layout") or {}
    grid = layout.get("grid") or {}
    icon_cols = grid.get("cols", 4)
    icon_rows = grid.get("rows", 5)
    cols = icon_cols * COL_FACTOR
    rows = icon_rows * ROW_FACTOR

    starter = ((spec.get("desklets") or {}).get("starter")) or []
    placed, notes, fixed = [], [], []

    for i, s in enumerate(starter):
        kid = s.get("kind")
        k = kinds.get(kid)
        if k is None:
            notes.append(("UNKNOWN", i, kid, "no such kind; placeAt returns early"))
            continue

        want_x, want_y = s.get("spanX"), s.get("spanY")
        sx = clamp(want_x if want_x is not None else k["defaultSpanX"],
                   k["minSpanX"], k["maxSpanX"], cols)
        sy = clamp(want_y if want_y is not None else k["defaultSpanY"],
                   k["minSpanY"], k["maxSpanY"], rows)

        if k["paneOnly"]:
            notes.append(("PANE-ONLY", i, kid,
                          "occupies cells and never draws on a graphical shell"))

        if want_x is not None or want_y is not None:
            dx, dy = k["defaultSpanX"], k["defaultSpanY"]
            if (want_x, want_y) == (dx, dy):
                notes.append(("REDUNDANT", i, kid,
                              f"authored {dx}x{dy}, which is the default"))
            else:
                notes.append(("SHRUNK", i, kid,
                              f"authored {want_x}x{want_y} -> renders {sx}x{sy}; "
                              f"default is {dx}x{dy}"))

        col, row = s.get("col"), s.get("row")
        page = s.get("page", 0)
        entry = {"col": col, "row": row, "sx": sx, "sy": sy, "page": page}

        if col is None or row is None:
            # `place` packs it into the first free cell, so it cannot collide
            # and cannot be dropped. Nothing to check.
            placed.append(entry)
            fixed.append({"kind": kid, "page": page})
            continue

        why = None
        if col < 0 or row < 0:
            why = "negative origin"
        elif col + sx > cols or row + sy > rows:
            why = (f"needs cols {col}..{col + sx - 1} of {cols}, "
                   f"rows {row}..{row + sy - 1} of {rows}")
        else:
            for j, other in enumerate(placed):
                if other["page"] == page and overlaps(entry, other):
                    why = f"overlaps starter[{j}]"
                    break

        if why:
            notes.append(("DROPPED", i, kid, why))
        else:
            placed.append(entry)

        fixed.append({"kind": kid, "page": page, "col": col, "row": row})

    return {
        "path": path,
        "name": spec.get("name", "?"),
        "grid": f"{icon_cols}x{icon_rows} icons -> {cols}x{rows} desklet cells",
        "count": len(starter),
        "notes": notes,
        "fixed": fixed,
    }


def repack(path, fixed):
    """Drop authored spans, keep positions, preserving key order elsewhere."""
    spec = json.load(open(path, encoding="utf-8"))
    spec.setdefault("desklets", {})["starter"] = fixed
    with open(path, "w", encoding="utf-8") as f:
        json.dump(spec, f, indent=2, ensure_ascii=False)
        f.write("\n")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("roots", nargs="*", default=None)
    ap.add_argument("--spec", default=SPEC)
    ap.add_argument("--fix", action="store_true",
                    help="rewrite each starter without spans (positions kept)")
    args = ap.parse_args()

    if not os.path.exists(args.spec):
        sys.exit(f"cannot find {args.spec}; run from the monorepo root "
                 "or pass --spec")

    kinds = read_kinds(args.spec)
    print(f"{len(kinds)} desklet kinds parsed from {args.spec}\n")

    roots = args.roots or ["."]
    paths = []
    for root in roots:
        for dirpath, dirnames, names in os.walk(root):
            dirnames[:] = [d for d in dirnames
                           if d not in ("node_modules", ".git", "build", ".next")]
            if "theme.json" in names:
                paths.append(os.path.join(dirpath, "theme.json"))
    paths.sort()

    bad = 0
    for p in paths:
        r = audit(p, kinds)
        if "error" in r:
            print(f"{p}\n  INVALID JSON: {r['error']}\n")
            bad += 1
            continue
        head = f"{r['name']}  ({r['grid']}, {r['count']} starter entries)"
        if not r["notes"]:
            print(f"  ok   {head}")
            continue
        bad += 1
        print(f"\n  {head}\n       {p}")
        for kind_, i, kid, why in r["notes"]:
            print(f"       {kind_:<10} starter[{i}] {kid}: {why}")
        if args.fix:
            repack(p, r["fixed"])
            print("       fixed: spans removed, positions kept")

    print(f"\n{len(paths)} packs checked, {bad} with findings")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
