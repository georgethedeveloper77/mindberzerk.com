#!/usr/bin/env python3
"""Turn tool/i18n/en.json into assets/content/strings-<code>.json.

    pip install deep-translator
    python3 tool/i18n/extract.py
    python3 tool/i18n/translate.py                 # every language but English
    python3 tool/i18n/translate.py --only sw       # one language
    python3 tool/i18n/translate.py --dry-run       # what would change
    python3 tool/i18n/translate.py --engine debug  # no network, bracketed text

THE TARGET LIST COMES FROM GLanguage.all, read out of g_strings.dart, so the
picker and the files on disk cannot drift apart. Adding a language is one line
of Dart and one run of this.

--- WHAT GOOGLE GETS WRONG, AND WHAT IS DONE ABOUT IT --------------------------

Two things, both silent, both shipped before anyone notices.

The slot. `Found {} files` comes back with the braces spaced, bracketed or
gone, and `replaceFirst('{}')` then finds nothing, so the number never appears
and the sentence reads as though the app found no files at all. Every `{}` is
swapped for XX0XX before sending and restored after. If it does not survive,
the string is dropped and that line reads in English.

The vocabulary. Google will happily translate Pro, SMB and G Recovery. Each
term in KEEP is swapped for its own token the same way.

--- WHAT IS NEVER OVERWRITTEN --------------------------------------------------

Any English listed under "locked" in an existing file. Machine translation is a
first pass, not a last one: when a native speaker corrects a line, add its
English to that list and this script leaves it alone forever. The words worth
correcting first are the ones an engine cannot know are product terms, Reclaim,
Stale, Untouched, Trash.

--- WHAT IS REMOVED ------------------------------------------------------------

Entries whose English no longer appears anywhere in lib. That is the whole
maintenance story of the English-as-key scheme. Reword a button and the stale
translation retires itself on the next run.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
import time
from datetime import datetime, timezone

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
EN = os.path.join(ROOT, "tool", "i18n", "en.json")
DART = os.path.join(ROOT, "lib", "core", "i18n", "g_strings.dart")
OUT_DIR = os.path.join(ROOT, "assets", "content")

# Free endpoint. Too fast and it starts returning nothing.
SLEEP = 0.25
RETRIES = 3

# Never translated. Product names, protocols and units.
KEEP = [
    "G Recovery",
    "Mindberzerk",
    "Nextcloud",
    "WebDAV",
    "Android",
    "SHA-256",
    "Wi-Fi",
    "SFTP",
    "EXIF",
    "JPEG",
    "HEIC",
    "SMB",
    "NAS",
    "PNG",
    "Pro",
    "TB",
    "GB",
    "MB",
    "KB",
]

# House rules, enforced after the fact rather than trusted.
BANNED = {
    "\u2014": "em dash",
    "\u2013": "en dash",
    "\u2026": "ellipsis character",
    "...": "three dots",
}

# Where GLanguage codes and Google codes disagree. Anything absent is passed
# through unchanged.
GOOGLE_CODE = {
    "zh": "zh-CN",
    "zh-Hans": "zh-CN",
    "zh-Hant": "zh-TW",
    "pt-BR": "pt",
    "he": "iw",
    "fil": "tl",
    "nb": "no",
}

LANG_RE = re.compile(
    r"GLanguage\(\s*code:\s*'([a-zA-Z-]+)'\s*,\s*englishName:\s*'([^']*)'"
    r"\s*,\s*nativeName:\s*'([^']*)'",
    re.S,
)


def languages() -> list[tuple[str, str, str]]:
    src = open(DART, encoding="utf-8").read()
    found = LANG_RE.findall(src)
    if not found:
        sys.exit("error: could not read GLanguage.all from g_strings.dart")
    return [f for f in found if f[0] != "en"]


def out_path(code: str) -> str:
    return os.path.join(OUT_DIR, f"strings-{code}.json")


def load_existing(code: str) -> tuple[dict[str, str], list[str]]:
    path = out_path(code)
    if not os.path.exists(path):
        return {}, []
    doc = json.load(open(path, encoding="utf-8"))
    table = {
        k: v
        for k, v in (doc.get("strings") or {}).items()
        if isinstance(v, str) and v.strip()
    }
    return table, list(doc.get("locked") or [])


# --- token protection ---------------------------------------------------------


def token(index: int) -> str:
    """An opaque run Google leaves alone. Letters around a digit survive where
    braces, brackets and underscores do not."""
    return f"XX{index}XX"


def token_re(index: int) -> re.Pattern[str]:
    """Tolerant on the way back. Some targets lowercase the run or pad it."""
    return re.compile(r"X\s*X\s*" + str(index) + r"\s*X\s*X", re.IGNORECASE)


def protect(english: str) -> tuple[str, list[str]]:
    """Replace the slot and every glossary term with tokens.

    Returns the text to send and the original spans, indexed by token number.
    """
    spans: list[str] = []
    text = english

    if "{}" in text:
        spans.append("{}")
        text = text.replace("{}", token(0))
    else:
        # Index 0 stays reserved for the slot so a token number means the same
        # thing in every string, which keeps a failure readable in the log.
        spans.append("")

    # Longest first, so Wi-Fi is not eaten by a shorter term inside it.
    for term in sorted(KEEP, key=len, reverse=True):
        pattern = re.compile(rf"(?<!\w){re.escape(term)}(?!\w)")
        if pattern.search(text):
            spans.append(term)
            text = pattern.sub(token(len(spans) - 1), text)

    return text, spans


def restore(translated: str, spans: list[str]) -> str:
    out = translated
    for index, original in enumerate(spans):
        if not original:
            continue
        out = token_re(index).sub(original.replace("\\", "\\\\"), out)
    return out


# --- validation ---------------------------------------------------------------


def check(english: str, out: str) -> tuple[list[str], list[str]]:
    """Errors drop the string. Warnings are printed and the string is kept.

    There is no second attempt to be had here: Google cannot be told what it got
    wrong. So anything recoverable stays, and anything that would render a
    broken sentence goes back to English.
    """
    errors: list[str] = []
    warnings: list[str] = []

    if not out.strip():
        errors.append("empty")
    if english.count("{}") != out.count("{}"):
        errors.append(f"{english.count('{}')} slots in, {out.count('{}')} out")
    if re.search(r"XX\s*\d+\s*XX", out, re.IGNORECASE):
        errors.append("token left behind")
    for term in KEEP:
        if re.search(rf"(?<!\w){re.escape(term)}(?!\w)", english) and term not in out:
            errors.append(f"lost {term}")

    for ch, name in BANNED.items():
        if ch in out:
            warnings.append(name)
    if len(english) <= 24 and len(out) > int(len(english) * 1.8) + 8:
        warnings.append(f"long for a label, {len(english)} to {len(out)} chars")

    return errors, warnings


def scrub(out: str) -> str:
    """Fix what can be fixed without a second request."""
    out = out.replace("\u2014", ", ").replace("\u2013", ", ")
    out = out.replace("\u2026", ".").replace("...", ".")
    out = re.sub(r"\s+([.,;:!?])", r"\1", out)
    return re.sub(r"[ \t]{2,}", " ", out).strip()


# --- engine -------------------------------------------------------------------


def make_engine(code: str, engine: str):
    if engine == "debug":
        return lambda text: f"[{code}] {text}"

    try:
        from deep_translator import GoogleTranslator
    except ImportError:
        sys.exit("error: pip install deep-translator")

    target = GOOGLE_CODE.get(code, code)
    client = GoogleTranslator(source="en", target=target)

    def run(text: str) -> str:
        last = ""
        for attempt in range(RETRIES):
            try:
                got = client.translate(text)
                if got and got.strip():
                    return got
                last = "empty response"
            except Exception as error:  # the library raises a dozen types
                last = f"{type(error).__name__}: {error}"
            time.sleep(2 * (attempt + 1))
        raise RuntimeError(last)

    return run


def translate(
    code: str, missing: list[str], engine: str, sleep: float
) -> dict[str, str]:
    run = make_engine(code, engine)
    done: dict[str, str] = {}
    total = len(missing)

    for index, english in enumerate(missing, start=1):
        if index % 25 == 0 or index == total:
            print(f"  {code}: {index} of {total}", flush=True)

        sent, spans = protect(english)
        try:
            raw = run(sent)
        except RuntimeError as error:
            print(f"    kept English, {english!r}: {error}", file=sys.stderr)
            continue

        out = scrub(restore(raw, spans))
        errors, warnings = check(english, out)

        if errors:
            # Written nowhere, so this one line reads in English.
            print(
                f"    kept English, {english!r}: {', '.join(errors)}",
                file=sys.stderr,
            )
        else:
            if warnings:
                print(
                    f"    warning, {english!r}: {', '.join(warnings)}",
                    file=sys.stderr,
                )
            done[english] = out

        if engine != "debug" and sleep:
            time.sleep(sleep)

    return done


# --- main ---------------------------------------------------------------------


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", default="", help="comma separated codes")
    ap.add_argument("--force", action="store_true", help="retranslate everything")
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--engine", default="google", choices=["google", "debug"])
    ap.add_argument("--sleep", type=float, default=SLEEP)
    args = ap.parse_args()

    if not os.path.exists(EN):
        sys.exit("error: tool/i18n/en.json missing, run extract.py first")
    en_doc = json.load(open(EN, encoding="utf-8"))
    source = list(en_doc.get("strings") or {})
    if not source:
        sys.exit("error: en.json has no strings")

    wanted = {c.strip() for c in args.only.split(",") if c.strip()}
    targets = [l for l in languages() if not wanted or l[0] in wanted]
    if not targets:
        sys.exit(f"error: no language matches {args.only!r}")

    for code, _english_name, native_name in targets:
        existing, locked = load_existing(code)
        keep = {k: v for k, v in existing.items() if k in set(source)}
        dropped = len(existing) - len(keep)

        if args.force:
            missing = [s for s in source if s not in locked]
            keep = {k: v for k, v in keep.items() if k in locked}
        else:
            missing = [s for s in source if s not in keep]

        print(
            f"{code} ({native_name}): {len(keep)} kept, {dropped} retired, "
            f"{len(missing)} to translate, {len(locked)} locked"
        )

        if args.dry_run:
            continue

        if missing:
            keep.update(translate(code, missing, args.engine, args.sleep))

        doc = {
            "locale": code,
            "generated": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
            "source_count": len(source),
            # Hand corrected entries. Add the English here and this script will
            # never touch its translation again.
            "locked": sorted(locked),
            "strings": {k: keep[k] for k in sorted(keep)},
        }
        os.makedirs(OUT_DIR, exist_ok=True)
        with open(out_path(code), "w", encoding="utf-8") as f:
            f.write(json.dumps(doc, ensure_ascii=False, indent=2) + "\n")

        covered = len(doc["strings"])
        pct = round(100 * covered / len(source))
        print(
            f"  wrote {os.path.relpath(out_path(code), ROOT)}, "
            f"{covered} of {len(source)} strings, {pct} percent"
        )

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
