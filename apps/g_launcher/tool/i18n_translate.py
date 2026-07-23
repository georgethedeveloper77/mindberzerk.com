#!/usr/bin/env python3
"""i18n_translate.py - fill the per-language JSON files from en.json using
Google Translate (free, no API key), via the deep-translator library.

This is the second half of the loop. The Dart extractor keys every English
string into en.json; this translates those keys into every other language and
writes each <code>.json next to it.

    pip install deep-translator                # once
    dart run tool/i18n_extract.dart --write    # keys strings into en.json
    python3 tool/i18n_translate.py             # fills es/fr/pt/sw/hi/ar from en

By default it translates only the keys MISSING from each target file, so after
you add English strings a re-run fills just the gaps and leaves reviewed
translations alone.

Placeholders ({name}, {n}, {total}) and product names (G Launcher, Ubuntu, ...)
are swapped for sentinels before translating and restored after, and any string
whose placeholders do not survive the round trip falls back to English rather
than shipping broken. Machine translation is a first pass, not a final one:
review the output, especially the short button labels.

Usage:
    python3 tool/i18n_translate.py                 # every language, missing only
    python3 tool/i18n_translate.py es fr           # only these codes
    python3 tool/i18n_translate.py --all es        # re-translate every key
    python3 tool/i18n_translate.py --dry-run       # preview, no network, no install
    python3 tool/i18n_translate.py --src assets/i18n/en.json --out assets/i18n
"""

import json
import os
import re
import sys
import time

# code -> Google Translate target code. Keep in step with kBundledLocales in
# lib/i18n/app_locale.dart: add a language there, add it here.
LANGUAGES = {
    "es": "es",
    "fr": "fr",
    "pt": "pt",
    "sw": "sw",
    "hi": "hi",
    "ar": "ar",
}

DEFAULT_SRC = "assets/i18n/en.json"
DEFAULT_OUT = "assets/i18n"

# Never translate these; Google would happily turn "Dock" into "Muelle".
DO_NOT_TRANSLATE = [
    "G Launcher", "Ubuntu", "Fedora", "KDE", "GNOME", "Plasma", "Android",
    "Linux", "Dock",
]

PH_RE = re.compile(r"\{[^}]+\}")
HAS_LETTER = re.compile(r"[A-Za-z]")


# --- io ---------------------------------------------------------------------

def load(path):
    if not os.path.exists(path):
        return {}
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def write(path, data):
    # Matches the extractor's format: keys sorted, two-space indent, unicode
    # kept as-is, trailing newline. Keeps diffs between the two tools clean.
    keys = sorted(data)
    lines = ["{"]
    for i, k in enumerate(keys):
        comma = "" if i == len(keys) - 1 else ","
        lines.append(
            "  %s: %s%s"
            % (json.dumps(k, ensure_ascii=False), json.dumps(data[k], ensure_ascii=False), comma)
        )
    lines.append("}")
    with open(path, "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")


# --- placeholder / brand protection -----------------------------------------

def placeholders(s):
    return set(PH_RE.findall(s))


def protect(text):
    """Swap {placeholders} and brand names for [[n]] sentinels Google leaves
    alone. Returns (protected_text, restores) where restores maps back."""
    spans = list(dict.fromkeys(PH_RE.findall(text)))  # placeholders, in order
    for term in DO_NOT_TRANSLATE:
        if term in text:
            spans.append(term)

    protected = text
    restores = []
    for i, span in enumerate(spans):
        token = "[[%d]]" % i
        restores.append((token, span))
        protected = protected.replace(span, token)
    return protected, restores


def restore(text, restores):
    for token, span in restores:
        text = text.replace(token, span)
    return text


# --- translation ------------------------------------------------------------

def make_translator(target):
    try:
        from deep_translator import GoogleTranslator
    except ImportError:
        sys.exit("deep-translator is not installed. Run:  pip install deep-translator")
    return GoogleTranslator(source="en", target=target)


def translate_one(translator, english):
    # Nothing translatable (a bare placeholder, a symbol): keep verbatim.
    if not HAS_LETTER.search(english):
        return english

    protected, restores = protect(english)
    last = None
    for attempt in range(3):
        try:
            out = translator.translate(protected)
            out = restore(out or "", restores)
            # The safety net: if a placeholder did not survive, this string is
            # not safe to ship, so keep English and flag it.
            if placeholders(out) != placeholders(english):
                return None
            return out
        except Exception as e:  # deep-translator raises its own error types
            last = e
            time.sleep(1.5 * (attempt + 1))
    raise RuntimeError("translate failed after 3 tries: %s" % last)


def translate_lang(code, target, src, out_dir, force, dry):
    target_path = os.path.join(out_dir, code + ".json")
    existing = load(target_path)

    todo = {k: v for k, v in src.items() if force or k not in existing}
    if not todo:
        print("  %s: up to date (%d keys)" % (code, len(existing)))
        return

    print("  %s -> %s: %d key(s) to translate" % (code, target, len(todo)))
    if dry:
        for k in list(todo)[:8]:
            print("      %s" % k)
        if len(todo) > 8:
            print("      ...and %d more" % (len(todo) - 8))
        return

    translator = make_translator(target)
    kept_english = 0
    for n, (k, english) in enumerate(todo.items(), 1):
        tr = translate_one(translator, english)
        if tr is None:
            kept_english += 1
            print("      ! kept English for %s (placeholder did not survive)" % k)
            existing[k] = english
        else:
            existing[k] = tr
        if n % 10 == 0:
            time.sleep(0.5)  # be gentle with the free endpoint

    write(target_path, existing)
    note = " (%d kept English)" % kept_english if kept_english else ""
    print("  %s: wrote %s (%d keys total)%s" % (code, target_path, len(existing), note))


# --- main -------------------------------------------------------------------

def main(argv):
    args = list(argv)
    force = "--all" in args
    dry = "--dry-run" in args
    args = [a for a in args if a not in ("--all", "--dry-run")]

    src_path, out_dir = DEFAULT_SRC, DEFAULT_OUT
    if "--src" in args:
        i = args.index("--src"); src_path = args[i + 1]; del args[i:i + 2]
    if "--out" in args:
        i = args.index("--out"); out_dir = args[i + 1]; del args[i:i + 2]

    codes = [a for a in args if not a.startswith("-")] or list(LANGUAGES)
    unknown = [c for c in codes if c not in LANGUAGES]
    if unknown:
        sys.exit("unknown language code(s): %s (add them to LANGUAGES)" % ", ".join(unknown))

    src = load(src_path)
    if not src:
        sys.exit("no source strings at %s (run the extractor first)" % src_path)

    print("source %s: %d key(s)" % (src_path, len(src)))
    for code in codes:
        translate_lang(code, LANGUAGES[code], src, out_dir, force, dry)
    print("done. Machine translation is a first pass; review the short labels.")


if __name__ == "__main__":
    main(sys.argv[1:])
