#!/usr/bin/env python3
"""
Join adjacent Dart string literals into one, so the reuse pass can key them.

    python3 tools/i18n_audit.py --json > audit.json
    python3 tools/i18n_join.py --dry-run
    python3 tools/i18n_join.py
    python3 tools/i18n_audit.py --json > audit.json
    python3 tools/i18n_extract.py && python3 tools/i18n_audit.py --json > audit.json
    python3 tools/i18n_reuse.py
    flutter analyze

─── WHAT THIS FIXES ─────────────────────────────────────────────────────────

Dart concatenates literals that merely sit next to each other:

    'Rotation, fit and lock. Your photos stay'
    ' where they are.'

That is ONE string to a reader and TWO to every regex. The audit reports only
the first fragment, so its key gets named after half a sentence and its English
is half a sentence, and `i18n_reuse` refuses the site rather than stranding the
second half as a second argument.

Joining them first turns the whole family into ordinary single-literal sites.

─── THE JOIN IS EXACT ───────────────────────────────────────────────────────

Dart inserts NOTHING between adjacent literals, so neither does this. The
authored line break is where a space already is or is not, and adding one would
silently change copy. `'stay'` followed by `' where'` keeps the leading space
that was already written into the second fragment.

Refused rather than guessed at:

  MIXED QUOTES. Joining `'a'` with `"b"` means re-escaping one side against the
  other's rules, and a wrong guess corrupts an apostrophe.
  ADJACENT INTERPOLATION. If any fragment interpolates, the result needs
  `t(key, vars)` and belongs with the other thirty-six.
  RAW STRINGS. `r'...'` does not escape, so it cannot be merged with one that
  does.
"""

import argparse
import json
import os
import re
import sys
from collections import defaultdict

AUDIT = "audit.json"

INTERP = re.compile(r"\$\{[^}]*\}|\$[A-Za-z_][A-Za-z0-9_]*")


def read_literal(src, i):
    """Read one Dart string literal starting at `i`.

    Returns (quote, inner, end) or None. Escapes are stepped over rather than
    interpreted, so the inner text comes back exactly as authored and can be
    written straight back out.
    """
    if i >= len(src) or src[i] not in "'\"":
        return None
    quote = src[i]
    j = i + 1
    while j < len(src):
        c = src[j]
        if c == "\\":
            j += 2
            continue
        if c == quote:
            return quote, src[i + 1:j], j + 1
        if c == "\n":
            return None  # unterminated on this line, not our shape
        j += 1
    return None


def literal_run(src, start):
    """Every literal in the adjacent run beginning at `start`.

    Returns (pieces, end) where pieces is [(quote, inner)]. Only whitespace may
    separate them; a comma, bracket or any other token ends the run.
    """
    pieces = []
    i = start
    while True:
        got = read_literal(src, i)
        if got is None:
            break
        quote, inner, end = got
        pieces.append((quote, inner))
        j = end
        while j < len(src) and src[j] in " \t\r\n":
            j += 1
        # A comment between fragments would be dropped by a naive join.
        if src[j:j + 2] in ("//", "/*"):
            return pieces, end
        if j < len(src) and src[j] in "'\"":
            i = j
            continue
        return pieces, end
    return pieces, start


def offset_of(src, line):
    """Absolute index of the start of a 1-based line."""
    pos = 0
    for _ in range(line - 1):
        nl = src.find("\n", pos)
        if nl == -1:
            return None
        pos = nl + 1
    return pos


def find_run(src, line, text):
    """Locate the adjacent run whose FIRST fragment is `text`, near `line`.

    The audit reports where the call starts, which for a wrapped argument is a
    line or two above the literal, so a small window is searched the same way
    the reuse pass does.
    """
    start = offset_of(src, line)
    if start is None:
        return None
    window_end = start
    for _ in range(5):
        nl = src.find("\n", window_end)
        if nl == -1:
            window_end = len(src)
            break
        window_end = nl + 1

    for quote in ("'", '"'):
        needle = quote + text + quote
        at = src.find(needle, start, window_end)
        if at == -1:
            continue
        pieces, end = literal_run(src, at)
        if len(pieces) > 1:
            return at, end, pieces
    return None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--audit", default=AUDIT)
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    if not os.path.isfile(args.audit):
        sys.exit(f"no {args.audit}; run the audit with --json first")
    with open(args.audit, encoding="utf-8") as fh:
        data = json.load(fh)

    by_file = defaultdict(list)
    for h in data.get("hardcoded", []):
        by_file[h["file"]].append(h)

    joined, refused = 0, []

    for path in sorted(by_file):
        if not os.path.isfile(path):
            continue
        with open(path, encoding="utf-8") as fh:
            src = fh.read()

        # Highest line first: every join shortens the file, so ascending order
        # would invalidate every offset behind it.
        runs = []
        for h in sorted(by_file[path], key=lambda x: x["line"], reverse=True):
            found = find_run(src, h["line"], h["text"])
            if found is None:
                continue
            at, end, pieces = found

            quotes = {q for q, _ in pieces}
            if len(quotes) > 1:
                refused.append((path, h["line"], "mixed quote characters"))
                continue
            if any(INTERP.search(inner) for _, inner in pieces):
                refused.append((path, h["line"], "interpolated, needs t(key, vars)"))
                continue
            if src[max(0, at - 1)] == "r":
                refused.append((path, h["line"], "raw string, escapes differ"))
                continue

            quote = pieces[0][0]
            merged = quote + "".join(inner for _, inner in pieces) + quote
            runs.append((at, end, merged, len(pieces)))

        if not runs:
            continue

        for at, end, merged, n in runs:
            if args.dry_run:
                print(f"  {path}")
                print(f"    {n} fragments -> {merged[:96]}")
            else:
                src = src[:at] + merged + src[end:]
            joined += 1

        if not args.dry_run:
            with open(path, "w", encoding="utf-8") as fh:
                fh.write(src)
            print(f"  {path}: {len(runs)} joined")

    verb = "would join" if args.dry_run else "joined"
    print(f"\n{verb} {joined} runs")

    if refused:
        print(f"\nrefused {len(refused)}:")
        for path, line, why in refused:
            print(f"  {path}:{line}  {why}")

    print(
        "\nnext:\n"
        "  python3 tools/i18n_audit.py --json > audit.json\n"
        "  python3 tools/i18n_extract.py\n"
        "  python3 tools/i18n_audit.py --json > audit.json\n"
        "  python3 tools/i18n_reuse.py\n"
        "  python3 tools/i18n_deconst.py\n"
        "  flutter analyze"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
