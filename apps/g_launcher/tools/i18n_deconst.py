#!/usr/bin/env python3
"""
Delete the `const` that a newly substituted `t()` call sits inside.

    python3 tools/i18n_deconst.py --dry-run
    python3 tools/i18n_deconst.py
    flutter analyze

─── THE PROBLEM THIS EXISTS FOR ─────────────────────────────────────────────

`const` propagates DOWNWARD in Dart. A literal inside a const constructor is
implicitly const even with no keyword on its own line:

    const ThemedScaffold(title: context.t('settings.icons'), ...)
    const Column(children: [Text('Apps')])

`i18n_reuse.py` strips a `const` sitting on the same line, which is all a
line-oriented pass can see. Everything else surfaces as
`const_eval_method_invocation`, and the fix is always the same: find the
constructor whose `const` reaches this call and remove that one word.

─── WHY IT IS DRIVEN BY THE ANALYZER RATHER THAN BY A PARSER ────────────────

Deciding which expressions are in a const context means implementing Dart's
const rules. The analyzer already has. It reports file, line and column of the
exact offending invocation, which is a better starting point than any heuristic
this tool could compute, so the only work left is walking outward from that
point to the constructor that owns it.

Iterative on purpose: const constructors nest, removing one can expose another,
and the loop stops when the analyzer stops complaining or when a pass changes
nothing.
"""

import argparse
import re
import subprocess
import sys

# The three the analyzer raises when a call lands in a const context.
CONST_ERRORS = (
    "const_eval_method_invocation",
    "invalid_constant",
    "non_constant_list_element",
    "non_constant_map_value",
)

# `  error • message • path/to/file.dart:239:39 • code`
ERROR_LINE = re.compile(r"•\s+(\S+\.dart):(\d+):(\d+)\s+•\s+(\w+)\s*$")

OPENERS, CLOSERS = "([{", ")]}"
IDENT = re.compile(r"[A-Za-z0-9_.]")


def analyze():
    """Run the analyzer and return [(path, line, col, code)] for const errors."""
    proc = subprocess.run(
        ["flutter", "analyze"], capture_output=True, text=True
    )
    out = []
    for raw in proc.stdout.splitlines():
        m = ERROR_LINE.search(raw.strip())
        if m and m.group(4) in CONST_ERRORS:
            out.append((m.group(1), int(m.group(2)), int(m.group(3)), m.group(4)))
    return out


def offset_of(src, line, col):
    """Absolute index of a 1-based line and column."""
    pos = 0
    for _ in range(line - 1):
        nl = src.find("\n", pos)
        if nl == -1:
            return None
        pos = nl + 1
    return pos + col - 1


def enclosing_const(src, offset):
    """Span of the `const ` keyword whose constructor encloses `offset`.

    Walks outward one bracket level at a time. At each level it looks at the
    identifier immediately before the opening bracket and then at the word
    before that; the first `const` found owns this expression.

    Returns (start, end) of the keyword plus its trailing space, or None.
    """
    i = offset
    while i > 0:
        depth = 0
        # Back out to the opening bracket of the construct we are inside.
        while i > 0:
            i -= 1
            c = src[i]
            if c in CLOSERS:
                depth += 1
            elif c in OPENERS:
                if depth == 0:
                    break
                depth -= 1
        if i <= 0:
            return None

        # Skip the callee name sitting just before the bracket.
        j = i
        while j > 0 and IDENT.match(src[j - 1]):
            j -= 1
        # Skip the whitespace between `const` and the name.
        k = j
        while k > 0 and src[k - 1] in " \t\n":
            k -= 1
        if src[max(0, k - 5):k] == "const":
            return k - 5, j
        # Not this level. Keep walking outward from the bracket we found.


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--max-passes", type=int, default=6)
    args = ap.parse_args()

    total = 0
    for attempt in range(1, args.max_passes + 1):
        errors = analyze()
        if not errors:
            print(f"pass {attempt}: no const errors left")
            break

        print(f"pass {attempt}: {len(errors)} const errors")
        fixed = 0
        # One file at a time, highest offset first, so an edit never shifts a
        # site not yet visited in the same file.
        by_file = {}
        for path, line, col, code in errors:
            by_file.setdefault(path, []).append((line, col, code))

        for path, sites in by_file.items():
            with open(path, encoding="utf-8") as fh:
                src = fh.read()

            spans = []
            for line, col, code in sites:
                off = offset_of(src, line, col)
                if off is None:
                    print(f"  {path}:{line}:{col}  line out of range")
                    continue
                span = enclosing_const(src, off)
                if span is None:
                    print(f"  {path}:{line}:{col}  no enclosing const found ({code})")
                    continue
                spans.append(span)

            # Deduplicate: several errors under one const all name the same span.
            for start, end in sorted(set(spans), reverse=True):
                src = src[:start] + src[end:]
                fixed += 1
                print(f"  {path}  removed const at offset {start}")

            if spans and not args.dry_run:
                with open(path, "w", encoding="utf-8") as fh:
                    fh.write(src)

        total += fixed
        if args.dry_run:
            print("\n(dry run, nothing written)")
            break
        if fixed == 0:
            print("  no progress, stopping")
            break
    else:
        print(f"gave up after {args.max_passes} passes")

    print(f"\nremoved {total} const keywords")
    print("next: flutter analyze")
    return 0


if __name__ == "__main__":
    sys.exit(main())
