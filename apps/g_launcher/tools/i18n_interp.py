#!/usr/bin/env python3
"""
Rewrite interpolated literals into `t(key, vars)`, from a named mapping.

    python3 tools/i18n_audit.py --json > audit.json
    python3 tools/i18n_interp.py --dry-run
    python3 tools/i18n_interp.py
    python3 tools/i18n_deconst.py
    flutter analyze

`i18n_reuse` refuses interpolated strings and says why: `'${s.name} folder
created'` needs its placeholder NAMED, and the name is a decision nobody can
derive. `tools/i18n_vars.json` is where those decisions are written down. This
applies them.

─── WHAT IT DOES PER SITE ───────────────────────────────────────────────────

    'Group ${suggestion.size} apps into a folder'

becomes

    context.t('settings.groupAppsIntoFolder', {'count': suggestion.size})

with `"Group {count} apps into a folder"` minted into en.json.

Context resolution, the four-directional adjacency guard and the search window
are IMPORTED from `i18n_reuse` rather than reimplemented. Every one of them was
a bug found the hard way, and a second copy would have to find each again.
"""

import argparse
import importlib.util
import json
import os
import re
import sys
from collections import defaultdict

AUDIT = "audit.json"
EN = "assets/i18n/en.json"
VARS = "tools/i18n_vars.json"

HERE = os.path.dirname(os.path.abspath(__file__))


def load_reuse():
    """Borrow the sibling's hard-won helpers."""
    path = os.path.join(HERE, "i18n_reuse.py")
    spec = importlib.util.spec_from_file_location("i18n_reuse", path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def dart_map(variables):
    """`{'count': suggestion.size}` from {name: expression}.

    Sorted, so the same mapping always produces the same source and a re-run
    never shows a diff that is only reordering.
    """
    inner = ", ".join(
        f"'{name}': {expr}" for name, expr in sorted(variables.items())
    )
    return "{" + inner + "}"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--audit", default=AUDIT)
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    for path in (args.audit, EN, VARS):
        if not os.path.isfile(path):
            sys.exit(f"no {path}")

    reuse = load_reuse()
    with open(args.audit, encoding="utf-8") as fh:
        audit = json.load(fh)
    with open(EN, encoding="utf-8") as fh:
        en = json.load(fh)
    with open(VARS, encoding="utf-8") as fh:
        mapping = {
            k: v for k, v in json.load(fh).items() if not k.startswith("_")
        }

    # Every brace in the English must have an expression behind it, and every
    # expression must appear in the English. A mismatch renders a raw `{name}`
    # on someone's phone, which is the exact failure this pass exists to avoid.
    PH = re.compile(r"\{([A-Za-z_][A-Za-z0-9_]*)\}")
    for text, spec in mapping.items():
        want = set(PH.findall(spec["en"]))
        got = set(spec["vars"])
        if want != got:
            sys.exit(
                f"{spec['key']}: English has {sorted(want)}, "
                f"vars has {sorted(got)}"
            )

    by_file = defaultdict(list)
    for h in audit.get("hardcoded", []):
        if h["text"] in mapping:
            by_file[h["file"]].append(h)

    seen = {h["text"] for hs in by_file.values() for h in hs}
    unused = sorted(set(mapping) - seen)

    applied, skipped, minted = 0, [], {}

    for path in sorted(by_file):
        if not os.path.isfile(path):
            skipped.append((path, 0, "file not found"))
            continue
        with open(path, encoding="utf-8") as fh:
            src = fh.read()
        lines = src.split("\n")
        touched = False

        # Highest line first: every rewrite is longer than what it replaces.
        for h in sorted(by_file[path], key=lambda x: x["line"], reverse=True):
            n, text = h["line"], h["text"]
            spec = mapping[text]

            found = None
            for off in range(0, 8):
                if n - 1 + off >= len(lines):
                    break
                span = reuse.literal_span(lines[n - 1 + off], text)
                if span is not None:
                    found = (n - 1 + off, span)
                    break
            if found is None:
                skipped.append((path, n, "literal not found near the call"))
                continue

            idx, (start, end, _) = found
            if reuse.adjacent_literal(lines, idx, start, end):
                skipped.append(
                    (path, n, "adjacent literal, join the halves first")
                )
                continue

            ctx = reuse.enclosing_context(lines, idx + 1)
            if ctx is None:
                skipped.append((path, n, "no BuildContext in scope"))
                continue

            line = lines[idx]
            head, tail = line[:start], line[end:]
            call = re.search(r"(\bconst\s+)(\w+\(\s*)$", head)
            if call:
                head = head[: call.start(1)] + call.group(2)

            lines[idx] = (
                f"{head}{ctx}.t('{spec['key']}', {dart_map(spec['vars'])}){tail}"
            )
            minted[spec["key"]] = spec["en"]
            applied += 1
            touched = True

            if args.dry_run:
                print(f"  {path}:{n}")
                print(f"    {text}")
                print(f"    -> {lines[idx].strip()[:110]}")

        if touched and not args.dry_run:
            out = "\n".join(lines)
            if not reuse.has_i18n_import(out):
                out = reuse.add_import(out)
            with open(path, "w", encoding="utf-8") as fh:
                fh.write(out)

    verb = "would rewrite" if args.dry_run else "rewrote"
    print(f"\n{verb} {applied} sites, {len(minted)} keys")

    if unused:
        print(f"\n{len(unused)} mappings matched nothing:")
        for text in unused:
            print(f"  {text[:88]}")

    if skipped:
        print(f"\nskipped {len(skipped)}:")
        for path, n, why in skipped:
            print(f"  {path}:{n}  {why}")

    if args.dry_run:
        print("\n(dry run, nothing written)")
        return 0

    if minted:
        en.update(minted)
        with open(EN, "w", encoding="utf-8") as fh:
            json.dump(dict(sorted(en.items())), fh, ensure_ascii=False, indent=2)
            fh.write("\n")
        print(f"en.json now {len(en)} keys")

    print("\nnext: python3 tools/i18n_deconst.py && flutter analyze")
    return 0


if __name__ == "__main__":
    sys.exit(main())
