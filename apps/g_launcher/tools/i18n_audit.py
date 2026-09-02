#!/usr/bin/env python3
"""
i18n audit for g_launcher.

Four checks, because the interesting failures run in both directions:

  HARDCODED  a UI string literal that never passes through context.t
  MISSING    context.t('x') where x is not in en.json   <- renders as a raw key
  UNUSED     a key in en.json that no Dart file names   <- dead weight, and a
             signal that a screen was rewritten and its copy left behind
  PARITY     keys present in en.json and absent from another locale

Run from the app root:

    python3 tools/i18n_audit.py
    python3 tools/i18n_audit.py --only hardcoded
    python3 tools/i18n_audit.py --json > audit.json

Exit code is 1 when MISSING is non-empty, so it can gate a build. The other
three are advisory: HARDCODED has judgement in it and UNUSED is often correct
for a key that is about to be used again.
"""

import argparse
import json
import os
import re
import sys
from collections import defaultdict

LIB = "lib"
I18N = "assets/i18n"
BASE_LOCALE = "en.json"

# ─── WHAT COUNTS AS A USER-VISIBLE STRING ───────────────────────────────────
#
# Named parameters whose value lands on screen. Chosen from what this codebase
# actually uses rather than from Flutter's whole surface: `semantic` and
# `semanticLabel` are here because a screen reader reads them aloud, which is
# no less user-visible for being unpainted.
UI_PARAMS = [
    "title", "subtitle", "label", "hint", "message", "caption", "tooltip",
    "confirmLabel", "cancelLabel", "semantic", "semanticLabel", "summary",
    "helper", "placeholder", "errorText", "helperText", "labelText",
    "hintText", "heading", "body", "name",
]

# Calls whose first positional argument is shown to someone.
UI_CALLS = ["Text", "showMessage", "SelectableText", "ThemedSectionHeader"]

# ─── AND WHAT DOES NOT ──────────────────────────────────────────────────────
#
# Diagnostics go to a console. Translating them costs 47 files of churn to
# make a stack trace harder for you to read.
NEVER = [
    "debugPrint", "print(", "assert(", "throw ", "Exception(", "StateError(",
    "ArgumentError(", "FlutterError(", "log(", "developer.log",
]

# A literal that is plainly not prose.
SKIP_VALUE = re.compile(
    r"""^(
        [a-z0-9_]+                 # a bare identifier or enum-ish token
      | .{0,2}                     # one or two characters
      | [\d\s\W]+                  # punctuation, spacing, numbers only
      | (assets|packages)/.*       # asset paths
      | https?://.*
      | [A-Za-z0-9_\-/.]+\.(png|jpg|jpeg|webp|svg|ttf|otf|json|dart)
      | \#[0-9A-Fa-f]{3,8}         # colours
      | [A-Z_][A-Z0-9_]*           # SCREAMING_CASE constants
    )$""",
    re.VERBOSE,
)

# Anything with no letter in it, or no lowercase run of three, is very unlikely
# to be a sentence. Catches format strings, keys and single glyphs.
HAS_PROSE = re.compile(r"[a-z]{3}")

STR = r"""(?:'((?:[^'\\\n]|\\.)*)'|"((?:[^"\\\n]|\\.)*)")"""
T_CALL = re.compile(r"""\.t\(\s*['"]([^'"]+)['"]""")

# ─── KEYS BUILT AT RUNTIME ──────────────────────────────────────────────────
#
# `context.t('setup.step.${st.name}')` names eight keys and matches none of them
# literally, so a naive UNUSED check reports every one as dead. That is not a
# cosmetic inaccuracy: acting on it deletes copy that ships. The prefix up to
# the first interpolation is the only honest thing to key on, so everything
# under it is treated as reachable.
T_DYNAMIC = re.compile(r"""\.t\(\s*['"]([^'"$]*)\$""")

# ─── AND KEYS HELD IN A VARIABLE ────────────────────────────────────────────
#
# `context.t(card.messageKey)` or `t(k)` inside a loop names keys this scan
# cannot see at all: there is no literal and no prefix to key on. Every family
# reached that way appears UNUSED, which is the same trap the interpolation case
# was, one step further out.
#
# There is no honest fix, only honest reporting. When any of these exist the
# UNUSED list is a list of CANDIDATES rather than of dead keys, and it says so.
T_VARIABLE = re.compile(r"""\.t\(\s*(?!['"])[A-Za-z_]""")

# `'$count'` and `'${members.length}'` are numbers wearing quotes. The
# interpolation has to come out BEFORE the prose test, or the identifier inside
# it reads as a word: `$count` contains "count", which is three lowercase
# letters and nothing anybody translates.
INTERP = re.compile(r"\$\{[^}]*\}|\$[A-Za-z_][A-Za-z0-9_]*")
PARAM_STR = re.compile(r"\b(" + "|".join(UI_PARAMS) + r")\s*:\s*" + STR)
CALL_STR = re.compile(r"\b(" + "|".join(UI_CALLS) + r")\(\s*" + STR)


def strip_comments(src):
    """Blank out comments and keep line numbers intact.

    Line-preserving on purpose: this file's whole output is `path:line`, and a
    rewrite that shifts them sends you to the wrong place in the editor, which
    is worse than not reporting at all.
    """
    out = []
    i, n = 0, len(src)
    in_s = None  # the quote character we are inside, or None
    while i < n:
        c = src[i]
        if in_s:
            if c == "\\":
                out.append(src[i:i + 2])
                i += 2
                continue
            if c == in_s:
                in_s = None
            out.append(c)
            i += 1
            continue
        if c in "'\"":
            in_s = c
            out.append(c)
            i += 1
            continue
        if src.startswith("//", i):
            j = src.find("\n", i)
            j = n if j < 0 else j
            out.append(" " * (j - i))
            i = j
            continue
        if src.startswith("/*", i):
            j = src.find("*/", i + 2)
            j = n if j < 0 else j + 2
            out.append("".join(ch if ch == "\n" else " " for ch in src[i:j]))
            i = j
            continue
        out.append(c)
        i += 1
    return "".join(out)


def dart_files():
    for root, _, names in os.walk(LIB):
        for f in sorted(names):
            if not f.endswith(".dart"):
                continue
            # Generated code has no copy of its own worth translating.
            if f.endswith(".g.dart") or f.endswith(".freezed.dart"):
                continue
            yield os.path.join(root, f)


def suggest_key(path, value):
    """A key in this codebase's own shape: `namespace.camelCase`."""
    parts = path.split(os.sep)
    ns = parts[2] if len(parts) > 2 and parts[1] == "features" else parts[-2]
    ns = re.sub(r"[^a-z]", "", ns.lower()) or "common"
    words = re.findall(r"[A-Za-z]+", value)[:4]
    if not words:
        return f"{ns}.TODO"
    head = words[0].lower()
    tail = "".join(w.capitalize() for w in words[1:])
    return f"{ns}.{head}{tail}"


def scan(base):
    hardcoded, used, dynamic, variable = [], set(), set(), []

    # ─── THE MOST USEFUL COLUMN IN THE REPORT ────────────────────────────
    #
    # A hardcoded string very often has a key ALREADY, written when the same
    # copy appeared on another screen and then retyped here rather than reused.
    # Those are the free fixes: no new key, no 47 locale files to update, just
    # a call site pointed at something that exists. Matching on the VALUE is
    # what finds them, since the two sites rarely agree on wording of a key.
    by_value = {}
    for k, v in base.items():
        by_value.setdefault(v.strip().lower(), []).append(k)

    for path in dart_files():
        raw = open(path, encoding="utf-8").read()
        src = strip_comments(raw)
        lines = src.split("\n")

        for m in T_CALL.finditer(src):
            key = m.group(1)
            # A key with an interpolation in it is not a key, it is a family.
            # T_DYNAMIC below records its prefix; adding the raw text to `used`
            # would report the literal 'setup.step.${st.name}' as MISSING,
            # which is the one check that gates a build.
            if "$" in key:
                continue
            used.add(key)
        for m in T_VARIABLE.finditer(src):
            line_no = src.count("\n", 0, m.start()) + 1
            variable.append(f"{path}:{line_no}")
        for m in T_DYNAMIC.finditer(src):
            prefix = m.group(1)
            if prefix:
                dynamic.add(prefix)

        # Every string already inside a t() call is a KEY, not copy. Blanking
        # them first is what stops the report being a list of its own keys.
        src_no_keys = T_CALL.sub(lambda m: ".t(" + " " * (len(m.group(0)) - 3), src)

        for rx, kind in ((PARAM_STR, "param"), (CALL_STR, "call")):
            for m in rx.finditer(src_no_keys):
                value = m.group(2) if m.group(2) is not None else m.group(3)
                if value is None:
                    continue
                bare = INTERP.sub("", value).strip()
                if SKIP_VALUE.match(bare) or not HAS_PROSE.search(bare):
                    continue
                line_no = src_no_keys.count("\n", 0, m.start()) + 1
                line = lines[line_no - 1] if line_no <= len(lines) else ""
                if any(bad in line for bad in NEVER):
                    continue
                # ─── SAME NAMESPACE FIRST ────────────────────────────
                #
                # Matching on value alone offered `setup.step.welcome` for a
                # DESKLET named Welcome, and `setup.step.distro` for a settings
                # row called Desktop. Both are the same English word meaning
                # two different things, and a translator given one key for both
                # cannot render either correctly in a language that declines
                # them differently. Preferring a key from this file's own
                # namespace picks the one written for this screen.
                here = suggest_key(path, "x").split(".")[0]
                existing = sorted(
                    by_value.get(bare.lower(), []),
                    key=lambda k: (not k.startswith(here + "."), len(k)),
                )
                hardcoded.append({
                    "file": path,
                    "line": line_no,
                    "where": f"{m.group(1)} ({kind})",
                    "text": value,
                    "existing": existing,
                    "suggest": existing[0] if existing else suggest_key(path, value),
                })

    return hardcoded, used, dynamic, variable


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--json", action="store_true")
    ap.add_argument(
        "--only",
        choices=["hardcoded", "missing", "unused", "parity", "dupes"],
        action="append",
    )
    args = ap.parse_args()
    want = set(args.only or
               ["hardcoded", "missing", "unused", "parity", "dupes"])

    if not os.path.isdir(LIB):
        sys.exit(f"run me from the app root; no {LIB}/ here")

    base_path = os.path.join(I18N, BASE_LOCALE)
    base = json.load(open(base_path, encoding="utf-8"))
    hardcoded, used, dynamic, variable = scan(base)

    missing = sorted(k for k in used if k not in base)
    dynamic_note = sorted(dynamic)
    unused = sorted(
        k for k in base
        if k not in used and not any(k.startswith(d) for d in dynamic)
    )

    # ─── TWO KEYS, ONE STRING ───────────────────────────────────────────
    #
    # `drawer.deviceSettings` and `drawer.deviceSettings_2` are the shape this
    # finds, and the `_2` suffix says how they got here: an extractor ran twice
    # and appended rather than reusing. They are not harmless. Every duplicate
    # is a second string a translator is paid to translate, and the pair drifts
    # the first time somebody edits one of them, so the same button reads
    # differently on two screens in French and identically in English.
    dupes = defaultdict(list)
    for k, v in base.items():
        dupes[v.strip().lower()].append(k)
    dupes = {v: ks for v, ks in dupes.items() if len(ks) > 1}

    parity = {}
    if os.path.isdir(I18N):
        for f in sorted(os.listdir(I18N)):
            if not f.endswith(".json") or f == BASE_LOCALE:
                continue
            try:
                other = json.load(open(os.path.join(I18N, f), encoding="utf-8"))
            except json.JSONDecodeError as e:
                parity[f] = {"error": str(e)}
                continue
            gap = sorted(k for k in base if k not in other)
            if gap:
                parity[f] = {"missing": gap}

    if args.json:
        print(json.dumps({
            "hardcoded": hardcoded,
            "missing": missing,
            "unused": unused,
            "dupes": dupes,
            "parity": parity,
            "variableKeySites": variable,
        }, indent=2))
        return 1 if missing else 0

    if "missing" in want:
        print(f"\n=== MISSING KEYS ({len(missing)}) "
              "— context.t names these and en.json does not ===")
        for k in missing:
            print(f"  {k}")
        if not missing:
            print("  none")

    if "hardcoded" in want:
        by_file = defaultdict(list)
        for h in hardcoded:
            by_file[h["file"]].append(h)
        free = sum(1 for h in hardcoded if h["existing"])
        print(f"\n=== HARDCODED ({len(hardcoded)} in {len(by_file)} files, "
              f"{free} already have a key) ===")
        for f in sorted(by_file):
            print(f"\n{f}")
            for h in by_file[f]:
                print(f"  {h['line']:>5}  {h['where']:<22} {h['text']!r}")
                mark = "REUSE" if h["existing"] else "  new"
                print(f"         {mark} -> context.t('{h['suggest']}')")

    if "unused" in want:
        label = "CANDIDATES, NOT CONFIRMED" if variable else "unused"
        print(f"\n=== UNUSED KEYS ({len(unused)}, {label}) — "
              f"{len(dynamic_note)} dynamic prefixes excluded ===")
        for d in dynamic_note:
            print(f"  (kept: everything under {d}*)")
        if variable:
            print(f"  WARNING: {len(variable)} call sites pass a VARIABLE key.")
            print("  Any family reached that way is listed below as unused and")
            print("  is not. Check these before deleting anything:")
            for v in variable[:20]:
                print(f"      {v}")
            if len(variable) > 20:
                print(f"      (+{len(variable) - 20} more)")
            print()
        for k in unused:
            print(f"  {k}  =  {base[k]!r}")

    if "dupes" in want:
        print(f"\n=== DUPLICATE VALUES ({len(dupes)}) "
              "— one string, more than one key ===")
        for v, ks in sorted(dupes.items()):
            print(f"  {v!r}")
            for k in ks:
                print(f"      {k}")
        if not dupes:
            print("  none")

    if "parity" in want:
        print(f"\n=== LOCALE PARITY ({len(parity)} files behind en) ===")
        for f, info in parity.items():
            if "error" in info:
                print(f"  {f}: INVALID JSON, {info['error']}")
            else:
                gap = info["missing"]
                shown = ", ".join(gap[:6])
                more = f" (+{len(gap) - 6} more)" if len(gap) > 6 else ""
                print(f"  {f}: {len(gap)} missing — {shown}{more}")
        if not parity:
            print("  every locale matches en")

    return 1 if missing else 0


if __name__ == "__main__":
    sys.exit(main())
