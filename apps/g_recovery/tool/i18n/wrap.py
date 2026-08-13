#!/usr/bin/env python3
"""Wrap hardcoded copy in context.s() so extract.py can see it.

    python3 tool/i18n/wrap.py lib/features/home              # report only
    python3 tool/i18n/wrap.py lib/features/home --apply      # rewrite
    python3 tool/i18n/wrap.py lib/features/home --apply --strip-const

COMMIT FIRST. This edits files in place and there is no backup but git.

--- WHAT IT TOUCHES ------------------------------------------------------------

A literal is rewritten only when it sits in a position that is unambiguously
copy: the first argument of Text(), or a named argument from NAMED below. Every
other literal in the file is left alone and listed in the report.

--- WHAT IT REFUSES ------------------------------------------------------------

Interpolation, `Text('$count files')`. Those need a {} slot and a decision
about word order that only a person can make. They are reported so the manual
pass is a list rather than a hunt.

No BuildContext in scope. The extension is on BuildContext, so a literal in a
method that never received one cannot be wrapped without changing a signature.

Literals inside a const collection. Removing const from `const <Widget>[...]`
changes more than this script should decide on its own.

--- HOW IT KNOWS THE CONTEXT VARIABLE ------------------------------------------

The nearest `BuildContext <name>` declared before the literal. That is a
heuristic and it can pick the wrong one in a file with nested builders, which is
why `dart analyze` is the gate: a wrong name is an undefined identifier and
fails loudly. A wrong name is never silent.

--- AFTER RUNNING --------------------------------------------------------------

    dart format lib/features/home
    dart analyze lib/features/home
    python3 tool/i18n/extract.py
"""

from __future__ import annotations

import argparse
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from extract import strip_comments, unescape  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
STRINGS = "lib/core/i18n/g_strings.dart"

# Named arguments that carry copy. Anything not here is left alone.
NAMED = {
    "title",
    "subtitle",
    "label",
    "message",
    "hint",
    "note",
    "text",
    "tooltip",
    "heading",
    "caption",
    "description",
    "placeholder",
    "confirm",
    "cancel",
    "action",
    "actionLabel",
    "empty",
    "emptyTitle",
    "emptyMessage",
    "helper",
    "error",
    "value",
    "unit",
    "trailing",
    "leadingText",
}

# Never rewritten in these, whatever the position.
SKIP_FILES = ("/bridge/", "/generated/", "/core/i18n/", "firebase_options.dart")
SKIP_SUFFIX = (".g.dart",)

# A call whose arguments are diagnostics, not copy.
DIAGNOSTIC = re.compile(
    r"(GLog\.\w+|debugPrint|print|assert|throw|Exception|Error|jsonEncode"
    r"|PrefsKeys|writeJson|readJson|analytics|logEvent|setCustomKey)\s*\($"
)

LITERAL = re.compile(
    r"""(?P<raw>r?)(?P<q>'''|\"\"\"|'|")(?P<body>(?:\\.|(?!(?P=q)).)*)(?P=q)""",
    re.S,
)

CONTEXT_DECL = re.compile(r"BuildContext\s+(\w+)")

# Not copy: paths, keys, identifiers, units, format fragments.
PATHY = re.compile(r"(assets/|\.json$|\.png$|\.webp$|\.svg$|^/|^[a-z0-9_.]+$)")


def dart_files(target: str) -> list[str]:
    path = os.path.join(ROOT, target) if not os.path.isabs(target) else target
    if os.path.isfile(path):
        return [path]
    found = []
    for base, _dirs, names in os.walk(path):
        for name in sorted(names):
            if name.endswith(".dart") and not name.endswith(SKIP_SUFFIX):
                found.append(os.path.join(base, name))
    return sorted(found)


def import_line(path: str) -> str:
    """The relative import of g_strings.dart from this file."""
    rel = os.path.relpath(
        os.path.join(ROOT, STRINGS), os.path.dirname(path)
    ).replace(os.sep, "/")
    return f"import '{rel}';"


def add_import(src: str, path: str) -> str:
    line = import_line(path)
    if line in src:
        return src
    imports = list(re.finditer(r"^import .*;$", src, re.M))
    if not imports:
        return src
    at = imports[-1].end()
    return src[:at] + "\n" + line + src[at:]


def in_const_collection(code: str, at: int) -> bool:
    """True when the literal sits inside `const [` or `const <Widget>[`."""
    depth = 0
    i = at
    while i > 0:
        ch = code[i]
        if ch == "]":
            depth += 1
        elif ch == "[":
            if depth == 0:
                head = code[max(0, i - 40) : i]
                return bool(re.search(r"const\s*(<[^>]*>)?\s*$", head))
            depth -= 1
        elif ch in ";}":
            return False
        i -= 1
    return False


def classify(code: str, m: re.Match) -> tuple[str, str]:
    """Return (verdict, detail). Verdict is 'wrap', 'skip' or 'manual'."""
    start = m.start()
    body = m.group("body")
    text = unescape(body)
    before = code[:start].rstrip()

    if before.endswith((".s(", ".s1(")):
        return "skip", "already wrapped"
    if DIAGNOSTIC.search(before):
        return "skip", "diagnostic call"

    if before.endswith("Text("):
        kind = "Text"
    else:
        named = re.search(r"(\w+):\s*$", before)
        if named and named.group(1) in NAMED:
            kind = named.group(1)
        else:
            return "skip", "not a copy position"

    if not re.search(r"[A-Za-z]", text):
        return "skip", "no letters"
    if PATHY.search(text.strip()):
        return "skip", "looks like a key or path"
    if len(text) <= 4 and text.upper() == text:
        return "skip", "unit or abbreviation"
    if m.group("raw"):
        return "manual", f"{kind}, raw string"
    if "$" in body.replace("\\$", ""):
        return "manual", f"{kind}, interpolation needs a {{}} slot"
    if in_const_collection(code, start):
        return "manual", f"{kind}, inside a const collection"
    return "wrap", kind


def context_name(code: str, at: int) -> str | None:
    found = None
    for m in CONTEXT_DECL.finditer(code, 0, at):
        found = m.group(1)
    return found


def process(path: str, apply: bool, strip_const: bool) -> tuple[int, list[str]]:
    raw = open(path, encoding="utf-8").read()
    code = strip_comments(raw)
    rel = os.path.relpath(path, ROOT)

    edits: list[tuple[int, int, str]] = []
    notes: list[str] = []

    for m in LITERAL.finditer(code):
        verdict, detail = classify(code, m)
        line = raw.count("\n", 0, m.start()) + 1
        text = unescape(m.group("body"))

        if verdict == "skip":
            continue
        if verdict == "manual":
            notes.append(f"  {rel}:{line} {detail}: {text[:60]!r}")
            continue

        name = context_name(code, m.start())
        if not name:
            notes.append(f"  {rel}:{line} no BuildContext in scope: {text[:60]!r}")
            continue

        literal = raw[m.start() : m.end()]
        edits.append((m.start(), m.end(), f"{name}.s({literal})"))

    if not edits or not apply:
        return len(edits), notes

    out = raw
    for start, end, replacement in reversed(edits):
        out = out[:start] + replacement + out[end:]

    if strip_const:
        out = re.sub(r"\bconst\s+(?=\w+\(\s*\w+\.s1?\()", "", out)

    out = add_import(out, path)
    open(path, "w", encoding="utf-8").write(out)
    return len(edits), notes


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("target", help="a folder or file under lib")
    ap.add_argument("--apply", action="store_true", help="rewrite in place")
    ap.add_argument(
        "--strip-const",
        action="store_true",
        help="drop const from constructors this script wrapped",
    )
    args = ap.parse_args()

    files = [
        f for f in dart_files(args.target) if not any(s in f for s in SKIP_FILES)
    ]
    if not files:
        sys.exit(f"error: no dart files under {args.target}")

    wrapped = 0
    all_notes: list[str] = []
    for path in files:
        count, notes = process(path, args.apply, args.strip_const)
        wrapped += count
        all_notes.extend(notes)
        if count:
            verb = "wrapped" if args.apply else "would wrap"
            print(f"{verb} {count:3} in {os.path.relpath(path, ROOT)}")

    if all_notes:
        print(f"\n{len(all_notes)} left for you:")
        for note in all_notes:
            print(note)

    print(f"\n{wrapped} wrapped, {len(all_notes)} manual, {len(files)} files")
    if args.apply:
        print(f"\nnow: dart format {args.target} && dart analyze {args.target}")
    else:
        print("\nnothing written, add --apply")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
