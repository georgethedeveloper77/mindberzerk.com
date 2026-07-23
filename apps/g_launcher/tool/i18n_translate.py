#!/usr/bin/env python3
"""i18n_translate.py - translate assets/i18n/en.json into every configured
language using Google Translate (free, no API key) via deep-translator.

    pip install deep-translator          # once
    python3 tool/i18n_translate.py       # all languages, missing keys only

45 languages are configured below. Each run only fills the keys MISSING from
each <code>.json, so reviewed translations survive re-runs, and adding new
English keys later means just running this again.

FAST AND VISIBLY ALIVE: strings are sent in batches (many per request, joined
with a delimiter and split on return), with a progress line per batch. If a
batch comes back malformed (the delimiter did not survive), that batch alone
falls back to one-request-per-string, so a bad batch degrades to slow instead
of wrong. Placeholders ({name}, {n}) and product names (G Launcher, Ubuntu,
Dock, ...) are swapped for sentinels before translating and restored after;
any string whose placeholders do not survive keeps English with a warning.

Usage:
    python3 tool/i18n_translate.py                 # everything missing
    python3 tool/i18n_translate.py es fr sw        # only these codes
    python3 tool/i18n_translate.py --all es        # re-translate every key
    python3 tool/i18n_translate.py --dry-run       # preview, no network
    python3 tool/i18n_translate.py --src assets/i18n/en.json --out assets/i18n
"""

import json
import os
import re
import sys
import time

# file code -> Google Translate target code. File codes use underscores so
# they double as asset filenames (zh_CN.json). Keep in step with
# kBundledLocales in lib/i18n/app_locale.dart: add a language there, add it
# here, run this script.
LANGUAGES = {
    # Europe / Americas
    "es": "es", "fr": "fr", "pt": "pt", "de": "de", "it": "it", "nl": "nl",
    "pl": "pl", "tr": "tr", "ru": "ru", "uk": "uk", "ro": "ro", "cs": "cs",
    "el": "el", "hu": "hu", "sv": "sv", "da": "da", "fi": "fi", "no": "no",
    # Asia-Pacific
    "id": "id", "ms": "ms", "vi": "vi", "th": "th", "tl": "tl",
    "ja": "ja", "ko": "ko", "zh_CN": "zh-CN", "zh_TW": "zh-TW",
    # South Asia
    "hi": "hi", "bn": "bn", "ur": "ur", "ta": "ta", "te": "te", "ml": "ml",
    "mr": "mr", "gu": "gu", "pa": "pa",
    # Middle East
    "ar": "ar", "fa": "fa", "he": "iw",   # Google still uses the legacy 'iw'
    # Africa
    "sw": "sw", "am": "am", "ha": "ha", "yo": "yo", "ig": "ig", "zu": "zu",
    "af": "af",
}

DEFAULT_SRC = "assets/i18n/en.json"
DEFAULT_OUT = "assets/i18n"

# Never translate these; Google would happily turn "Dock" into "Muelle".
DO_NOT_TRANSLATE = [
    "G Launcher", "Ubuntu", "Fedora", "KDE", "GNOME", "Plasma", "Android",
    "Linux", "Dock", "Kali", "Garuda", "COSMIC", "Breeze", "Cinnamon",
]

# Batch delimiter: a line Google reliably preserves as its own line. Verified
# by count on return; any mismatch falls back to per-string for that batch.
DELIM = "\n@@\n"
BATCH_CHAR_BUDGET = 3500   # stay under the endpoint's ~5000-char limit
PH_RE = re.compile(r"\{[^}]+\}")
HAS_LETTER = re.compile(r"[A-Za-z]")


# --- io ---------------------------------------------------------------------

def load(path):
    if not os.path.exists(path):
        return {}
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def write(path, data):
    keys = sorted(data)
    lines = ["{"]
    for i, k in enumerate(keys):
        comma = "" if i == len(keys) - 1 else ","
        lines.append("  %s: %s%s" % (
            json.dumps(k, ensure_ascii=False),
            json.dumps(data[k], ensure_ascii=False), comma))
    lines.append("}")
    with open(path, "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")


# --- placeholder / brand protection -----------------------------------------

def placeholders(s):
    return set(PH_RE.findall(s))


def protect(text):
    spans = list(dict.fromkeys(PH_RE.findall(text)))
    for term in DO_NOT_TRANSLATE:
        if term in text:
            spans.append(term)
    restores = []
    for i, span in enumerate(spans):
        token = "[[%d]]" % i
        restores.append((token, span))
        text = text.replace(span, token)
    return text, restores


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


def call(translator, text):
    """One network call with retries."""
    last = None
    for attempt in range(3):
        try:
            return translator.translate(text) or ""
        except Exception as e:
            last = e
            time.sleep(1.5 * (attempt + 1))
    raise RuntimeError("translate failed after 3 tries: %s" % last)


def translate_single(translator, english):
    """One string, placeholder-safe. Returns None to mean 'keep English'."""
    if not HAS_LETTER.search(english):
        return english
    protected, restores = protect(english)
    out = restore(call(translator, protected), restores)
    if placeholders(out) != placeholders(english):
        return None
    return out


def translate_batch(translator, items):
    """items: list of (key, english). Returns {key: translation-or-None}.
    One request for the whole batch; falls back to per-string if the
    delimiter does not survive the round trip."""
    protected_all, restores_all = [], []
    for _k, english in items:
        p, r = protect(english)
        protected_all.append(p)
        restores_all.append(r)

    joined = DELIM.join(protected_all)
    out = call(translator, joined)
    # Google normalises whitespace around lines sometimes; split tolerantly.
    parts = [p.strip("\n") for p in re.split(r"\n?\s*@@\s*\n?", out)]

    result = {}
    if len(parts) == len(items):
        for (k, english), part, restores in zip(items, parts, restores_all):
            if not HAS_LETTER.search(english):
                result[k] = english
                continue
            tr = restore(part.strip(), restores)
            result[k] = tr if placeholders(tr) == placeholders(english) else None
        return result

    # Delimiter did not survive: this batch goes one-by-one. Slow, never wrong.
    for k, english in items:
        result[k] = translate_single(translator, english)
    return result


def batches(items):
    """Split (key, english) pairs into request-sized chunks."""
    chunk, budget = [], 0
    for k, v in items:
        cost = len(v) + len(DELIM)
        if chunk and budget + cost > BATCH_CHAR_BUDGET:
            yield chunk
            chunk, budget = [], 0
        chunk.append((k, v))
        budget += cost
    if chunk:
        yield chunk


def translate_lang(code, target, src, out_dir, force, dry):
    target_path = os.path.join(out_dir, code + ".json")
    existing = load(target_path)

    todo = [(k, v) for k, v in sorted(src.items()) if force or k not in existing]
    if not todo:
        print("  %-6s up to date (%d keys)" % (code, len(existing)))
        return

    if dry:
        print("  %-6s %d key(s) to translate" % (code, len(todo)))
        return

    translator = make_translator(target)
    kept_english, done = 0, 0
    t0 = time.time()
    for chunk in batches(todo):
        result = translate_batch(translator, chunk)
        for k, english in chunk:
            tr = result.get(k)
            if tr is None:
                kept_english += 1
                existing[k] = english
            else:
                existing[k] = tr
        done += len(chunk)
        # The heartbeat. This is what makes the run visibly alive instead of
        # "stuck": one line per request, with throughput.
        rate = done / max(time.time() - t0, 0.1)
        print("  %-6s %4d/%d  (%.0f strings/s)" % (code, done, len(todo), rate),
              flush=True)
        time.sleep(0.3)  # be gentle with the free endpoint

    write(target_path, existing)
    note = "  (%d kept English: placeholder issues)" % kept_english if kept_english else ""
    print("  %-6s wrote %s, %d keys total%s" % (code, target_path, len(existing), note))


# --- main -------------------------------------------------------------------

def clear_flutter_gen():
    """Delete lib/generated/assets.dart if it exists and nothing imports it.

    FlutterGen makes one class per directory NAME, so two folders both called
    'wallpapers' collide as $AssetsWallpapersGen and the file fails to compile.
    It keeps coming back because the IDE plugin regenerates on save. Since the
    app loads wallpapers by path (nothing imports the generated file), the safe
    move is to delete it. This runs on every translate so a routine i18n run
    also clears the error. To stop it regenerating for good, disable the
    FlutterGen IDE plugin's auto-generation.
    """
    gen = os.path.join("lib", "generated", "assets.dart")
    if not os.path.exists(gen):
        return
    # Refuse to delete if something actually references the generated symbols.
    used = False
    for dirpath, _dirs, files in os.walk("lib"):
        if os.path.normpath(dirpath) == os.path.normpath(os.path.dirname(gen)):
            continue
        for f in files:
            if not f.endswith(".dart"):
                continue
            try:
                with open(os.path.join(dirpath, f), encoding="utf-8") as fh:
                    body = fh.read()
            except OSError:
                continue
            if "generated/assets.dart" in body or "gen/assets.dart" in body:
                used = True
                break
        if used:
            break
    if used:
        print("note: lib/generated/assets.dart is imported somewhere; left in "
              "place. Rename a duplicate 'wallpapers' folder to fix the clash.")
        return
    os.remove(gen)
    print("cleared lib/generated/assets.dart (FlutterGen $AssetsWallpapersGen "
          "clash). Disable the FlutterGen IDE plugin so it stays gone.")


def main(argv):
    clear_flutter_gen()

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
        sys.exit("no source strings at %s" % src_path)

    print("source %s: %d key(s), %d language(s)" % (src_path, len(src), len(codes)))
    for code in codes:
        translate_lang(code, LANGUAGES[code], src, out_dir, force, dry)
    print("done. Machine output is a first pass; review short button labels.")


if __name__ == "__main__":
    main(sys.argv[1:])
