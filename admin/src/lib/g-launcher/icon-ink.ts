'use client';

import { setStroke, withIntrinsicSize } from '@/lib/g-launcher/svg-stroke';
import { recolourSvg } from '@/lib/g-launcher/svg-recolor';

/**
 * OPTICAL WEIGHT: "do these look like one set", answered by measurement.
 *
 * ─── THE PROBLEM THIS EXISTS FOR ────────────────────────────────────────────
 *
 * A pack of 193 icons reads as a set when every drawing carries roughly the
 * same amount of ink. One glyph that is half again as heavy as its neighbours
 * does not look like emphasis, it looks like a mistake, and it is the single
 * thing that separates a pack somebody paid for from a pack somebody assembled.
 *
 * The eye is bad at this. Scanning 193 tiles, a 45% overweight icon reads as
 * "slightly off" and gets forgiven, forty times, until the whole set feels
 * cheap and no one can point at why. A canvas is not bad at it: the alpha
 * channel of a glyph rendered with no plate IS the ink, exactly.
 *
 * ─── MEASURED, ON THE REAL PIPELINE ─────────────────────────────────────────
 *
 * 61 Arcticons files rendered at weight 1.7, inset 0.06:
 *
 *     median coverage   14.53%
 *     MAD                1.99
 *     range              8.20% to 21.18%
 *     flagged at 3.2 MAD    2 of 61  (Duolingo +46%, Calculator +44%)
 *
 * Two of sixty-one is a signal. Forty would have been noise and zero would have
 * been decoration, which is the test any threshold like this has to pass.
 *
 * ─── WHY MEDIAN AND MAD, NOT MEAN AND SIGMA ─────────────────────────────────
 *
 * Outliers are what we are looking for, and mean and standard deviation are
 * both dragged by the very values they are supposed to expose. Two heavy icons
 * in a set of sixty pull the mean up and inflate sigma, so the threshold widens
 * to accommodate them and they stop being outliers. Median and median absolute
 * deviation do not move, so a set with one bad icon and a set with none produce
 * the same centre and the bad one stands out of it.
 */

/** How big a glyph is rendered for measurement. Not the pack's output size. */
const PROBE_PX = 72;

/**
 * Alpha below this is antialiasing spill rather than ink.
 *
 * Zero would work and would be slightly wrong in a way that matters at this
 * scale: a 48 unit drawing at 72px has a lot of edge relative to its area, so
 * counting every partially-covered pixel at full value inflates thin drawings
 * more than thick ones, which is backwards. Summing the alpha VALUES rather
 * than counting pixels handles that correctly, and this floor only drops noise.
 */
const ALPHA_FLOOR = 8;

/** Distance from the median, in MADs, past which an icon leaves the set. */
export const OUTLIER_MADS = 3.2;

export interface InkRow {
  /** Whatever the caller keys entries by: a slug, a package, a role id. */
  key: string;
  /** Percentage of the tile covered by ink, 0 to 100. */
  ink: number;
  /** Signed distance from the median, in MADs. */
  mads: number;
  /** Percentage difference from the median, for display. */
  drift: number;
  outlier: boolean;
}

export interface InkReport {
  rows: InkRow[];
  median: number;
  mad: number;
  min: number;
  max: number;
  outliers: InkRow[];
}

export interface InkOptions {
  /** Stroke weight in viewBox units. Changes ink, so it is part of the key. */
  weight?: number;
  /** Composer inset, 0 to 1. Also changes ink. */
  inset?: number;
}

/**
 * Ink coverage of one glyph, as a percentage of its tile.
 *
 * NO PLATE AND NO COLOUR. The plate would saturate the alpha channel to 100%
 * on every icon and measure nothing; the colour is irrelevant because alpha is
 * what carries coverage. So the glyph is forced to opaque black and drawn on
 * transparency, which is the cheapest render that answers the question.
 */
export async function measureInk(
  svg: string,
  opts: InkOptions = {},
): Promise<number> {
  const weight = opts.weight ?? 1;
  const inset = Math.min(0.9, Math.max(0, opts.inset ?? 0));
  const room = Math.max(1, Math.round(PROBE_PX * (1 - inset)));

  const prepared = withIntrinsicSize(
    setStroke(recolourSvg(svg, '#000000'), weight),
    room,
  );

  const canvas = document.createElement('canvas');
  canvas.width = PROBE_PX;
  canvas.height = PROBE_PX;
  const ctx = canvas.getContext('2d', { willReadFrequently: true });
  if (!ctx) return 0;

  let bitmap: ImageBitmap;
  try {
    bitmap = await createImageBitmap(
      new Blob([prepared], { type: 'image/svg+xml' }),
    );
  } catch {
    // An undecodable file measures as zero rather than throwing. It will be a
    // wild outlier, which is the correct thing to surface: a glyph that cannot
    // be drawn is a glyph that must not ship.
    return 0;
  }

  const scale = Math.min(room / bitmap.width, room / bitmap.height);
  const w = bitmap.width * scale;
  const h = bitmap.height * scale;
  ctx.drawImage(bitmap, (PROBE_PX - w) / 2, (PROBE_PX - h) / 2, w, h);
  bitmap.close();

  const data = ctx.getImageData(0, 0, PROBE_PX, PROBE_PX).data;
  let sum = 0;
  for (let i = 3; i < data.length; i += 4) {
    if (data[i] > ALPHA_FLOOR) sum += data[i];
  }
  return (sum / (255 * PROBE_PX * PROBE_PX)) * 100;
}

/**
 * Ink coverage of a Blob, vector or raster.
 *
 * The builder holds a `File` per row and those rows are not all SVG: a pack can
 * mix line art with a dropped PNG. Both have an alpha channel and both can be
 * measured, so the caller should not have to branch on mime type to find out
 * whether an icon fits its set.
 *
 * Raster art ignores [weight], because a PNG has no strokes to set. It is
 * measured as it arrived, which is the honest answer: the reason a dropped PNG
 * is heavier than the line set around it is that it IS heavier, and no setting
 * in this builder will change that.
 */
export async function measureBlobInk(
  art: Blob,
  opts: InkOptions = {},
): Promise<number> {
  if (art.type === 'image/svg+xml') {
    try {
      return await measureInk(await art.text(), opts);
    } catch {
      return 0;
    }
  }

  const inset = Math.min(0.9, Math.max(0, opts.inset ?? 0));
  const room = Math.max(1, Math.round(PROBE_PX * (1 - inset)));
  const canvas = document.createElement('canvas');
  canvas.width = PROBE_PX;
  canvas.height = PROBE_PX;
  const ctx = canvas.getContext('2d', { willReadFrequently: true });
  if (!ctx) return 0;

  let bitmap: ImageBitmap;
  try {
    bitmap = await createImageBitmap(art);
  } catch {
    return 0;
  }
  const scale = Math.min(room / bitmap.width, room / bitmap.height);
  const w = bitmap.width * scale;
  const h = bitmap.height * scale;
  ctx.drawImage(bitmap, (PROBE_PX - w) / 2, (PROBE_PX - h) / 2, w, h);
  bitmap.close();

  const data = ctx.getImageData(0, 0, PROBE_PX, PROBE_PX).data;
  let sum = 0;
  for (let i = 3; i < data.length; i += 4) {
    if (data[i] > ALPHA_FLOOR) sum += data[i];
  }
  return (sum / (255 * PROBE_PX * PROBE_PX)) * 100;
}

/**
 * Measure blobs rather than SVG text. Same cache, same report.
 *
 * [key] must identify the ART, not the row: two rows holding the same file
 * should hit the cache once. The builder passes the file name plus its size,
 * which is stable across re-renders and distinguishes two files that happen to
 * share a name.
 */
export async function measureBlobSet(
  entries: { key: string; art: Blob }[],
  opts: InkOptions = {},
): Promise<InkReport> {
  const rows: { key: string; ink: number }[] = [];
  for (const e of entries) {
    const k = cacheKey(e.key, opts);
    let ink = cache.get(k);
    if (ink === undefined) {
      ink = await measureBlobInk(e.art, opts);
      cache.set(k, ink);
      if (cache.size > 4000) cache.delete(cache.keys().next().value as string);
    }
    rows.push({ key: e.key, ink });
  }
  return summarise(rows);
}

/**
 * Mean relative luminance of a blob's INK, 0 to 1, or null when it has none.
 *
 * ─── THE FAILURE THIS ANSWERS ─────────────────────────────────────────────
 *
 * A pack of dark line art on transparency, shipped with no plate, is invisible
 * on a dark wallpaper. Every file is valid, the pack signs and publishes, the
 * device applies it, and the icons are simply not there. It looks like the
 * launcher failed to load them.
 *
 * Coverage cannot see this: a black drawing and a white drawing of the same
 * shape have identical ink coverage. Luminance is the missing axis.
 *
 * Weighted by alpha for the same reason `measureInk` is: a line drawing is
 * mostly edge, and counting partly-covered pixels at full weight drags every
 * thin drawing toward whatever it was composited over.
 */
export async function measureLuminance(art: Blob): Promise<number | null> {
  const canvas = document.createElement('canvas');
  canvas.width = PROBE_PX;
  canvas.height = PROBE_PX;
  const ctx = canvas.getContext('2d', { willReadFrequently: true });
  if (!ctx) return null;

  let bitmap: ImageBitmap;
  try {
    bitmap = await createImageBitmap(art);
  } catch {
    return null;
  }
  const scale = Math.min(PROBE_PX / bitmap.width, PROBE_PX / bitmap.height);
  const w = bitmap.width * scale;
  const h = bitmap.height * scale;
  ctx.drawImage(bitmap, (PROBE_PX - w) / 2, (PROBE_PX - h) / 2, w, h);
  bitmap.close();

  const d = ctx.getImageData(0, 0, PROBE_PX, PROBE_PX).data;
  let weighted = 0;
  let weight = 0;
  for (let i = 0; i < d.length; i += 4) {
    const a = d[i + 3];
    if (a <= ALPHA_FLOOR) continue;
    weighted += srgbLuminance(d[i], d[i + 1], d[i + 2]) * a;
    weight += a;
  }
  return weight === 0 ? null : weighted / weight;
}

/** sRGB relative luminance, the WCAG definition. Matches IconContrast.kt. */
function srgbLuminance(r: number, g: number, b: number): number {
  const f = (v: number) => {
    const c = v / 255;
    return c <= 0.03928 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4);
  };
  return 0.2126 * f(r) + 0.7152 * f(g) + 0.0722 * f(b);
}

/**
 * Median ink luminance across a set. One number, because the question is about
 * the PACK: one dark icon among a hundred light ones is a different problem
 * from a pack that is uniformly too dark to see.
 */
export async function measureSetLuminance(arts: Blob[]): Promise<number | null> {
  const values: number[] = [];
  for (const a of arts) {
    const l = await measureLuminance(a);
    if (l !== null) values.push(l);
  }
  if (values.length === 0) return null;
  values.sort((x, y) => x - y);
  return values[Math.floor((values.length - 1) / 2)];
}

/**
 * Measure a whole set and say which icons leave it.
 *
 * ─── THE CACHE IS NOT AN OPTIMISATION HERE ──────────────────────────────────
 *
 * This runs behind a slider. At 193 icons, an uncached pass is 193 SVG
 * rasterisations and 193 `getImageData` calls, and `getImageData` forces a
 * readback that stalls the compositor. Dragging a weight slider without a cache
 * and a debounce locks the tab.
 *
 * The key deliberately carries ONLY weight and inset. Colour, plate, shape and
 * corner radius cannot change coverage, and putting them in the key would throw
 * the whole measurement away every time somebody nudged a hue, which is the
 * control people move most.
 */
const cache = new Map<string, number>();

function cacheKey(key: string, opts: InkOptions): string {
  return `${key}|${opts.weight ?? 1}|${opts.inset ?? 0}`;
}

/** Drop everything. Call when the SOURCE art changes, not when style does. */
export function clearInkCache(): void {
  cache.clear();
}

export async function measureSet(
  entries: { key: string; svg: string }[],
  opts: InkOptions = {},
): Promise<InkReport> {
  const rows: { key: string; ink: number }[] = [];
  for (const e of entries) {
    const k = cacheKey(e.key, opts);
    let ink = cache.get(k);
    if (ink === undefined) {
      ink = await measureInk(e.svg, opts);
      cache.set(k, ink);
      // Bounded so a long authoring session over several source sets cannot
      // grow without limit. Well above one full pack at a handful of settings.
      if (cache.size > 4000) cache.delete(cache.keys().next().value as string);
    }
    rows.push({ key: e.key, ink });
  }
  return summarise(rows);
}

/** Pure. Split out so it is testable without a canvas. */
export function summarise(rows: { key: string; ink: number }[]): InkReport {
  if (rows.length === 0) {
    return { rows: [], median: 0, mad: 0, min: 0, max: 0, outliers: [] };
  }

  const values = rows.map((r) => r.ink);
  const median = middle(values);
  // A set where more than half the icons share one coverage value produces a
  // MAD of zero, and every other icon then sits infinitely far from the median.
  // Rare in real art and routine in a set of placeholders, so it is floored.
  const mad = Math.max(middle(values.map((v) => Math.abs(v - median))), 0.001);

  const out: InkRow[] = rows.map((r) => {
    const mads = (r.ink - median) / mad;
    return {
      key: r.key,
      ink: r.ink,
      mads,
      drift: median === 0 ? 0 : ((r.ink - median) / median) * 100,
      outlier: Math.abs(mads) > OUTLIER_MADS,
    };
  });

  return {
    rows: out,
    median,
    mad,
    // ─── COMPUTED, NOT INDEXED ────────────────────────────────────────────
    //
    // These read `values[0]` and `values[length - 1]`, which was correct only
    // while `values` was sorted. Sorting moved into `middle` to fix the MAD,
    // and these two silently became "the first row's ink" and "the last row's
    // ink" instead. On a real pack that produced a min ABOVE the max, and
    // `histogram` then divided by a negative span and stacked every icon into
    // one edge bucket.
    //
    // It failed visibly, on screen, as an axis reading 13.1% to 9.4%, and it
    // still took a screenshot to notice. Deriving them removes the dependency
    // on an ordering that no longer exists.
    min: Math.min(...values),
    max: Math.max(...values),
    outliers: out.filter((r) => r.outlier).sort((a, b) => Math.abs(b.mads) - Math.abs(a.mads)),
  };
}

/**
 * Median. Sorts a COPY, and that is not a defensive nicety.
 *
 * This took an already-sorted array and the caller then handed it the ABSOLUTE
 * DEVIATIONS from the median, which are derived from sorted input and are not
 * themselves sorted. The MAD came back as whatever deviation happened to sit at
 * the midpoint of an arbitrary order, which for an even set was near the
 * maximum rather than the middle, and the threshold collapsed: a synthetic set
 * of forty evenly spaced icons reported thirty-two outliers.
 *
 * The failure mode is the dangerous kind. It does not throw, it does not look
 * wrong in the code, and on a real set it would have reported plausible-looking
 * outliers that were simply the wrong icons. Sorting here costs nothing at this
 * size and removes the contract that got broken.
 *
 * Lower median on an even count, so the result is always a value some icon
 * actually has rather than an average of two that neither does.
 */
function middle(values: number[]): number {
  const sorted = [...values].sort((a, b) => a - b);
  return sorted[Math.floor((sorted.length - 1) / 2)];
}

/**
 * Bucket a report for a histogram.
 *
 * Returns counts plus the coverage value at each bucket's centre, so the caller
 * can colour a bucket by whether an icon landing there would be an outlier
 * without re-deriving the threshold and getting it subtly different.
 */
export function histogram(
  report: InkReport,
  buckets = 26,
): { count: number; centre: number; outlier: boolean }[] {
  const span = report.max - report.min || 1;
  const counts = new Array(buckets).fill(0);
  for (const r of report.rows) {
    const i = Math.min(buckets - 1, Math.floor(((r.ink - report.min) / span) * buckets));
    counts[i] += 1;
  }
  return counts.map((count, i) => {
    const centre = report.min + (span * (i + 0.5)) / buckets;
    return {
      count,
      centre,
      outlier: Math.abs((centre - report.median) / report.mad) > OUTLIER_MADS,
    };
  });
}
