/**
 * The families the font pickers offer, and the two the APK already carries.
 *
 * ─── GENERATED. DO NOT HAND-EDIT. ───────────────────────────────────────────
 *
 * Written by `apps/g_launcher/tools/gen_font_catalogue.py`, which emits this
 * file and `apps/g_launcher/assets/fonts/catalogue.json` in the same run.
 *
 * ONE SOURCE ON PURPOSE. Two hand-kept lists drift, and the drift is silent in
 * the worst direction: the panel offers a family, the pack publishes, and the
 * device resolves a name nothing registered and paints Roboto. Nothing errors
 * anywhere, and you find out from a screenshot.
 */

export type FontCategory = 'sans-serif' | 'serif' | 'display' | 'monospace';

export interface FontEntry {
  family: string;
  category: FontCategory;
}

/**
 * Declared in `pubspec.yaml`, so they resolve on a cold boot with no network.
 *
 * ─── `UbuntuMono` IS NOT `Ubuntu Mono` ──────────────────────────────────────
 *
 * The first is this bundled family. The second is the Google Fonts name for a
 * different copy of the same typeface, which the device fetches at runtime.
 * They are different strings, they take different code paths, and swapping one
 * for the other would cost the trust-anchor distro its offline rendering for no
 * visible gain. The picker therefore lists bundled families separately and
 * never rewrites one spelling to the other.
 */
export const BUNDLED_FONTS: FontEntry[] = [
  { family: 'Ubuntu', category: 'sans-serif' },
  { family: 'UbuntuMono', category: 'monospace' },
];

/** Fetched on device through `google_fonts`. Sorted at generation time. */
export const GOOGLE_FONTS: FontEntry[] = [
  { family: "Anonymous Pro", category: "monospace" },
  { family: "Anton", category: "display" },
  { family: "Archivo", category: "sans-serif" },
  { family: "Assistant", category: "sans-serif" },
  { family: "Audiowide", category: "display" },
  { family: "Azeret Mono", category: "monospace" },
  { family: "Barlow", category: "sans-serif" },
  { family: "Bebas Neue", category: "display" },
  { family: "Bitter", category: "serif" },
  { family: "Cabin", category: "sans-serif" },
  { family: "Comfortaa", category: "display" },
  { family: "Cormorant Garamond", category: "serif" },
  { family: "Courier Prime", category: "monospace" },
  { family: "Cousine", category: "monospace" },
  { family: "Crimson Text", category: "serif" },
  { family: "DM Mono", category: "monospace" },
  { family: "DM Sans", category: "sans-serif" },
  { family: "Domine", category: "serif" },
  { family: "EB Garamond", category: "serif" },
  { family: "Exo 2", category: "sans-serif" },
  { family: "Figtree", category: "sans-serif" },
  { family: "Fira Code", category: "monospace" },
  { family: "Fira Mono", category: "monospace" },
  { family: "Fira Sans", category: "sans-serif" },
  { family: "Fredoka", category: "display" },
  { family: "Heebo", category: "sans-serif" },
  { family: "IBM Plex Mono", category: "monospace" },
  { family: "IBM Plex Sans", category: "sans-serif" },
  { family: "IBM Plex Serif", category: "serif" },
  { family: "Inconsolata", category: "monospace" },
  { family: "Inter", category: "sans-serif" },
  { family: "JetBrains Mono", category: "monospace" },
  { family: "Josefin Sans", category: "sans-serif" },
  { family: "Karla", category: "sans-serif" },
  { family: "Lato", category: "sans-serif" },
  { family: "Lexend", category: "sans-serif" },
  { family: "Libre Baskerville", category: "serif" },
  { family: "Lora", category: "serif" },
  { family: "Manrope", category: "sans-serif" },
  { family: "Martian Mono", category: "monospace" },
  { family: "Merriweather", category: "serif" },
  { family: "Montserrat", category: "sans-serif" },
  { family: "Mulish", category: "sans-serif" },
  { family: "Nanum Gothic Coding", category: "monospace" },
  { family: "Newsreader", category: "serif" },
  { family: "Noto Sans", category: "sans-serif" },
  { family: "Noto Sans Mono", category: "monospace" },
  { family: "Noto Serif", category: "serif" },
  { family: "Nunito", category: "sans-serif" },
  { family: "Nunito Sans", category: "sans-serif" },
  { family: "Open Sans", category: "sans-serif" },
  { family: "Orbitron", category: "display" },
  { family: "Oswald", category: "display" },
  { family: "Outfit", category: "sans-serif" },
  { family: "Overpass Mono", category: "monospace" },
  { family: "Oxygen", category: "sans-serif" },
  { family: "PT Sans", category: "sans-serif" },
  { family: "PT Serif", category: "serif" },
  { family: "Playfair Display", category: "serif" },
  { family: "Plus Jakarta Sans", category: "sans-serif" },
  { family: "Poppins", category: "sans-serif" },
  { family: "Public Sans", category: "sans-serif" },
  { family: "Quicksand", category: "sans-serif" },
  { family: "Raleway", category: "sans-serif" },
  { family: "Red Hat Display", category: "sans-serif" },
  { family: "Red Hat Mono", category: "monospace" },
  { family: "Righteous", category: "display" },
  { family: "Roboto", category: "sans-serif" },
  { family: "Roboto Mono", category: "monospace" },
  { family: "Roboto Slab", category: "serif" },
  { family: "Rubik", category: "sans-serif" },
  { family: "Share Tech Mono", category: "monospace" },
  { family: "Sora", category: "sans-serif" },
  { family: "Source Code Pro", category: "monospace" },
  { family: "Source Sans 3", category: "sans-serif" },
  { family: "Source Serif 4", category: "serif" },
  { family: "Space Grotesk", category: "sans-serif" },
  { family: "Space Mono", category: "monospace" },
  { family: "Spectral", category: "serif" },
  { family: "Titillium Web", category: "sans-serif" },
  { family: "Ubuntu", category: "sans-serif" },
  { family: "Ubuntu Mono", category: "monospace" },
  { family: "Urbanist", category: "sans-serif" },
  { family: "Work Sans", category: "sans-serif" },
  { family: "Zilla Slab", category: "serif" },
];

/** True for a family the device can resolve without the pack shipping files. */
export function isKnownFamily(family: string): boolean {
  const f = family.trim();
  if (!f) return false;
  return (
    BUNDLED_FONTS.some((e) => e.family === f) ||
    GOOGLE_FONTS.some((e) => e.family === f)
  );
}

/**
 * Fixed-advance, as far as the catalogue knows.
 *
 * A bundled family is answered from `BUNDLED_FONTS`, a catalogue family from its
 * category, and anything else returns TRUE rather than false. That default is
 * deliberate: an unknown family is one the pack ships itself, and the panel has
 * no way to inspect a TTF's advance widths. Guessing "not monospaced" there
 * would block a legitimate publish over something it cannot actually check.
 */
export function isMonospaceFamily(family: string): boolean {
  const f = family.trim();
  const bundled = BUNDLED_FONTS.find((e) => e.family === f);
  if (bundled) return bundled.category === 'monospace';
  const google = GOOGLE_FONTS.find((e) => e.family === f);
  if (google) return google.category === 'monospace';
  return true;
}

export function isBundledFamily(family: string): boolean {
  return BUNDLED_FONTS.some((e) => e.family === family.trim());
}

/**
 * What a picker shows.
 *
 * The mono list is filtered to fixed-advance families, and that gate is not
 * cosmetic: `terminal_screen.dart` derives the PTY column count by measuring a
 * run of glyphs in this family. A proportional face makes the count too
 * generous, the remote host formats for a width the screen does not have, and
 * its output wraps mid-field.
 *
 * `Ubuntu` is therefore absent from the mono list even though it is bundled.
 */
export function fontOptions(mono: boolean): {
  bundled: FontEntry[];
  google: FontEntry[];
} {
  const keep = (e: FontEntry) => (mono ? e.category === 'monospace' : true);
  return {
    bundled: BUNDLED_FONTS.filter(keep),
    google: GOOGLE_FONTS.filter(keep),
  };
}

/**
 * The sample drawn in each row.
 *
 * A display name answers its own question: seeing "Playfair Display" set in
 * Playfair Display is the whole decision. A monospace name answers almost
 * nothing, because what is being chosen there is whether zero is
 * distinguishable from capital O, and whether the family ligates. Fira Code and
 * Fira Mono are the same typeface except for the ligatures.
 */
export function fontSample(family: string, mono: boolean): string {
  return mono ? `${family}  0O1lI  => != ===` : family;
}

/**
 * The stylesheet that makes the previews real, built once for the whole list.
 *
 * Weights 400 and 700 only, matching what the device fetches, so a preview
 * cannot show a weight the phone will not have. Bundled families are excluded:
 * asking Google Fonts for `UbuntuMono` returns nothing, and the row falls back
 * to the panel's own face, which is the honest result for a family that lives
 * in the APK rather than on a CDN.
 */
export function googleFontsHref(): string {
  const families = GOOGLE_FONTS.map(
    (e) => `family=${encodeURIComponent(e.family).replace(/%20/g, '+')}:wght@400;700`,
  ).join('&');
  return `https://fonts.googleapis.com/css2?${families}&display=swap`;
}
