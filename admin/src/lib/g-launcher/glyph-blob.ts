'use client';

/**
 * A GLYPH, AS SOMETHING [composeIcon] CAN DRAW.
 *
 * `composeIcon` takes a Blob, because that is what an upload is and it keeps
 * the composer indifferent to where art came from. A Simple Icons entry is a
 * path string, so it has to become one, and the wrapping is a place where two
 * numbers can silently disagree.
 *
 * ─── THE 24 IS NOT ARBITRARY AND MUST NOT BE RETYPED ────────────────────────
 *
 * Every icon in the set is authored against a 24 unit square and none of them
 * carries its own viewBox. Wrap it in anything else and the art is cropped or
 * floats in space, and because the composer then scales to fit its inset, the
 * result looks plausible rather than obviously wrong. That is the failure worth
 * guarding: an icon that is 8% too small in a pack of forty reads as sloppy
 * drawing rather than as a bug.
 *
 * ─── AND THE FILL IS THE BRAND HEX ──────────────────────────────────────────
 *
 * THIS WAS `currentColor` AND EVERY COMPOSED ICON CAME OUT BLANK.
 *
 * The argument for it was that `composeIcon` owns colour, so the source should
 * stay neutral and let `tint` decide. That is right about ownership and wrong
 * about rendering, in two ways at once:
 *
 *   1. `currentColor` needs a CSS context to resolve against. An SVG Blob
 *      handed to `createImageBitmap` has none, so the keyword resolves to
 *      nothing rather than to a colour, and the path is never painted.
 *   2. Even where it does resolve, the initial value is BLACK, and these packs
 *      are built on dark plates. A black glyph on #16191D is invisible, so the
 *      "safe fallback" was the one colour guaranteed not to show.
 *
 * The brand hex is what the picker already displays, so what lands in the pack
 * now matches what was clicked. Ownership is unchanged: set a tint and
 * `composeIcon` recolours the whole thing to a silhouette regardless of what
 * came in, so this fill only matters when no tint is set, which is exactly the
 * case where the author has asked for the art as it is.
 */

/** The box every Simple Icons path is drawn against. One copy. */
const GLYPH_BOX = 24;

export interface GlyphLite {
  slug: string;
  title: string;
  hex: string;
  path: string;
}

/**
 * An SVG Blob for [glyph], ready for `composeIcon`.
 *
 * [colour] paints the path directly and is for the PICKER's own thumbnails,
 * where there is no composer to tint them. Leave it out for anything headed
 * into a pack.
 */
export function glyphToBlob(glyph: GlyphLite, colour?: string): Blob {
  // The brand hex, unless the caller names one. `hex` is stored without the
  // leading hash by the package, which is the kind of detail that silently
  // produces a fill of "25D366" and no paint at all.
  const fill = colour ?? `#${glyph.hex}`;
  const svg =
    `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${GLYPH_BOX} ${GLYPH_BOX}">` +
    `<title>${escapeXml(glyph.title)}</title>` +
    `<path d="${glyph.path}" fill="${fill}"/>` +
    `</svg>`;
  return new Blob([svg], { type: 'image/svg+xml' });
}

/** A data URL, for an `img` tag in the picker without minting object URLs. */
export function glyphToDataUrl(glyph: GlyphLite, colour: string): string {
  const svg =
    `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${GLYPH_BOX} ${GLYPH_BOX}">` +
    `<path d="${glyph.path}" fill="${colour}"/>` +
    `</svg>`;
  // encodeURIComponent rather than btoa: the path data is ASCII but the title
  // is not always, and a base64 of a UTF-8 string needs a byte dance that this
  // avoids entirely. Object URLs would work too and would need revoking, which
  // is a leak waiting for a list that re-renders on every keystroke.
  return `data:image/svg+xml,${encodeURIComponent(svg)}`;
}

/**
 * Fetch matches from the search route.
 *
 * Returns an empty list on any failure rather than throwing. A picker that
 * shows nothing is a picker with no results; a picker that throws takes the
 * builder down mid-edit, and there is unsaved work on that screen.
 */
export async function fetchGlyphs(query: string): Promise<GlyphLite[]> {
  try {
    const res = await fetch(
      `/api/icons/glyphs?q=${encodeURIComponent(query)}`,
      { cache: 'no-store' },
    );
    if (!res.ok) return [];
    const json = (await res.json()) as { glyphs?: GlyphLite[] };
    return json.glyphs ?? [];
  } catch {
    return [];
  }
}

function escapeXml(s: string): string {
  return s
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}
