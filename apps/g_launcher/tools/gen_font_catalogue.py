#!/usr/bin/env python3
"""Writes the font catalogue for BOTH the app and the admin panel.

Run from the repo root:

    python3 apps/g_launcher/tools/gen_font_catalogue.py

ONE SOURCE, TWO ARTIFACTS. Two hand-kept lists drift, and the drift is silent
in the worst direction: the panel offers a family, the pack publishes, and the
device resolves a name nothing registered and paints Roboto. Nothing errors
anywhere, and the first report is a screenshot.

The list is CURATED, not the whole Google Fonts library. A picker with fifteen
hundred families in it is a worse picker than one with seventy, and every family
here is one someone would plausibly want their phone to be set in.

`licence` decides which text ships in showLicensePage, and a wrong value is a
licensing claim rather than a cosmetic bug. Every value below was VERIFIED on
2026-08-15 against the directory a family lives in inside github.com/google/fonts,
which is the authoritative answer: `ofl/`, `apache/` and `ufl/` are the licence
buckets themselves.

That check corrected four entries that had been set from memory: Roboto, Roboto
Mono and Cousine are OFL and had been marked Apache, and Roboto Slab is Apache
and had been marked OFL. Re-run the check when adding families:

    curl -sIo /dev/null -w "%{http_code}" \
      https://raw.githubusercontent.com/google/fonts/main/ofl/<slug>/METADATA.pb

where <slug> is the family lowercased with everything non-alphanumeric removed.
The three values map to assets/fonts/licences/<value>.txt.
"""

import json

# (family, category, licence)
FAMILIES = [
    # ── sans ──────────────────────────────────────────────────────────────
    ("Archivo", "sans-serif", "ofl"),
    ("Assistant", "sans-serif", "ofl"),
    ("Barlow", "sans-serif", "ofl"),
    ("Cabin", "sans-serif", "ofl"),
    ("DM Sans", "sans-serif", "ofl"),
    ("Exo 2", "sans-serif", "ofl"),
    ("Figtree", "sans-serif", "ofl"),
    ("Fira Sans", "sans-serif", "ofl"),
    ("Heebo", "sans-serif", "ofl"),
    ("IBM Plex Sans", "sans-serif", "ofl"),
    ("Inter", "sans-serif", "ofl"),
    ("Josefin Sans", "sans-serif", "ofl"),
    ("Karla", "sans-serif", "ofl"),
    ("Lato", "sans-serif", "ofl"),
    ("Lexend", "sans-serif", "ofl"),
    ("Manrope", "sans-serif", "ofl"),
    ("Montserrat", "sans-serif", "ofl"),
    ("Mulish", "sans-serif", "ofl"),
    ("Noto Sans", "sans-serif", "ofl"),
    ("Nunito", "sans-serif", "ofl"),
    ("Nunito Sans", "sans-serif", "ofl"),
    ("Open Sans", "sans-serif", "ofl"),
    ("Outfit", "sans-serif", "ofl"),
    ("Oxygen", "sans-serif", "ofl"),
    ("PT Sans", "sans-serif", "ofl"),
    ("Plus Jakarta Sans", "sans-serif", "ofl"),
    ("Poppins", "sans-serif", "ofl"),
    ("Public Sans", "sans-serif", "ofl"),
    ("Quicksand", "sans-serif", "ofl"),
    ("Raleway", "sans-serif", "ofl"),
    ("Red Hat Display", "sans-serif", "ofl"),
    ("Roboto", "sans-serif", "ofl"),
    ("Rubik", "sans-serif", "ofl"),
    ("Sora", "sans-serif", "ofl"),
    ("Source Sans 3", "sans-serif", "ofl"),
    ("Space Grotesk", "sans-serif", "ofl"),
    ("Titillium Web", "sans-serif", "ofl"),
    ("Ubuntu", "sans-serif", "ufl"),
    ("Urbanist", "sans-serif", "ofl"),
    ("Work Sans", "sans-serif", "ofl"),

    # ── serif ─────────────────────────────────────────────────────────────
    ("Bitter", "serif", "ofl"),
    ("Cormorant Garamond", "serif", "ofl"),
    ("Crimson Text", "serif", "ofl"),
    ("Domine", "serif", "ofl"),
    ("EB Garamond", "serif", "ofl"),
    ("IBM Plex Serif", "serif", "ofl"),
    ("Libre Baskerville", "serif", "ofl"),
    ("Lora", "serif", "ofl"),
    ("Merriweather", "serif", "ofl"),
    ("Newsreader", "serif", "ofl"),
    ("Noto Serif", "serif", "ofl"),
    ("PT Serif", "serif", "ofl"),
    ("Playfair Display", "serif", "ofl"),
    ("Roboto Slab", "serif", "apache"),
    ("Source Serif 4", "serif", "ofl"),
    ("Spectral", "serif", "ofl"),
    ("Zilla Slab", "serif", "ofl"),

    # ── display ───────────────────────────────────────────────────────────
    ("Anton", "display", "ofl"),
    ("Audiowide", "display", "ofl"),
    ("Bebas Neue", "display", "ofl"),
    ("Comfortaa", "display", "ofl"),
    ("Fredoka", "display", "ofl"),
    ("Orbitron", "display", "ofl"),
    ("Oswald", "display", "ofl"),
    ("Righteous", "display", "ofl"),

    # ── monospace ─────────────────────────────────────────────────────────
    ("Anonymous Pro", "monospace", "ofl"),
    ("Azeret Mono", "monospace", "ofl"),
    ("Courier Prime", "monospace", "ofl"),
    ("Cousine", "monospace", "ofl"),
    ("DM Mono", "monospace", "ofl"),
    ("Fira Code", "monospace", "ofl"),
    ("Fira Mono", "monospace", "ofl"),
    ("IBM Plex Mono", "monospace", "ofl"),
    ("Inconsolata", "monospace", "ofl"),
    ("JetBrains Mono", "monospace", "ofl"),
    ("Martian Mono", "monospace", "ofl"),
    ("Nanum Gothic Coding", "monospace", "ofl"),
    ("Noto Sans Mono", "monospace", "ofl"),
    ("Overpass Mono", "monospace", "ofl"),
    ("Red Hat Mono", "monospace", "ofl"),
    ("Roboto Mono", "monospace", "ofl"),
    ("Share Tech Mono", "monospace", "ofl"),
    ("Source Code Pro", "monospace", "ofl"),
    ("Space Mono", "monospace", "ofl"),
    ("Ubuntu Mono", "monospace", "ufl"),
]


APP_OUT = "apps/g_launcher/assets/fonts/catalogue.json"
ADMIN_OUT = "admin/src/lib/g-launcher/font-catalogue.ts"

# Declared in apps/g_launcher/pubspec.yaml. `UbuntuMono` is NOT `Ubuntu Mono`:
# the first is this bundled family and resolves offline, the second is the
# Google Fonts name for a runtime fetch of the same typeface. Different strings,
# different code paths, and the picker must never rewrite one to the other.
BUNDLED = [("Ubuntu", "sans-serif"), ("UbuntuMono", "monospace")]


def write_admin(entries) -> None:
    rows = "\n".join(
        f'  {{ family: {json.dumps(e["family"])}, '
        f'category: {json.dumps(e["category"])} }},'
        for e in entries
    )
    bundled = "\n".join(
        f'  {{ family: {json.dumps(f)}, category: {json.dumps(c)} }},'
        for f, c in BUNDLED
    )
    with open(ADMIN_OUT, "r", encoding="utf-8") as f:
        current = f.read()

    # Only the two data arrays are regenerated. Everything else in that file is
    # hand-written logic (isKnownFamily, fontOptions, the stylesheet builder)
    # and rewriting it from here would mean maintaining TypeScript inside a
    # Python string, which is how the two drift in a different way.
    import re

    out = re.sub(
        r"(export const BUNDLED_FONTS: FontEntry\[\] = \[\n).*?(\n\];)",
        lambda m: m.group(1) + bundled + m.group(2),
        current,
        count=1,
        flags=re.S,
    )
    out = re.sub(
        r"(export const GOOGLE_FONTS: FontEntry\[\] = \[\n).*?(\n\];)",
        lambda m: m.group(1) + rows + m.group(2),
        out,
        count=1,
        flags=re.S,
    )
    assert out != current or rows in current, "admin catalogue arrays not found"
    with open(ADMIN_OUT, "w", encoding="utf-8") as f:
        f.write(out)


def main() -> None:
    seen = set()
    entries = []
    for family, category, licence in FAMILIES:
        assert family not in seen, f"duplicate family: {family}"
        seen.add(family)
        entries.append(
            {"family": family, "category": category, "licence": licence}
        )

    entries.sort(key=lambda e: e["family"])

    doc = {
        "version": 1,
        "note": (
            "Curated subset of Google Fonts. Fetched at runtime through the "
            "Play Services font provider, never bundled. See "
            "tools/gen_font_catalogue.py."
        ),
        "families": entries,
    }

    with open(APP_OUT, "w", encoding="utf-8") as f:
        json.dump(doc, f, indent=2, ensure_ascii=False)
        f.write("\n")

    write_admin(entries)

    mono = sum(1 for e in entries if e["category"] == "monospace")
    print(f"{len(entries)} families, {mono} monospace")
    print(f"wrote {APP_OUT}")
    print(f"wrote {ADMIN_OUT}")


if __name__ == "__main__":
    main()
