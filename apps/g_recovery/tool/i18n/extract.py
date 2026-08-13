#!/usr/bin/env python3
"""Collect every string the user reads into tool/i18n/en.json.

THE ENGLISH IS THE KEY, so this file is the whole source of truth for
translation: whatever a call site passes to `context.s` is what a translator
sees, and rewording the copy retires the old entry by itself.

en.json is GENERATED. Never edit it. Edit the Dart and run this again.

    python3 tool/i18n/extract.py            # write tool/i18n/en.json
    python3 tool/i18n/extract.py --check    # exit 1 if en.json is stale

Why a scanner and not a regex over the raw file: g_strings.dart documents the
scheme with `context.s('Nothing deleted here')` inside a doc comment. A regex
ships that comment as copy. Comments are blanked first, string literals are
not, so offsets and line numbers stay true.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
from datetime import datetime, timezone

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
LIB = os.path.join(ROOT, "lib")
OUT = os.path.join(ROOT, "tool", "i18n", "en.json")

# Generated bridges carry no user copy and are rewritten by pigeon.
SKIP_SUFFIX = (".g.dart",)
SKIP_DIRS = {"generated"}

# `.s('x')` and `.s1('x', v)`, with the opening paren possibly followed by a
# newline because dart format wraps long calls.
CALL = re.compile(
    r"""\.s1?\(\s*r?(?P<q>'''|\"\"\"|'|")(?P<body>(?:\\.|(?!(?P=q)).)*)(?P=q)""",
    re.S,
)

# A call whose first argument is not a literal. Those cannot be extracted, so
# they are reported rather than silently dropped.
DYNAMIC = re.compile(r"\.s1?\(\s*(?![r]?['\"])(?![)\s])")

FORBIDDEN = {
    "\u2014": "an em dash",
    "\u2013": "an en dash",
    "\u2026": "an ellipsis character",
}


def strip_comments(src: str) -> str:
    """Blank out comments, preserving length and newlines.

    Handles line comments, block comments (Dart nests them), single and double
    quotes, triple quotes, raw strings and escapes.
    """
    out = list(src)
    i = 0
    n = len(src)

    def blank(a: int, b: int) -> None:
        for k in range(a, b):
            if out[k] != "\n":
                out[k] = " "

    while i < n:
        c = src[i]

        if c == "/" and i + 1 < n and src[i + 1] == "/":
            j = src.find("\n", i)
            j = n if j < 0 else j
            blank(i, j)
            i = j
            continue

        if c == "/" and i + 1 < n and src[i + 1] == "*":
            depth = 1
            j = i + 2
            while j < n and depth:
                if src.startswith("/*", j):
                    depth += 1
                    j += 2
                elif src.startswith("*/", j):
                    depth -= 1
                    j += 2
                else:
                    j += 1
            blank(i, j)
            i = j
            continue

        if c in "'\"":
            raw = i > 0 and src[i - 1] == "r"
            triple = src.startswith(c * 3, i)
            close = c * 3 if triple else c
            j = i + len(close)
            while j < n:
                if not raw and src[j] == "\\":
                    j += 2
                    continue
                if src.startswith(close, j):
                    j += len(close)
                    break
                j += 1
            i = j
            continue

        i += 1

    return "".join(out)


UNI = re.compile(r"\\u\{([0-9a-fA-F]{1,6})\}|\\u([0-9a-fA-F]{4})")


def unescape(body: str) -> str:
    """Turn a Dart literal body into the runtime string.

    Unicode escapes are decoded so that an em dash written as \\u2014 is caught
    by the same check as one typed directly.
    """
    body = UNI.sub(lambda m: chr(int(m.group(1) or m.group(2), 16)), body)
    return (
        body.replace("\\n", "\n")
        .replace("\\t", "\t")
        .replace("\\'", "'")
        .replace('\\"', '"')
        .replace("\\$", "$")
        .replace("\\\\", "\\")
    )


def dart_files() -> list[str]:
    found: list[str] = []
    for base, dirs, names in os.walk(LIB):
        dirs[:] = [d for d in dirs if d not in SKIP_DIRS]
        for name in sorted(names):
            if not name.endswith(".dart"):
                continue
            if name.endswith(SKIP_SUFFIX):
                continue
            found.append(os.path.join(base, name))
    return sorted(found)


def line_of(src: str, offset: int) -> int:
    return src.count("\n", 0, offset) + 1


def collect() -> tuple[dict[str, list[str]], list[str]]:
    strings: dict[str, list[str]] = {}
    problems: list[str] = []

    for path in dart_files():
        rel = os.path.relpath(path, ROOT)
        raw = open(path, encoding="utf-8").read()
        code = strip_comments(raw)

        for m in DYNAMIC.finditer(code):
            problems.append(
                f"{rel}:{line_of(raw, m.start())} "
                "s() called with a variable. The English must be a literal."
            )

        for m in CALL.finditer(code):
            body = m.group("body")
            line = line_of(raw, m.start())
            text = unescape(body)

            if "$" in body.replace("\\$", ""):
                problems.append(
                    f"{rel}:{line} interpolation inside s(). "
                    "Use s1() with a {} slot instead."
                )
                continue
            if not text.strip():
                problems.append(f"{rel}:{line} empty string passed to s().")
                continue
            if text.count("{}") > 1:
                # one() substitutes with replaceFirst, so a second slot renders
                # as two literal braces on the screen.
                problems.append(
                    f"{rel}:{line} has {text.count('{}')} slots, "
                    f"s1() fills one: {text!r}"
                )
                continue
            for ch, name in FORBIDDEN.items():
                if ch in text:
                    problems.append(f"{rel}:{line} contains {name}: {text!r}")

            files = strings.setdefault(text, [])
            if rel not in files:
                files.append(rel)

    return strings, problems


def build(strings: dict[str, list[str]]) -> dict:
    keys = sorted(strings)
    return {
        "locale": "en",
        "generated": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "count": len(keys),
        # Key equals value, which is the point of the scheme. Kept as a map so
        # this file has the same shape as every strings-<code>.json.
        "strings": {k: k for k in keys},
        # Where each one is written, for a translator who needs the screen.
        # Paths only, no line numbers, so ordinary edits do not churn the diff.
        "sources": {k: sorted(strings[k]) for k in keys},
    }


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument(
        "--check",
        action="store_true",
        help="do not write, exit 1 if en.json is stale or a call site is bad",
    )
    args = ap.parse_args()

    strings, problems = collect()

    for p in problems:
        print(f"error: {p}", file=sys.stderr)

    doc = build(strings)
    text = json.dumps(doc, ensure_ascii=False, indent=2, sort_keys=False) + "\n"

    if args.check:
        current = open(OUT, encoding="utf-8").read() if os.path.exists(OUT) else ""
        stale = _without_timestamp(current) != _without_timestamp(text)
        if stale:
            print("error: en.json is stale, run extract.py", file=sys.stderr)
        if stale or problems:
            return 1
        print(f"en.json current, {doc['count']} strings")
        return 0

    if problems:
        print("refusing to write while call sites are broken", file=sys.stderr)
        return 1

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    open(OUT, "w", encoding="utf-8").write(text)
    print(f"wrote {os.path.relpath(OUT, ROOT)}, {doc['count']} strings")
    return 0


def _without_timestamp(text: str) -> str:
    try:
        doc = json.loads(text)
    except Exception:
        return text
    doc.pop("generated", None)
    return json.dumps(doc, ensure_ascii=False, sort_keys=True)


if __name__ == "__main__":
    raise SystemExit(main())
