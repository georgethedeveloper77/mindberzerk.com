'use client';

/**
 * RECOLOURING MONOTONE LINE ART, AT INTAKE.
 *
 * A line-icon set is one colour repeated across every file. That is what makes
 * it a set, and it is also what makes it retargetable: the same fifteen thousand
 * drawings are a Kali pack in Kali's blue and a Pop pack in Pop's teal, and the
 * only difference is a hex.
 *
 * ─── WHY THIS RUNS AT INTAKE AND NOT AT RENDER ──────────────────────────────
 *
 * The device could tint. `IconStyle` could carry a colour, `IconRenderer.kt`
 * could apply it, and the launcher would recolour on the fly. That is the wrong
 * place, for a reason specific to this codebase: adding a field to `IconStyle`
 * touches eight files, and missing `EffectiveTheme.iconCacheId` or
 * `IconCache.fingerprint()` fails SILENTLY by serving stale bitmaps that look
 * exactly like an unwired field. All of that risk, for a value that never
 * varies per device.
 *
 * Recolouring the SVG text before it is rasterised produces the same pixels,
 * changes no wire format, needs no Pigeon regeneration, and cannot serve a
 * stale cache because the bytes that ship are already the right colour. The art
 * is drawn as authored, which is what `masked: false` already promises.
 *
 * ─── WHAT COUNTS AS MONOTONE ────────────────────────────────────────────────
 *
 * One distinct colour across every paint attribute in the file. `none` is not a
 * colour and is never rewritten: a line icon is `fill="none" stroke="#fff"`, and
 * a recolour that filled the `none` would turn every outline into a solid blob.
 * `currentColor` counts as monotone and is replaced, because it is a deferred
 * single colour and rasterising it without substitution yields black.
 *
 * A file with two or more real colours is NOT monotone and is left untouched
 * rather than flattened. Flattening a two-tone icon to one colour destroys it,
 * and doing that silently across a set is exactly the kind of damage nobody
 * notices until it is published.
 *
 * ─── AND THE FILES THAT DECLARE NO COLOUR AT ALL ────────────────────────────
 *
 * Some sets ship `<path d="..."/>` with no paint attributes, relying on the
 * consumer to tint. Those are reported as `implicit` rather than `monotone`.
 * They CAN be coloured, but only by injecting a paint the author never wrote,
 * so it is a separate answer and the caller decides whether to offer it.
 */

/** Attribute and CSS property names that carry a paint value. */
const PAINT = ['fill', 'stroke', 'stop-color', 'flood-color', 'lighting-color'];

const PAINT_ATTR = new RegExp(`\\b(${PAINT.join('|')})\\s*=\\s*"([^"]*)"`, 'gi');
const PAINT_PROP = new RegExp(`\\b(${PAINT.join('|')})\\s*:\\s*([^;"'}]+)`, 'gi');

/** Values that are not a colour and must never be rewritten. */
function isNonPaint(value: string): boolean {
  const v = value.trim().toLowerCase();
  return (
    v === '' ||
    v === 'none' ||
    v === 'transparent' ||
    v === 'inherit' ||
    v.startsWith('url(')
  );
}

/** Canonical form so `#FFF`, `#ffffff` and `white` are recognised as one colour. */
function canonical(value: string): string {
  let v = value.trim().toLowerCase();
  if (v === 'white') v = '#ffffff';
  if (v === 'black') v = '#000000';
  const short = /^#([0-9a-f])([0-9a-f])([0-9a-f])$/.exec(v);
  if (short) return `#${short[1]}${short[1]}${short[2]}${short[2]}${short[3]}${short[3]}`;
  // Drop an alpha byte: `#ffffffff` and `#ffffff` are the same ink, and a set
  // that mixes the two is still one colour.
  const long = /^#([0-9a-f]{6})[0-9a-f]{2}$/.exec(v);
  if (long) return `#${long[1]}`;
  return v;
}

export type SvgPaint =
  /** Exactly one colour across the whole file. Safe to recolour. */
  | { kind: 'monotone'; color: string }
  /** No paint declared anywhere. Colourable only by injecting one. */
  | { kind: 'implicit' }
  /** Two or more colours. Left alone. */
  | { kind: 'multi'; colors: string[] }
  /** Not an SVG, or unreadable. */
  | { kind: 'unknown' };

/** What colours this SVG declares. */
export function readPaint(svg: string): SvgPaint {
  if (!/<svg[\s>]/i.test(svg)) return { kind: 'unknown' };

  const found = new Set<string>();
  let hasCurrent = false;

  const collect = (re: RegExp) => {
    re.lastIndex = 0;
    let m: RegExpExecArray | null;
    while ((m = re.exec(svg)) !== null) {
      const value = m[2];
      if (isNonPaint(value)) continue;
      if (value.trim().toLowerCase() === 'currentcolor') {
        hasCurrent = true;
        continue;
      }
      found.add(canonical(value));
    }
  };
  collect(PAINT_ATTR);
  collect(PAINT_PROP);

  if (found.size === 0) {
    // `currentColor` alone is a deferred single colour, which is monotone in
    // every sense that matters here.
    return hasCurrent ? { kind: 'monotone', color: 'currentColor' } : { kind: 'implicit' };
  }
  // One declared colour is monotone whether or not `currentColor` also appears:
  // `currentColor` inherits the same single ink, so the file still has one.
  // These were two separate branches returning the same value, which read as if
  // the cases differed and invited someone to "fix" one of them.
  if (found.size === 1) return { kind: 'monotone', color: [...found][0] };
  return { kind: 'multi', colors: [...found] };
}

/** Can this file take a new colour without being damaged? */
export function isRecolourable(svg: string): boolean {
  const paint = readPaint(svg);
  return paint.kind === 'monotone' || paint.kind === 'implicit';
}

/**
 * Rewrite every declared paint to [hex].
 *
 * `none` survives untouched, which is the single most important line in this
 * file: it is what keeps an outline an outline.
 *
 * A `multi` file is returned UNCHANGED rather than flattened, so this is safe
 * to map across a whole set without inspecting each result. The caller learns
 * what happened from `readPaint`, not from a silent difference in the output.
 */
export function recolourSvg(svg: string, hex: string): string {
  const paint = readPaint(svg);
  if (paint.kind === 'multi' || paint.kind === 'unknown') return svg;

  if (paint.kind === 'implicit') {
    // Nothing declares a colour, so one is injected on the root element where
    // it inherits to every child. `fill` is deliberately left alone: a shape
    // with no paint attributes defaults to a BLACK FILL, and setting stroke
    // alone on such a file would produce a filled blob with an outline. Setting
    // fill is what actually colours it.
    return svg.replace(/<svg\b/i, `<svg fill="${hex}"`);
  }

  const swap = (_full: string, prop: string, value: string, quoted: boolean) => {
    if (isNonPaint(value)) return quoted ? `${prop}="${value}"` : `${prop}:${value}`;
    return quoted ? `${prop}="${hex}"` : `${prop}:${hex}`;
  };

  return svg
    .replace(PAINT_ATTR, (full, prop: string, value: string) => swap(full, prop, value, true))
    .replace(PAINT_PROP, (full, prop: string, value: string) => swap(full, prop, value, false));
}

/**
 * Recolour raw bytes, returning bytes.
 *
 * Non-SVG input is passed straight back. Recolouring a PNG would mean decoding,
 * walking pixels and re-encoding, which is a different and much heavier
 * operation, and monotone raster line sets are rare enough that pretending to
 * support them would be worse than declining. The builder only offers the
 * control when the intake actually found recolourable SVGs.
 */
export function recolourBytes(bytes: Uint8Array, mime: string, hex: string): Uint8Array {
  if (mime !== 'image/svg+xml') return bytes;
  const text = new TextDecoder().decode(bytes);
  const out = recolourSvg(text, hex);
  if (out === text) return bytes;
  return new TextEncoder().encode(out);
}

/** A six-digit hex, or null. Used to gate the control rather than to sanitise. */
export function normaliseHex(value: string): string | null {
  const v = value.trim().toLowerCase();
  const short = /^#?([0-9a-f]{3})$/.exec(v);
  if (short) {
    const [r, g, b] = short[1].split('');
    return `#${r}${r}${g}${g}${b}${b}`;
  }
  const long = /^#?([0-9a-f]{6})$/.exec(v);
  return long ? `#${long[1]}` : null;
}
