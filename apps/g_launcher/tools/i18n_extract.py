#!/usr/bin/env python3
"""
Mint en.json keys for hardcoded strings that do not have one yet.

    python3 tools/i18n_audit.py --json > audit.json
    python3 tools/i18n_extract.py --dry-run
    python3 tools/i18n_extract.py
    python3 tools/i18n_audit.py --json > audit.json
    python3 tools/i18n_reuse.py
    flutter analyze

─── WHY THIS DOES NOT TOUCH A SINGLE .dart FILE ─────────────────────────────

`i18n_reuse.py` already knows how to put a `context.t(key)` where a literal was:
the four-line window for wrapped calls, the const-stripping, the enclosing
context search, the refusals. Reproducing any of that here would mean two
copies of the same judgement, drifting.

So this tool does the ONE thing reuse cannot: it writes the English into
en.json. After it runs, the audit sees those strings as having an existing key,
which turns every one of them into exactly the case reuse was built for. Run
the audit again and reuse does the rest.

That is also why the sequence above regenerates audit.json in the middle. The
file is a snapshot, and the whole point of this pass is that it changes what
the next snapshot says.
"""

import argparse
import json
import os
import re
import sys
from collections import defaultdict

AUDIT = "audit.json"
EN = "assets/i18n/en.json"
OVERRIDES = "tools/i18n_overrides.json"

# `'$name'` or `'${expr}'`. These need `t(key, vars)` and a decision about what
# to call each placeholder, which is a judgement rather than a transformation.
INTERP = re.compile(r"\$\{[^}]*\}|\$[A-Za-z_][A-Za-z0-9_]*")


# Dart's escapes, as they appear in SOURCE. The audit reports the raw text
# between the quotes, so a string written `'Android\\'s settings'` arrives with
# the backslash still in it.
UNESCAPE = [
    ("\\\\", "\x00"),   # a real backslash, parked so nothing below eats it
    ("\\n", "\n"),
    ("\\t", "\t"),
    ("\\r", "\r"),
    ("\\'", "'"),
    ('\\"', '"'),
    ("\\$", "$"),
    ("\x00", "\\"),
]


def unescape(text):
    """Turn Dart source escapes into the characters they stand for.

    Without this the mint writes `Android\\'s` into en.json, and every locale
    inherits a backslash that renders on the phone. The double-backslash case is
    parked on a sentinel first, so `\\\\n` stays a backslash followed by an n
    rather than becoming a newline.
    """
    out = text
    for src, dst in UNESCAPE:
        out = out.replace(src, dst)
    return out


def load(path, what):
    if not os.path.isfile(path):
        sys.exit(f"no {path}; {what}")
    with open(path, encoding="utf-8") as fh:
        return json.load(fh)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--audit", default=AUDIT)
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument(
        "--interpolated",
        action="store_true",
        help="list the strings that need t(key, vars) by hand, then exit",
    )
    args = ap.parse_args()

    data = load(args.audit, "run: python3 tools/i18n_audit.py --json > audit.json")
    en = load(EN, "run me from the app root")

    # Hand-picked keys, consulted before the generator. Optional: a repo with no
    # collisions needs no file.
    overrides = {}
    if os.path.isfile(OVERRIDES):
        overrides = {
            k: v for k, v in json.load(open(OVERRIDES, encoding="utf-8")).items()
            if not k.startswith("_")
        }

    # Only the ones with no key yet. Anything with `existing` is reuse's job and
    # touching it here would mint a duplicate of a string already shipped in 46
    # locales.
    fresh = [h for h in data.get("hardcoded", []) if not h.get("existing")]

    interpolated = [h for h in fresh if INTERP.search(h["text"])]
    plain = [h for h in fresh if not INTERP.search(h["text"])]

    if args.interpolated:
        print(f"{len(interpolated)} interpolated strings, by hand:\n")
        for h in sorted(interpolated, key=lambda x: (x["file"], x["line"])):
            print(f"  {h['file']}:{h['line']}")
            print(f"    {h['text']}")
            print(f"    suggested key: {h['suggest']}")
        print(
            "\nEach needs the placeholders NAMED. `'${s.name} folder created'`\n"
            "becomes t('drawer.folderCreated', {'name': s.name}) with\n"
            '"{name} folder created" in en.json. The name is a decision, not a\n'
            "derivation, so no tool makes it."
        )
        return 0

    # ─── COLLISIONS ─────────────────────────────────────────────────────────
    #
    # `suggest_key` builds a key from the file's namespace and the first four
    # words, so two different sentences that open the same way land on one key.
    # Minting either would silently give both call sites the other's copy.
    #
    # Same key AND same text is not a collision, it is the same string used
    # twice, and one key serving both is the correct outcome.
    by_key = defaultdict(set)
    for h in plain:
        text = unescape(h["text"])
        # The override wins over the generated suggestion. Keyed on the text
        # rather than on file and line, so the same string in two places
        # resolves the same way and moving code does not silently unresolve it.
        by_key[overrides.get(text, h["suggest"])].add(text)

    unused = sorted(set(overrides) - {t for v in by_key.values() for t in v})
    if unused:
        print(f"{len(unused)} overrides match nothing, stale or mistyped:")
        for t in unused:
            print(f"  {t!r}")
        print()

    clashes = {k: v for k, v in by_key.items() if len(v) > 1}
    taken = {k: v for k, v in by_key.items() if k in en and en[k] not in v}

    mintable = {
        k: next(iter(v))
        for k, v in by_key.items()
        if k not in clashes and k not in taken
    }

    print(f"{len(fresh)} strings with no key")
    print(f"  {len(plain)} plain, {len(interpolated)} interpolated")
    print(f"  {len(mintable)} keys to mint")

    if clashes:
        print(f"\n{len(clashes)} key collisions, RENAME ONE SIDE AND RE-RUN:")
        for k, texts in sorted(clashes.items()):
            print(f"  {k}")
            for t in sorted(texts):
                print(f"      {t!r}")

    if taken:
        print(f"\n{len(taken)} keys already in en.json with different copy:")
        for k, texts in sorted(taken.items()):
            print(f"  {k}")
            print(f"      en.json has {en[k]!r}")
            for t in sorted(texts):
                print(f"      code has   {t!r}")

    if interpolated:
        print(
            f"\n{len(interpolated)} interpolated, left alone. "
            "See --interpolated for the list."
        )

    if args.dry_run:
        print("\n(dry run, en.json not written)")
        for k in sorted(mintable)[:15]:
            print(f"  {k:<44} {mintable[k]!r}")
        return 0

    if not mintable:
        print("\nnothing to mint")
        return 0

    en.update(mintable)
    # Sorted, so the diff is the new keys rather than a reshuffle.
    with open(EN, "w", encoding="utf-8") as fh:
        json.dump(dict(sorted(en.items())), fh, ensure_ascii=False, indent=2)
        fh.write("\n")
    print(f"\nen.json now {len(en)} keys")

    print(
        "\nnext:\n"
        "  python3 tools/i18n_audit.py --json > audit.json\n"
        "  python3 tools/i18n_reuse.py\n"
        "  flutter analyze"
    )
    print(
        "\nen.json grew, so every other locale is now further behind. "
        "Run i18n_fill.py only once this settles."
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
