#!/usr/bin/env python3
"""Wrap hardcoded copy in context.s() so extract.py can see it.

    python3 tool/i18n/wrap.py lib/features/home              # report only
    python3 tool/i18n/wrap.py lib/features/home --apply      # rewrite

COMMIT FIRST. This edits files in place and there is no backup but git.

--- WHAT IT TOUCHES ------------------------------------------------------------

A literal is rewritten only when it sits in a position that is unambiguously
copy: the first argument of Text(), or a named argument from NAMED below. Every
other literal in the file is left alone and listed in the report.

--- ADJACENT LITERALS ARE ONE STRING -------------------------------------------

Dart concatenates them at compile time, so

    Text('Every count above '
         'is a floor until then.')

is one argument and one sentence. Wrapping only the first fragment strands the
second as an extra argument, which is a syntax error in every case and was the
single largest source of breakage in the first run of this script. The wrapper
goes around the whole run, and needs no requoting, because adjacent literals are
still legal inside the call.

--- CONST IS ALWAYS REMOVED ----------------------------------------------------

A method call cannot appear in a constant expression, so a constructor holding a
wrapped string can never stay const. This is not a flag: leaving const in place
is an error every time. The whole const expression is measured by brackets, so
`const _Foo(title: context.s('x'))` and `const <Widget>[Text(context.s('x'))]`
both lose their const, wherever in the argument list the call happens to sit.

--- HOW IT KNOWS THE CONTEXT VARIABLE ------------------------------------------

The nearest `BuildContext <name>` declared before the literal WHOSE SCOPE IS
STILL OPEN. The second half of that matters: without it, a literal in a method
declared after a build method borrows build's parameter name, which compiles to
nothing and produces an undefined name. Brace depth decides it, so a declaration
whose function has already closed is not a candidate.

--- WHAT IT REFUSES ------------------------------------------------------------

Interpolation, `Text('$count files')`. Those need a {} slot and a decision about
word order that only a person can make.

No BuildContext in scope at all. The extension is on BuildContext, so a literal
in a method that never received one cannot be wrapped without changing a
signature. Both are reported so the manual pass is a list rather than a hunt.

--- AFTER RUNNING --------------------------------------------------------------

    dart format lib && dart analyze lib && python3 tool/i18n/extract.py
"""

from __future__ import annotations

import argparse
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from extract import (  # noqa: E402
    LIT,
    has_interpolation,
    join_run,
    mask_literals,
    read_run,
    strip_comments,
)

VERSION = "3"

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

SKIP_FILES = ("/bridge/", "/generated/", "/core/i18n/", "firebase_options.dart")
SKIP_SUFFIX = (".g.dart",)

DIAGNOSTIC = re.compile(
    r"(GLog\.\w+|debugPrint|print|assert|throw|Exception|Error|jsonEncode"
    r"|PrefsKeys|writeJson|readJson|analytics|logEvent|setCustomKey)\s*\($"
)

CONTEXT_DECL = re.compile(r"BuildContext\s+(\w+)")

# Not copy: paths, keys, identifiers, units, format fragments.
PATHY = re.compile(r"(assets/|\.json$|\.png$|\.webp$|\.svg$|^/|^[a-z0-9_.]+$)")

WRAPPED = re.compile(r"\w+\.s1?\(")


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
    rel = os.path.relpath(os.path.join(ROOT, STRINGS), os.path.dirname(path))
    return f"import '{rel.replace(os.sep, '/')}';"


def add_import(src: str, path: str) -> str:
    line = import_line(path)
    if line in src:
        return src
    imports = list(re.finditer(r"^import .*;$", src, re.M))
    if not imports:
        return src
    at = imports[-1].end()
    return src[:at] + "\n" + line + src[at:]


def skip_literal(code: str, i: int) -> int | None:
    """Past the literal starting at i, or None when there is none."""
    m = LIT.match(code, i - 1 if i and code[i - 1] == "r" else i)
    return m.end() if m else None


def scope_end(code: str, decl_end: int) -> int:
    """Where the function holding this BuildContext parameter stops.

    Measured from the BODY, not from the parameter, because a method declared
    after build sits at the same class level brace depth and would otherwise
    look like it were still inside build. That is what produced eleven
    undefined name errors in device_page.dart.
    """
    depth = 1
    i = decl_end
    while i < len(code) and depth:
        ch = code[i]
        if ch in "'\"":
            j = skip_literal(code, i)
            if j:
                i = j
                continue
        if ch == "(":
            depth += 1
        elif ch == ")":
            depth -= 1
        i += 1

    while i < len(code) and (code[i].isspace() or code.startswith(("async", "sync", "*"), i)):
        i += 1 if code[i].isspace() else len(
            next(k for k in ("async", "sync", "*") if code.startswith(k, i))
        )

    if i < len(code) and code[i] == "{":
        depth = 0
        while i < len(code):
            ch = code[i]
            if ch in "'\"":
                j = skip_literal(code, i)
                if j:
                    i = j
                    continue
            if ch == "{":
                depth += 1
            elif ch == "}":
                depth -= 1
                if depth == 0:
                    return i
            i += 1
        return len(code)

    if code.startswith("=>", i):
        # An expression body, which ends at the comma, bracket or semicolon
        # that closes it. A closure passed as an argument ends at the comma.
        depth = 0
        i += 2
        while i < len(code):
            ch = code[i]
            if ch in "'\"":
                j = skip_literal(code, i)
                if j:
                    i = j
                    continue
            if ch in "([{":
                depth += 1
            elif ch in ")]}":
                if depth == 0:
                    return i
                depth -= 1
            elif ch in ",;" and depth == 0:
                return i
            i += 1
    return len(code)


def context_name(code: str, at: int) -> str | None:
    """The nearest BuildContext whose function has not already closed."""
    for m in reversed(list(CONTEXT_DECL.finditer(code, 0, at))):
        if scope_end(code, m.end()) > at:
            return m.group(1)
    return None


def expression_end(code: str, start: int) -> int:
    """The end of the const expression beginning at [start].

    Walks brackets rather than guessing at a shape, so a generic list literal,
    a constructor call and a nested pair of both all measure correctly.
    """
    depth = 0
    i = start
    opened = False
    while i < len(code):
        ch = code[i]
        if ch in "'\"":
            m = LIT.match(code, i - 1 if i and code[i - 1] == "r" else i)
            if m:
                i = m.end()
                continue
        if ch in "([{":
            depth += 1
            opened = True
        elif ch in ")]}":
            if depth == 0:
                return i
            depth -= 1
            if depth == 0 and opened:
                return i + 1
        elif ch in ",;" and depth == 0:
            return i
        i += 1
    return len(code)


def strip_const(src: str) -> str:
    """Remove const from every expression that now contains a wrapped call.

    Repeated to a fixed point because const nests: an outer const list holding a
    const constructor holding the call needs both removed, and removing the
    outer one first shifts every offset after it.
    """
    while True:
        code = mask_literals(strip_comments(src))
        for m in re.finditer(r"\bconst\b\s+", code):
            end = expression_end(code, m.end())
            if WRAPPED.search(code[m.end() : end]):
                src = src[: m.start()] + src[m.end() :]
                break
        else:
            return src


def classify(
    code: str, m: re.Match, parts: list[re.Match[str]], text: str
) -> tuple[str, str]:
    """Return (verdict, detail). Verdict is 'wrap', 'skip' or 'manual'."""
    before = code[: m.start()].rstrip()

    if WRAPPED.search(before[-8:]) and before.endswith("("):
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
    if any(p.group("raw") for p in parts):
        return "manual", f"{kind}, raw string"
    if has_interpolation(parts):
        return "manual", f"{kind}, interpolation needs a {{}} slot"
    if len(parts) > 1:
        kind = f"{kind}, {len(parts)} adjacent literals"
    return "wrap", kind


def process(path: str, apply: bool) -> tuple[int, list[str]]:
    raw = open(path, encoding="utf-8").read()
    code = strip_comments(raw)
    rel = os.path.relpath(path, ROOT)

    edits: list[tuple[int, int, str]] = []
    notes: list[str] = []
    claimed = 0

    for m in LIT.finditer(code):
        # A fragment already swallowed by an earlier run.
        if m.start() < claimed:
            continue

        parts, end = read_run(code, m.start())
        text = join_run(parts)
        verdict, detail = classify(code, m, parts, text)
        line = raw.count("\n", 0, m.start()) + 1

        if verdict == "skip":
            continue
        if verdict == "manual":
            notes.append(f"  {rel}:{line} {detail}: {text[:60]!r}")
            claimed = end
            continue

        name = context_name(code, m.start())
        if not name:
            notes.append(f"  {rel}:{line} no BuildContext in scope: {text[:60]!r}")
            claimed = end
            continue

        edits.append((m.start(), end, f"{name}.s({raw[m.start() : end]})"))
        claimed = end

    if not edits or not apply:
        return len(edits), notes

    out = raw
    for start, end, replacement in reversed(edits):
        out = out[:start] + replacement + out[end:]

    out = add_import(strip_const(out), path)
    open(path, "w", encoding="utf-8").write(out)
    return len(edits), notes


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("target", help="a folder or file under lib")
    ap.add_argument("--apply", action="store_true", help="rewrite in place")
    args = ap.parse_args()

    print(f"wrap.py v{VERSION}")

    files = [f for f in dart_files(args.target) if not any(s in f for s in SKIP_FILES)]
    if not files:
        sys.exit(f"error: no dart files under {args.target}")

    wrapped = 0
    all_notes: list[str] = []
    for path in files:
        count, notes = process(path, args.apply)
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
    print(
        f"\nnow: dart format {args.target} && dart analyze {args.target}"
        if args.apply
        else "\nnothing written, add --apply"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
