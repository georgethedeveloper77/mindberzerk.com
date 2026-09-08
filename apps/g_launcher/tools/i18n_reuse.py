#!/usr/bin/env python3
"""
Apply the free half of the i18n audit: hardcoded strings whose copy is ALREADY
in en.json under some other call site's key.

    python3 tools/i18n_audit.py --json > audit.json
    python3 tools/i18n_reuse.py --dry-run
    python3 tools/i18n_reuse.py
    flutter analyze

Only entries with a non-empty `existing` list are touched. Those need no new
key, no new English and no locale churn: a call site is pointed at a string that
already ships in 47 languages. Everything else is left for a human, because it
needs copy written.

─── WHY A REGEX PASS IS SAFE HERE AND WOULD NOT BE ELSEWHERE ────────────────

`t` is an extension on BuildContext that calls
`ProviderScope.containerOf(this, listen: false)`. It is a READ. Every context
under the scope answers identically, so picking the wrong one in scope changes
nothing, and picking one that is not in scope is a compile error rather than a
silent behaviour change.

That is not true of the other thing done with a context in this codebase.
`Navigator.pop(ctx)` against the caller's context instead of the menu's closes
the drawer rather than the menu, which is why `MenuAction.onTap` exists. Nothing
here pops anything.

─── WHAT IT REFUSES, AND WHY REFUSING IS THE POINT ──────────────────────────

Every skip is reported with a reason and the site is left untouched. A codemod
that guesses on the hard cases costs more to review than doing them by hand.
"""

import argparse
import json
import os
import re
import sys
from collections import defaultdict

AUDIT = "audit.json"
I18N_IMPORT = "import 'package:g_launcher/i18n/i18n.dart';\n"

# The nearest enclosing BuildContext parameter, searched backwards from the
# site. `ref` is the other lookup this codebase offers, but WidgetRef is only
# in scope inside a Consumer build and a BuildContext is in scope wherever a
# widget is being constructed at all, which is every site in the audit.
CONTEXT_DECL = re.compile(r"\bBuildContext\s+(\w+)")

# A literal that this pass will not rewrite. Interpolation is the big one: the
# audit reports `'$covered of your ${cov.total} apps'` as hardcoded and it is,
# but it needs `t(key, vars)` with a variable map, which is a judgement about
# what to name the placeholders.
HAS_INTERP = re.compile(r"\$\{|\$[A-Za-z_]")

# A const constructor cannot hold a method call. `const Text('Apps')` has to
# lose its const, and only the one wrapping THIS literal.
CONST_BEFORE = re.compile(r"\bconst\s+$")


def load_audit(path):
    if not os.path.isfile(path):
        sys.exit(
            f"no {path}. Run: python3 tools/i18n_audit.py --json > {path}"
        )
    with open(path, encoding="utf-8") as fh:
        return json.load(fh)


def literal_span(line, text):
    """Locate the exact quoted literal carrying `text` on this line.

    Returns (start, end, quote) or None. Matching on the RAW source rather than
    on the audit's decoded value, so an escaped quote inside the string lines up
    with what is actually written in the file.
    """
    for quote in ("'", '"'):
        needle = quote + text + quote
        i = line.find(needle)
        if i != -1:
            return i, i + len(needle), quote
    return None


def enclosing_context(lines, line_no):
    """The name of the nearest BuildContext parameter declared above the site.

    Backwards from the site rather than forwards, because the enclosing method's
    signature is above it and a later sibling method's is not in scope. This can
    still name a context from a method that has already closed, in which case
    the result does not compile and `flutter analyze` says so by name, which is
    a better failure than a wrong string.
    """
    for i in range(line_no - 1, -1, -1):
        m = None
        for m in CONTEXT_DECL.finditer(lines[i]):
            pass  # keep the LAST on the line: `(BuildContext context, ...)`
        if m:
            return m.group(1)
    return None


def has_i18n_import(src):
    return "i18n/i18n.dart" in src


def add_import(src):
    """Insert the i18n import after the last COMPLETE import statement.

    After the block rather than alphabetically inside it: this codebase already
    puts the i18n import last in several files, and reordering imports would put
    unrelated churn in a diff whose whole value is being boring.

    ─── AN IMPORT IS NOT A LINE ───────────────────────────────────────────

    This searched for the last line STARTING with `import `, which is wrong on
    every combinator in the codebase:

        import '../../engine/theme_spec.dart'
            show PanelModule, PanelSpec, ThemePalette, TopBarSide;

    The `show` clause does not start with `import`, so the insertion landed
    between the two lines and cut the statement in half. Dart then read the
    orphaned combinator as a declaration and reported eight errors in one file,
    none of which named the real cause.

    So a statement runs from a line beginning `import ` to the next line ending
    in a semicolon, and the insert goes after THAT.
    """
    lines = src.split("\n")
    end = -1
    i = 0
    while i < len(lines):
        if lines[i].lstrip().startswith("import "):
            j = i
            # Walk to the line that actually terminates the statement. Bounded
            # by the file, so an unterminated import cannot spin here.
            while j < len(lines) and not lines[j].rstrip().endswith(";"):
                j += 1
            end = min(j, len(lines) - 1)
            i = j + 1
            continue
        i += 1
    if end == -1:
        return I18N_IMPORT + src
    lines.insert(end + 1, I18N_IMPORT.rstrip("\n"))
    return "\n".join(lines)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--audit", default=AUDIT)
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument(
        "--file",
        help="restrict to one path, for trying the pass on a single file first",
    )
    args = ap.parse_args()

    data = load_audit(args.audit)
    entries = [h for h in data.get("hardcoded", []) if h.get("existing")]
    if args.file:
        entries = [h for h in entries if h["file"] == args.file]

    by_file = defaultdict(list)
    for h in entries:
        by_file[h["file"]].append(h)

    applied, skipped = 0, []

    for path in sorted(by_file):
        if not os.path.isfile(path):
            skipped.append((path, 0, "file not found"))
            continue

        with open(path, encoding="utf-8") as fh:
            src = fh.read()
        lines = src.split("\n")

        # Highest line first, so an edit never shifts a site not yet visited.
        # Every replacement is longer than what it replaces, so ascending order
        # would invalidate every column offset behind it.
        todo = sorted(by_file[path], key=lambda h: h["line"], reverse=True)
        touched = False

        for h in todo:
            n, text, key = h["line"], h["text"], h["suggest"]

            if n < 1 or n > len(lines):
                skipped.append((path, n, "line out of range, audit is stale"))
                continue
            if HAS_INTERP.search(text):
                skipped.append((path, n, "interpolated, needs t(key, vars)"))
                continue

            # ─── THE LITERAL IS NOT ALWAYS ON THE REPORTED LINE ─────────
            #
            # `CALL_STR` and `PARAM_STR` both span `\s*`, which matches
            # newlines, and the audit reports the line the MATCH STARTS on. A
            # wrapped call puts the literal below it:
            #
            #     Text(                <- reported
            #       'Activities',      <- actual
            #
            # Searching only the reported line called twenty of these stale and
            # they were nothing of the kind. The window is small on purpose: a
            # literal further than a few lines from its call is more likely to
            # be a different string that happens to match.
            found = None
            for off in range(0, 4):
                if n - 1 + off >= len(lines):
                    break
                span = literal_span(lines[n - 1 + off], text)
                if span is not None:
                    found = (n - 1 + off, span)
                    break
            if found is None:
                skipped.append(
                    (path, n, "literal not found within 4 lines of the call")
                )
                continue

            idx, (start, end, _) = found
            line = lines[idx]
            ctx = enclosing_context(lines, idx + 1)
            if ctx is None:
                skipped.append((path, n, "no BuildContext in scope above"))
                continue

            head, tail = line[:start], line[end:]

            # Drop the `const` that this literal's own constructor carries.
            # Only when it sits immediately before the call being made const,
            # which on these sites is `const Text(` and `const Tooltip(`.
            call = re.search(r"(\bconst\s+)(\w+\(\s*)$", head)
            if call:
                head = head[: call.start(1)] + call.group(2)

            lines[idx] = f"{head}{ctx}.t('{key}'){tail}"
            applied += 1
            touched = True

        if not touched:
            continue

        out = "\n".join(lines)
        if not has_i18n_import(out):
            out = add_import(out)

        if args.dry_run:
            print(f"--- {path}")
            for h in sorted(by_file[path], key=lambda x: x["line"]):
                print(f"  {h['line']:>5}  {h['text']!r} -> {h['suggest']}")
        else:
            with open(path, "w", encoding="utf-8") as fh:
                fh.write(out)

    verb = "would apply" if args.dry_run else "applied"
    print(f"\n{verb} {applied} substitutions across {len(by_file)} files")

    if skipped:
        print(f"\nskipped {len(skipped)}, left for a human:")
        for path, n, why in skipped:
            print(f"  {path}:{n}  {why}")

    # ─── THE ONE FAILURE THIS PASS CANNOT SEE ───────────────────────────
    #
    # `const` propagates DOWN. A literal inside an outer const constructor is
    # implicitly const even with no `const` on its own line, so stripping the
    # keyword this pass can see is not always enough:
    #
    #     const Column(children: [Text('Apps')])   <- still a const context
    #
    # Detecting it means tracking constructor nesting across lines, which is a
    # parser. The analyzer already is one, and it names the file and line:
    # "Arguments of a constant creation must be constant expressions". Fixing it
    # is deleting the outer `const`.
    print("\nnext: flutter analyze")
    print("a const-context error there means an OUTER const to delete, "
          "not a bad substitution")
    return 0


if __name__ == "__main__":
    sys.exit(main())
