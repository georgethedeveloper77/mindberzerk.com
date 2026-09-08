#!/usr/bin/env python3
"""
Fill the gap between en.json and every other locale, offline.

    pip install 'argostranslate>=1.9.0'
    python3 tools/i18n_fill.py --list
    python3 tools/i18n_fill.py --locale es --dry-run
    python3 tools/i18n_fill.py --locale es --locale pt
    python3 tools/i18n_fill.py --all
    python3 tools/i18n_audit.py --only parity

Argos runs locally on CPU with no key and no per-string cost, which is the whole
reason it is here: 44 locales times 145 keys is 6,380 strings, and it is going
to be run again every time en.json grows.

─── WHAT IT WILL NOT TOUCH ──────────────────────────────────────────────────

Only keys MISSING from a locale are written. An existing translation is never
overwritten, so a string somebody corrected by hand stays corrected, and a
second run after en.json grows costs only the new keys.

─── PLACEHOLDERS AND PRODUCT NOUNS ──────────────────────────────────────────

A machine translator will happily render `{name}` as `{nombre}` and translate
"Kickoff" into a sports metaphor. Both are protected by substitution before the
call and restored after, so what goes to the model is prose and what comes back
still interpolates.
"""

import argparse
import json
import os
import re
import sys

I18N = "assets/i18n"
BASE = "en.json"

# ─── LOCALE FILE TO ARGOS CODE ──────────────────────────────────────────────
#
# Only the ones that differ. Everything else uses the filename stem, which is
# already the ISO code Argos wants.
CODE_MAP = {
    "no": "nb",       # Argos ships Norwegian Bokmal
    "zh_CN": "zh",
    "zh_TW": "zt",    # Argos names Traditional 'zt'
}

# ─── NEVER TRANSLATED ───────────────────────────────────────────────────────
#
# Product and desktop nouns. A Plasma user looking for Kickoff is looking for
# the word Kickoff whatever language their phone is in, and a distro name is a
# trademark rather than a word. Matched case-sensitively and whole-word, so
# "Arch" the distro is protected and "arch" in a sentence is not.
KEEP = [
    "G Launcher", "Mindberzerk",
    "Ubuntu", "Fedora", "Debian", "Arch", "Manjaro", "EndeavourOS", "Garuda",
    "Kali", "Deepin", "Zorin", "Linux Mint", "Pop!_OS", "COSMIC", "elementary",
    "GNOME", "KDE", "Plasma", "Xfce", "Cinnamon", "Adwaita", "Breeze",
    "Activities", "Kickoff", "Whisker", "Launchpad", "Spotlight", "dmenu",
    "rofi", "waybar", "polybar", "Dash", "Dock", "Btrfs", "Snapper",
    "Android", "Google", "Play", "Samsung", "Nextcloud", "WebDAV", "SFTP",
    "SMB", "SSH", "Wi-Fi", "systemd", "fastfetch",
]

# `{name}`, `{count}` and friends. The braces are the contract with `t(key,
# vars)` and a translated brace is a string that renders the placeholder raw.
PLACEHOLDER = re.compile(r"\{[A-Za-z_][A-Za-z0-9_]*\}")

# A sentinel Argos will not split, inflect or reorder into another clause.
# Digits inside letters survive tokenisation in every engine tested; a bare
# number does not, and punctuation gets spaced out.
SENTINEL = "XQZ{}QZX"


def protect(text):
    """Swap placeholders and product nouns for sentinels.

    Returns (masked_text, restore_map). Placeholders go first: a product noun
    sitting inside a placeholder name would otherwise be masked twice and come
    back inside out.
    """
    restore = {}
    out = text
    n = 0

    for m in PLACEHOLDER.finditer(text):
        token = SENTINEL.format(n)
        restore[token] = m.group(0)
        out = out.replace(m.group(0), token, 1)
        n += 1

    for term in KEEP:
        # Whole word, case-sensitive. `\b` is wrong against "Pop!_OS", whose
        # last character is a word char but whose first run ends in `!`, so the
        # boundary is asserted only where the term itself has word edges.
        left = r"\b" if term[0].isalnum() else ""
        right = r"\b" if term[-1].isalnum() else ""
        pattern = left + re.escape(term) + right
        if not re.search(pattern, out):
            continue
        token = SENTINEL.format(n)
        restore[token] = term
        out = re.sub(pattern, token, out)
        n += 1

    return out, restore


def unprotect(text, restore):
    """Put the real strings back.

    Case-insensitive on the sentinel, because some targets lowercase a token
    they read as an ordinary noun. Longest token first, so XQZ1QZX cannot eat
    the prefix of XQZ11QZX.
    """
    out = text
    for token in sorted(restore, key=len, reverse=True):
        out = re.sub(re.escape(token), restore[token].replace("\\", "\\\\"),
                     out, flags=re.IGNORECASE)
    return out


def ensure_package(argostranslate, code):
    """Install the en -> code package if it is not already there.

    Returns None when Argos has no such pair. That is a real answer rather than
    an error: Argos covers roughly thirty targets and this app ships forty-six
    locales, so several will never be fillable this way and the caller needs to
    say which.
    """
    from argostranslate import package, translate

    langs = translate.get_installed_languages()
    src = next((l for l in langs if l.code == "en"), None)
    dst = next((l for l in langs if l.code == code), None)
    if src and dst and src.get_translation(dst):
        return src.get_translation(dst)

    package.update_package_index()
    available = package.get_available_packages()
    match = next(
        (p for p in available if p.from_code == "en" and p.to_code == code),
        None,
    )
    if match is None:
        return None
    package.install_from_path(match.download())

    langs = translate.get_installed_languages()
    src = next((l for l in langs if l.code == "en"), None)
    dst = next((l for l in langs if l.code == code), None)
    return src.get_translation(dst) if src and dst else None


def locale_files():
    return sorted(
        f for f in os.listdir(I18N)
        if f.endswith(".json") and f != BASE
    )


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--locale", action="append",
                    help="locale file stem, e.g. es. Repeatable.")
    ap.add_argument("--all", action="store_true")
    ap.add_argument("--list", action="store_true",
                    help="show the gap per locale and whether Argos covers it")
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    if not os.path.isdir(I18N):
        sys.exit(f"run me from the app root; no {I18N}/ here")

    try:
        import argostranslate  # noqa: F401
    except ImportError:
        sys.exit("pip install 'argostranslate>=1.9.0'")

    with open(os.path.join(I18N, BASE), encoding="utf-8") as fh:
        base = json.load(fh)

    if args.list:
        from argostranslate import package
        package.update_package_index()
        pairs = {
            p.to_code for p in package.get_available_packages()
            if p.from_code == "en"
        }
        print(f"{'locale':<10} {'gap':>5}  argos")
        for f in locale_files():
            stem = f[:-5]
            with open(os.path.join(I18N, f), encoding="utf-8") as fh:
                other = json.load(fh)
            gap = sum(1 for k in base if k not in other)
            code = CODE_MAP.get(stem, stem)
            mark = "yes" if code in pairs else "NO, needs a human"
            print(f"{stem:<10} {gap:>5}  {mark}")
        return 0

    if args.all:
        targets = [f[:-5] for f in locale_files()]
    elif args.locale:
        targets = args.locale
    else:
        sys.exit("pass --locale, --all or --list")

    for stem in targets:
        path = os.path.join(I18N, f"{stem}.json")
        if not os.path.isfile(path):
            print(f"{stem}: no such locale file, skipped")
            continue

        with open(path, encoding="utf-8") as fh:
            other = json.load(fh)
        gap = [k for k in base if k not in other]
        if not gap:
            print(f"{stem}: already complete")
            continue

        code = CODE_MAP.get(stem, stem)
        engine = ensure_package(argostranslate, code)
        if engine is None:
            print(f"{stem}: Argos has no en -> {code}, {len(gap)} keys left "
                  f"for a human")
            continue

        print(f"{stem}: {len(gap)} keys via en -> {code}")
        for i, key in enumerate(gap, 1):
            source = base[key]
            masked, restore = protect(source)
            translated = unprotect(engine.translate(masked), restore)
            other[key] = translated
            if args.dry_run and i <= 5:
                print(f"    {key}\n      {source}\n      {translated}")
            elif not args.dry_run and i % 25 == 0:
                print(f"    {i}/{len(gap)}")

        if args.dry_run:
            print(f"    (dry run, {stem}.json not written)")
            continue

        # Sorted, so a locale file's diff is only the new keys rather than a
        # reshuffle, and two runs on different machines produce the same file.
        with open(path, "w", encoding="utf-8") as fh:
            json.dump(dict(sorted(other.items())), fh,
                      ensure_ascii=False, indent=2)
            fh.write("\n")
        print(f"    wrote {path}")

    print("\nnext: python3 tools/i18n_audit.py --only parity")
    print("es and pt carry paying users, so read those two before shipping")
    return 0


if __name__ == "__main__":
    sys.exit(main())
