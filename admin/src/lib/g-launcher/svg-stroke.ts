'use client';

/**
 * STROKE WEIGHT FOR LINE ART, AT INTAKE.
 *
 * The sibling `svg-recolor.ts` has been missing since it was written. That file
 * answers "what colour is this set"; this one answers "how heavy is it", and
 * for a line set the second question decides whether the pack is usable at all.
 *
 * ─── WHY IT LIVES HERE AND NOT IN IconStyle ─────────────────────────────────
 *
 * The same argument `svg-recolor.ts` already makes, and it holds twice as hard
 * for weight. Adding a field to `IconStyle` touches eight places, and missing
 * `EffectiveTheme.iconCacheId` or `IconCache.fingerprint()` fails SILENTLY by
 * serving stale bitmaps. A stale bitmap from a missed colour field is obvious.
 * A stale bitmap from a missed WEIGHT field looks like art that is merely a
 * little thin, which nobody notices until it is published.
 *
 * Rewriting the SVG text before rasterising produces the same pixels, changes
 * no wire format, needs no Pigeon regeneration, and the bytes that ship are
 * already the right weight.
 *
 * ─── WHAT ARCTICONS ACTUALLY SHIPS, MEASURED ────────────────────────────────
 *
 * Every file is `viewBox="0 0 48 48"` with a single CSS rule of the form
 *
 *     .c{fill:none;stroke:#fff;stroke-linecap:round;stroke-linejoin:round;}
 *
 * and NO `stroke-width` anywhere. So every drawing inherits the SVG default of
 * 1, against a 48 unit box. That is the number this module exists to change.
 * Verified across the set: 22 of 22 sampled files parse as monotone under
 * `readPaint`, all declare `fill:none`, none declares a width.
 *
 * ─── THE ONE TRAP ───────────────────────────────────────────────────────────
 *
 * `stroke-linecap` and `stroke-linejoin` both begin with the word `stroke`. A
 * pattern of `/stroke/` matches them and a rewrite built on it corrupts the
 * caps. Every pattern below anchors on `stroke` followed by optional whitespace
 * and then a colon or an equals sign, which those two cannot satisfy.
 */

/** The box Arcticons and most line sets are authored against. */
export const LINE_BOX = 48;

/** The SVG default when no width is declared. Not a choice, a spec value. */
export const IMPLICIT_STROKE_WIDTH = 1;

/** Matches `stroke-width` as a CSS property or an XML attribute. */
const WIDTH_ANY = /\bstroke-width\s*[:=]/i;

/** A CSS declaration block that paints a stroke. Caps and joins cannot match. */
const STROKE_RULE = /(\{[^}]*\bstroke\s*:[^}]*)\}/g;

/** `stroke="#fff"` as an attribute on an element. */
const STROKE_ATTR = /\bstroke\s*=\s*"(?!none|transparent|inherit)[^"]*"/i;

export type StrokeReading =
  /** A width is declared somewhere. [value] is the first one found. */
  | { kind: 'declared'; value: number }
  /** Strokes are painted but no width is set, so the SVG default of 1 applies. */
  | { kind: 'implicit' }
  /** Nothing in the file paints a stroke. Filled art, or not art at all. */
  | { kind: 'none' };

/**
 * What weight this file draws at today.
 *
 * `implicit` is the interesting answer and the common one: it means the file is
 * line art relying on the spec default, which is exactly the case [setStroke]
 * handles and exactly the case that reads as "too thin" once composed at an
 * inset. `none` means the art is filled, and a caller mixing a `none` file into
 * a set of `implicit` ones is about to ship a solid glyph among outlines.
 */
export function readStroke(svg: string): StrokeReading {
  const declared = /\bstroke-width\s*[:=]\s*"?\s*([0-9]*\.?[0-9]+)/i.exec(svg);
  if (declared) return { kind: 'declared', value: parseFloat(declared[1]) };
  if (STROKE_RULE.test(svg) || STROKE_ATTR.test(svg)) {
    // STROKE_RULE carries the global flag, so `test` advanced lastIndex. Reset
    // it or the next call against a different string starts mid-way through and
    // misses a rule at the top of the file. This has bitten `readPaint` before.
    STROKE_RULE.lastIndex = 0;
    return { kind: 'implicit' };
  }
  STROKE_RULE.lastIndex = 0;
  return { kind: 'none' };
}

/** Is this file line art that a weight change would actually affect? */
export function isStrokeable(svg: string): boolean {
  return readStroke(svg).kind !== 'none';
}

/**
 * Set every stroke in [svg] to [width], in the file's own viewBox units.
 *
 * A file with NO stroke is returned unchanged rather than given one, for the
 * same reason `recolourSvg` returns a `multi` file untouched: injecting a
 * stroke onto filled art outlines every shape, which is damage, and doing it
 * silently across a set is damage nobody sees until publish.
 *
 * An already-declared width IS overwritten. Sets that declare their own weight
 * are declaring the weight the artist chose, and a builder control that
 * silently declined to move some of the set would be worse than one that moves
 * all of it: the author would see a grid where the slider works on most icons.
 */
export function setStroke(svg: string, width: number): string {
  const w = clampStroke(width);
  const reading = readStroke(svg);
  if (reading.kind === 'none') return svg;

  if (reading.kind === 'declared') {
    return svg
      .replace(/\bstroke-width\s*:\s*[^;"'}]+/gi, `stroke-width:${w}`)
      .replace(/\bstroke-width\s*=\s*"[^"]*"/gi, `stroke-width="${w}"`);
  }

  // Implicit. Append into every rule that already paints a stroke, so the
  // cascade lands on exactly the elements that were already being stroked.
  let out = svg.replace(STROKE_RULE, (full, body: string) =>
    WIDTH_ANY.test(body) ? full : `${body};stroke-width:${w};}`,
  );
  if (WIDTH_ANY.test(out)) return out;

  // No CSS rule carried it, so the stroke is an attribute. Put the width on the
  // root, where it inherits to every child that paints one.
  out = out.replace(/<svg\b/i, `<svg stroke-width="${w}"`);
  return out;
}

/**
 * Guard rails, not taste. Below 0.2 the line vanishes at any size; above 6 the
 * strokes of a 48 unit drawing merge into a blob and the icon is unreadable.
 * The builder's slider is much narrower than this; these are the bounds that
 * stop a bad value in a saved recipe from producing a set of solid squares.
 */
export const MIN_STROKE = 0.2;
export const MAX_STROKE = 6;

export function clampStroke(width: number): number {
  if (!Number.isFinite(width)) return IMPLICIT_STROKE_WIDTH;
  return Math.min(MAX_STROKE, Math.max(MIN_STROKE, Math.round(width * 100) / 100));
}

export type SetCharacter = 'stroked' | 'filled' | 'mixed' | 'unknown';

/**
 * Is this set drawn as outlines or as solid shapes.
 *
 * ─── THE MISTAKE THIS EXISTS TO CATCH ───────────────────────────────────────
 *
 * A set has 190 open outlines in it and one app has no drawing, so the obvious
 * move is to borrow a Simple Icons glyph, which is CC0 and takes one click.
 * Simple Icons are SOLID SHAPES. One filled glyph in a drawer of outlines does
 * not read as emphasis, it reads as a bug, and it is the kind that ships
 * because each individual decision was reasonable.
 *
 * No tool warns about this, because the file is valid, the licence is clean and
 * the drawing is correct. The only thing wrong with it is the company it keeps.
 *
 * ─── WHY A MAJORITY AND NOT A UNANIMOUS VOTE ────────────────────────────────
 *
 * Real sets are not pure. Arcticons has a handful of drawings that fill a
 * counter, and a pack can legitimately carry one brand mark among its outlines.
 * Requiring unanimity would report every real set as `mixed` and the warning
 * would never fire. Two thirds is enough to say what the set IS while leaving
 * room for the exceptions that were chosen deliberately.
 *
 * Raster sources return no vote at all rather than an abstention, because a PNG
 * has no strokes to read and guessing from its pixels would be a different and
 * much less reliable measurement pretending to be this one.
 */
export function setCharacter(svgTexts: string[]): SetCharacter {
  let stroked = 0;
  let filled = 0;
  for (const svg of svgTexts) {
    if (readStroke(svg).kind === 'none') filled += 1;
    else stroked += 1;
  }
  const total = stroked + filled;
  if (total === 0) return 'unknown';
  if (stroked / total >= 0.66) return 'stroked';
  if (filled / total >= 0.66) return 'filled';
  return 'mixed';
}

/**
 * Would adding [candidate] to a set of [character] look like a mistake.
 *
 * Returns the sentence to show, or null when it would not. A sentence rather
 * than a boolean because the caller must not have to invent the explanation,
 * and a warning whose reason is written at the call site is a warning that
 * drifts from the rule that produced it.
 */
export function mismatchWarning(
  character: SetCharacter,
  candidate: string,
): string | null {
  if (character === 'unknown' || character === 'mixed') return null;
  const candidateFilled = readStroke(candidate).kind === 'none';
  if (character === 'stroked' && candidateFilled) {
    return 'This is a solid shape and the rest of the set is open outlines. One filled icon in a drawer of line art reads as a mistake rather than as a highlight.';
  }
  if (character === 'filled' && !candidateFilled) {
    return 'This is an open outline and the rest of the set is solid shapes. It will read as lighter than everything around it at every size.';
  }
  return null;
}

/**
 * How many DEVICE pixels a stroke of [width] actually occupies.
 *
 * ─── THE NUMBER THAT DECIDES WHETHER A LINE PACK WORKS ──────────────────────
 *
 * A weight is meaningless on its own. It is a fraction of a viewBox, and what
 * reaches the screen depends on the grid size, the display density and how much
 * the composer inset the art. Those three live in different files and no single
 * screen ever showed their product, which is how a pack can look correct in a
 * 192px preview on a laptop and read washed out on the phone it was made for.
 *
 * Worked, for a Tecno Spark 10 at dpr 2.0 with a 48dp grid icon:
 *
 *     device      = 48 * 2.0            =  96 px
 *     glyph       = 96 * (1 - 0.34)     =  63.4 px
 *     stroke      = (1 / 48) * 63.4     =  1.32 px
 *
 * Against the same set at inset 0.06 and weight 1.7: 3.20 px. The first is a
 * washed line on a budget panel and the second holds. Same art, same file.
 */
export function strokeDevicePx(opts: {
  width: number;
  /** Icon size in device pixels: grid dp times display density. */
  devicePx: number;
  /** Composer inset, 0 to 1. */
  inset: number;
  /** viewBox extent the art is authored against. */
  box?: number;
}): number {
  const box = opts.box ?? LINE_BOX;
  const glyph = opts.devicePx * (1 - Math.min(0.9, Math.max(0, opts.inset)));
  return (opts.width / box) * glyph;
}

export type StrokeVerdict = 'subpixel' | 'thin' | 'crisp';

/**
 * Below 1 device pixel the rasteriser has no whole pixel to put ink in and
 * antialiases the line into grey, which reads as a faded icon rather than a
 * thin one. Between 1 and 1.6 it draws but loses its weight at arm's length on
 * an OLED. The thresholds are deliberately generous: this gates publish, and a
 * gate that fires on art that would have been fine is a gate people route
 * around.
 */
export function strokeVerdict(devicePx: number): StrokeVerdict {
  if (devicePx < 1) return 'subpixel';
  if (devicePx < 1.6) return 'thin';
  return 'crisp';
}

/**
 * Give [svg] an intrinsic width and height, in pixels.
 *
 * ─── WITHOUT THIS EVERY VECTOR RASTERISES AT 150 PIXELS ─────────────────────
 *
 * An SVG carrying only a viewBox has no intrinsic size, so `createImageBitmap`
 * falls back to the CSS default object size of 300x150 constrained to the
 * viewBox ratio. For a square box that is 150x150, regardless of what the
 * caller intends to draw it at. `composeIcon` then scales that 150px raster to
 * fill its room, and every pixel above 150 is an upscale of a vector that could
 * have been rendered sharp at any size.
 *
 * Arcticons files carry no width. So do the ones `glyphToBlob` builds from
 * Simple Icons. This is why a composed pack looks softer than the same art
 * rendered by an installed icon pack, where Android rasterises the
 * VectorDrawable at exactly the size the launcher asked for.
 *
 * Exported from THIS file rather than from `svg-recolor.ts` because it is the
 * same class of intake rewrite and the two are always applied together.
 */
export function withIntrinsicSize(svg: string, px: number): string {
  const size = Math.max(1, Math.round(px));
  const open = /<svg\b[^>]*>/i.exec(svg);
  if (!open) return svg;

  let tag = open[0];
  tag = /\swidth\s*=/i.test(tag)
    ? tag.replace(/\swidth\s*=\s*"[^"]*"/i, ` width="${size}"`)
    : tag.replace(/<svg\b/i, `<svg width="${size}"`);
  tag = /\sheight\s*=/i.test(tag)
    ? tag.replace(/\sheight\s*=\s*"[^"]*"/i, ` height="${size}"`)
    : tag.replace(/<svg\b/i, `<svg height="${size}"`);

  return svg.slice(0, open.index) + tag + svg.slice(open.index + open[0].length);
}
