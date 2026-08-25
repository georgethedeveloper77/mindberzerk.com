'use client';

import { setStroke, withIntrinsicSize } from '@/lib/g-launcher/svg-stroke';

/**
 * COMPOSE AN ICON: a plate you define, art you supply, one PNG you own.
 *
 * ## Why this exists
 *
 * Eleven drafted distros have no icon pack, and the reason is not effort, it is
 * licensing. Kali's set derives from Vimix and Flat-Remix, Garuda's from
 * BeautyLine, Pop ships its own; all GPL-3 or CC-BY-SA, and none of them can
 * sit inside something a Play SKU unlocks. Hunting for a permissive equivalent
 * is looking for a thing that mostly does not exist.
 *
 * Composing sidesteps the whole problem. Take art you are allowed to use, put
 * it on a plate you defined, and the output is an original raster that is
 * yours. The distro's identity lives in the plate, which is the part that
 * actually reads as Kali or Garuda at 48dp, and the foreground is doing far
 * less work than it appears to.
 *
 * ## What this is NOT
 *
 * NOT a licence launderer. Compositing a GPL glyph onto a plate produces a
 * derivative work of a GPL glyph. `expandPicked` already refuses marked SVGs
 * and the attestation checkbox already covers the rest; this changes neither,
 * and the same rules apply to whatever is handed to [composeIcon].
 *
 * NOT the device's generator. `IconRenderer` composes at runtime from the app's
 * own artwork and needs no files at all. This produces HERO art, which is the
 * layer above it: drawn once here, shipped as PNGs, and used where it exists.
 *
 * ## Why a separate module from pack-preview.ts
 *
 * That one composites SIX FINISHED ICONS into a shelf card. This composites ONE
 * icon from its parts. They share a canvas and nothing else: different inputs,
 * different output, different moment in the pipeline. Folding them together
 * would give one function two reasons to change, and the shelf preview is the
 * more load-bearing of the two because it ships inside the signed manifest.
 */

/**
 * The square every drawing is composed into.
 *
 * ─── RAISED FROM 192, AND THE OLD NUMBER WAS BELOW THE DEVICE ───────────────
 *
 * `app_icon.dart` asks for `size * devicePixelRatio`, and `IconSizing` lets a
 * grid icon reach 64dp before a theme's `iconScale` is applied. On a Galaxy S22
 * at dpr 3.0 a 52dp icon is 156 device pixels; at 64dp it is 192, exactly at
 * the old ceiling, and past it with any `iconScale` above 1.0. Authoring at 192
 * therefore meant the phone was upscaling a raster on the devices this launcher
 * is tested on, which shows on line art before anything else.
 *
 * 256 sits above every grid size these devices ask for, so the phone always
 * downscales, which is the direction that stays sharp. Measured cost across 61
 * composed Arcticons drawings at 256 on a plate: mean 11.8 KB per PNG, so a
 * 193-icon pack is about 2.3 MB and six distro packs about 13.6 MB on R2.
 *
 * PACKS ALREADY PUBLISHED ARE UNAFFECTED. Their PNGs are whatever size they
 * were composed at and the launcher scales them as it always has. Only newly
 * composed art changes, so this is safe to land without touching the CDN.
 */
export const ICON_SIZE = 256;

export type PlateKind = 'colour' | 'gradient' | 'image' | 'none';

export interface PlateSpec {
  kind: PlateKind;
  /** Solid fill, or the gradient's first stop. */
  colour: string;
  /** Gradient's second stop. Ignored unless kind is 'gradient'. */
  colour2?: string;
  /** Degrees, clockwise from the top. Ignored unless kind is 'gradient'. */
  angle?: number;
  /** Background art. Ignored unless kind is 'image'. */
  image?: Blob | null;
}

export interface ComposeSpec {
  plate: PlateSpec;
  /**
   * One of ICON_TREATMENTS. Only the plate is clipped by it; the foreground is
   * drawn inside and is never clipped, because art that reaches the edge of its
   * inset is art the author meant to reach there.
   */
  treatment: string;
  /** 0 to 1, as a fraction of the icon. Ignored for circle and square. */
  cornerRadius: number;
  /**
   * How much of the icon the plate leaves for the foreground, 0 to 1.
   *
   * 0.34 means the art occupies the middle 66%, which is roughly Android's own
   * adaptive-icon safe zone. Below about 0.2 the art starts colliding with the
   * corner radius on a circle.
   */
  inset: number;
  /**
   * Stroke weight for line art, in the source viewBox's own units, or null to
   * draw at whatever weight the file declares.
   *
   * ─── WHY THIS IS A COMPOSE SETTING AND NOT AN IconStyle FIELD ─────────────
   *
   * The same argument `svg-recolor.ts` makes for colour, and it is stronger
   * here. A weight is a property of the ART, so it can be baked before the
   * bytes are written and never has to reach the device. Putting it in
   * `IconStyle` would mean the eight-place ritual plus a Pigeon wire change,
   * and a missed `iconCacheId` or `fingerprint()` fails silently by serving
   * stale bitmaps that look like art which is merely a little thin.
   *
   * ─── AND WHY IT MATTERS AT ALL ───────────────────────────────────────────
   *
   * Arcticons, and every line set built like it, declares no `stroke-width`,
   * so all 13,623 drawings inherit the SVG default of 1 against a 48 unit box.
   * Composed at the default inset below, that reaches a Tecno Spark 10 as a
   * 1.32 device pixel line, which antialiases to grey rather than drawing. The
   * same art at weight 1.7 and inset 0.06 lands at 3.20 px and holds.
   *
   * Ignored for raster art, which has no strokes to set.
   */
  strokeWidth?: number | null;
  /**
   * Recolour the foreground to this, keeping its alpha, or null to draw the art
   * as it is.
   *
   * A SILHOUETTE, and that is the point: a distro icon set reads as one set
   * because everything in it is the same colour on the same plate. Handing this
   * a full-colour logo and a tint produces a flat shape, which is correct and
   * is what people mean by a monochrome pack.
   */
  tint?: string | null;
}

/**
 * ─── THE INSET WAS 0.34 AND THAT IS TWO INSETS FOR LINE ART ─────────────────
 *
 * 0.34 approximates Android's adaptive-icon safe zone, which is the right
 * default for a full-bleed logo that would otherwise touch the plate edge. It
 * is the wrong default for a line set, because a line set has already been
 * drawn with its own margin: measured across Arcticons, the art sits roughly
 * 9% inside its 48 unit box on every side. Composing at 0.34 insets a second
 * time, so the drawing occupies about 44% of the tile against an installed
 * pack that draws it full bleed, and the strokes thin in proportion.
 *
 * 0.12 is the compromise: enough to keep art clear of a circle treatment's
 * corner, close enough to how the same drawing renders when Android rasterises
 * it from a VectorDrawable. A logo that genuinely needs the safe zone can still
 * ask for it, which is the direction that costs one slider rather than a set
 * that ships thin.
 */
export const DEFAULT_COMPOSE: ComposeSpec = {
  plate: { kind: 'colour', colour: '#16191D' },
  treatment: 'roundedSquare',
  cornerRadius: 0.22,
  inset: 0.12,
  strokeWidth: null,
  tint: null,
};

/**
 * Trace the plate's outline into [ctx].
 *
 * Five of the six treatments are a rounded rectangle with a different radius.
 * `teardrop` is three round corners and one square one, drawn explicitly
 * because no radius expresses it. `original` has no plate at all, which the
 * caller handles by not calling this.
 */
function platePath(
  ctx: CanvasRenderingContext2D,
  size: number,
  treatment: string,
  cornerRadius: number,
): void {
  const r = Math.max(0, Math.min(0.5, cornerRadius)) * size;
  ctx.beginPath();

  if (treatment === 'circle') {
    ctx.arc(size / 2, size / 2, size / 2, 0, Math.PI * 2);
    return;
  }
  if (treatment === 'square') {
    ctx.rect(0, 0, size, size);
    return;
  }

  // A squircle is a superellipse, and approximating it with an oversized radius
  // is wrong in a way that shows at this size: the straight run between corners
  // disappears. Capping at 36% keeps the flat edge that distinguishes it from a
  // circle, which is the entire visual difference between the two treatments.
  const rr =
    treatment === 'squircle' ? Math.min(size * 0.36, r * 1.5) : r;

  if (treatment === 'teardrop') {
    ctx.moveTo(rr, 0);
    ctx.lineTo(size - rr, 0);
    ctx.quadraticCurveTo(size, 0, size, rr);
    ctx.lineTo(size, size - rr);
    ctx.quadraticCurveTo(size, size, size - rr, size);
    ctx.lineTo(rr, size);
    ctx.quadraticCurveTo(0, size, 0, size - rr);
    // The square corner, top left. No curve back to the start.
    ctx.lineTo(0, 0);
    ctx.closePath();
    return;
  }

  ctx.moveTo(rr, 0);
  ctx.lineTo(size - rr, 0);
  ctx.quadraticCurveTo(size, 0, size, rr);
  ctx.lineTo(size, size - rr);
  ctx.quadraticCurveTo(size, size, size - rr, size);
  ctx.lineTo(rr, size);
  ctx.quadraticCurveTo(0, size, 0, size - rr);
  ctx.lineTo(0, rr);
  ctx.quadraticCurveTo(0, 0, rr, 0);
  ctx.closePath();
}

/** Recolour a bitmap to [tint], keeping its alpha. */
function tinted(bmp: ImageBitmap, tint: string, w: number, h: number): HTMLCanvasElement | null {
  const c = document.createElement('canvas');
  c.width = w;
  c.height = h;
  const g = c.getContext('2d');
  if (!g) return null;
  g.drawImage(bmp, 0, 0, w, h);
  // `source-in` keeps the destination's alpha and takes the source's colour,
  // which is the one operation that turns art into a silhouette without
  // touching its edges. Doing it by pixel arithmetic instead would lose the
  // antialiasing that makes a 192px icon look drawn rather than cut out.
  g.globalCompositeOperation = 'source-in';
  g.fillStyle = tint;
  g.fillRect(0, 0, w, h);
  return c;
}

/**
 * Decode [art] at [px], giving a vector an intrinsic size first.
 *
 * `withIntrinsicSize` lives in `svg-stroke.ts` beside the other intake
 * rewrites, so there is one implementation of "make this SVG rasterise at a
 * chosen size" rather than a copy here that drifts from it.
 *
 * A blob that claims to be SVG but cannot be read as text falls through to a
 * plain decode rather than throwing, on the same rule as everything else in
 * this file: one bad input costs its own icon, never the batch.
 */
async function bitmapAtSize(
  art: Blob,
  px: number,
  strokeWidth?: number | null,
): Promise<ImageBitmap> {
  if (art.type !== 'image/svg+xml') return await createImageBitmap(art);
  try {
    let text = await art.text();
    // Weight BEFORE size. `setStroke` reads the file's own declarations and
    // `withIntrinsicSize` rewrites the root element; doing it the other way
    // round works today and would break the moment either learns to care about
    // the root's attributes, which is the kind of ordering dependency worth
    // spending one comment to remove.
    if (strokeWidth != null) text = setStroke(text, strokeWidth);
    const sized = withIntrinsicSize(text, Math.max(1, Math.round(px)));
    return await createImageBitmap(new Blob([sized], { type: 'image/svg+xml' }));
  } catch {
    return await createImageBitmap(art);
  }
}

/**
 * Compose one icon. Returns null when the canvas is unavailable.
 *
 * [foreground] may be null: a plate with nothing on it is a legitimate result
 * while an author is choosing colours, and refusing would make the preview
 * blank until every field is filled.
 */
export async function composeIcon(
  spec: ComposeSpec,
  foreground: Blob | null,
  size: number = ICON_SIZE,
): Promise<Blob | null> {
  const canvas = document.createElement('canvas');
  canvas.width = size;
  canvas.height = size;
  const ctx = canvas.getContext('2d');
  if (!ctx) return null;

  // ── the plate ────────────────────────────────────────────────────────────
  if (spec.plate.kind !== 'none') {
    ctx.save();
    platePath(ctx, size, spec.treatment, spec.cornerRadius);
    ctx.clip();

    if (spec.plate.kind === 'gradient') {
      // Degrees clockwise from the top, matching `gradientAngle` in theme.json
      // rather than canvas's own convention, so a number that looks right in
      // the theme builder looks right here.
      const rad = ((spec.plate.angle ?? 135) - 90) * (Math.PI / 180);
      const half = size / 2;
      const dx = Math.cos(rad) * half;
      const dy = Math.sin(rad) * half;
      const g = ctx.createLinearGradient(half - dx, half - dy, half + dx, half + dy);
      g.addColorStop(0, spec.plate.colour);
      g.addColorStop(1, spec.plate.colour2 ?? spec.plate.colour);
      ctx.fillStyle = g;
      ctx.fillRect(0, 0, size, size);
    } else if (spec.plate.kind === 'image' && spec.plate.image) {
      try {
        const bmp = await createImageBitmap(spec.plate.image);
        // COVER, not contain. A plate with letterboxing is not a plate, and a
        // background image is chosen for its texture rather than its framing.
        const s = Math.max(size / bmp.width, size / bmp.height);
        const dw = bmp.width * s;
        const dh = bmp.height * s;
        ctx.drawImage(bmp, (size - dw) / 2, (size - dh) / 2, dw, dh);
        bmp.close();
      } catch {
        // An undecodable background leaves the plate colour showing rather than
        // a hole, so the icon is still shippable and the fault is visible.
        ctx.fillStyle = spec.plate.colour;
        ctx.fillRect(0, 0, size, size);
      }
    } else {
      ctx.fillStyle = spec.plate.colour;
      ctx.fillRect(0, 0, size, size);
    }

    ctx.restore();
  }

  // ── the foreground ───────────────────────────────────────────────────────
  if (foreground) {
    try {
      const room = size * (1 - Math.max(0, Math.min(0.9, spec.inset)));
      // RASTERISE AT THE ROOM, NOT AT THE SVG'S DEFAULT.
      //
      // A vector handed straight to `createImageBitmap` with no width or height
      // is sized by the CSS default object size, which for a square viewBox is
      // 150x150 no matter what it is about to be drawn at. Every pixel above
      // that was an upscale of art that could have been rendered sharp, and it
      // is the difference between this pipeline and an installed icon pack,
      // where Android rasterises the VectorDrawable at the requested size.
      //
      // Raster input is passed through untouched: a PNG has a real intrinsic
      // size and re-wrapping it would be meaningless.
      const bmp = await bitmapAtSize(foreground, room, spec.strokeWidth);
      const s = Math.min(room / bmp.width, room / bmp.height);
      const dw = bmp.width * s;
      const dh = bmp.height * s;
      const x = (size - dw) / 2;
      const y = (size - dh) / 2;

      if (spec.tint) {
        const t = tinted(bmp, spec.tint, Math.round(dw), Math.round(dh));
        if (t) ctx.drawImage(t, x, y);
        else ctx.drawImage(bmp, x, y, dw, dh);
      } else {
        ctx.drawImage(bmp, x, y, dw, dh);
      }
      bmp.close();
    } catch {
      // Same rule as the shelf preview: one undecodable image leaves its icon
      // as a bare plate rather than sinking the batch.
    }
  }

  return await new Promise<Blob | null>((resolve) =>
    canvas.toBlob((b) => resolve(b), 'image/png'),
  );
}

/**
 * Recompose every entry against one style. The "style all" bar.
 *
 * SOURCE ART IN, FINISHED ART OUT, and the caller keeps the sources. Composing
 * from already-composed output would bake each pass onto the last, so the third
 * time someone nudged the tint they would be tinting a tinted plate. The
 * builder therefore has to hold the original upload per entry for as long as
 * the style is editable, which is the one thing this module cannot do for it.
 */
export async function composeAll(
  spec: ComposeSpec,
  sources: { key: string; art: Blob | null }[],
  size: number = ICON_SIZE,
): Promise<{ key: string; png: Blob | null }[]> {
  const out: { key: string; png: Blob | null }[] = [];
  for (const s of sources) {
    out.push({ key: s.key, png: await composeIcon(spec, s.art, size) });
  }
  return out;
}
