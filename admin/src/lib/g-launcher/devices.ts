'use client';

/**
 * THE HANDSETS A PACK IS JUDGED AGAINST.
 *
 * ─── ONE LIST, BECAUSE IT WAS ALREADY TWO ───────────────────────────────────
 *
 * `icon-set-health.tsx` and `icon-contact-sheet.tsx` each carried their own
 * copy. They agreed on the day they were written, which is the only day two
 * copies ever agree, and adding a handset was already a two-file change that
 * would silently leave the sheet and the gauge disagreeing about what a device
 * is. Extracted before that happened rather than after.
 *
 * ─── WHY THESE PHONES ───────────────────────────────────────────────────────
 *
 * The install base, not a test matrix. The S22 is the development device and
 * the LEAST demanding entry here: at dpr 3.0 it buys enough pixels that almost
 * any weight survives, so tuning against it is how a set ships thin. The Samsung
 * A-series, the Transsion pair and the Oppo A-series are what the market
 * actually runs, and they are where a line disappears first.
 *
 * ─── HOW THE NUMBERS ARE DERIVED ────────────────────────────────────────────
 *
 * `dpr` is the default `densityDpi / 160` each device reports out of the box.
 * `dp` is the icon size `IconSizing` lands on for that screen's dp width with a
 * default grid, and it is clamped to 40..64 there, so these are the FLOOR: a
 * theme raising `iconScale`, or a person choosing a larger display size, only
 * ever gets more pixels than this predicts.
 *
 * Both are defaults rather than guarantees. Android lets the display size be
 * changed on every phone here, and a person who has done that is off this
 * chart in the safe direction. A pack that reads well at the numbers below
 * reads well above them.
 */

export interface DeviceProfile {
  id: string;
  name: string;
  /** For the compact switcher, where the full name will not fit. */
  short: string;
  /** Default device pixel ratio, densityDpi / 160. */
  dpr: number;
  /** Grid icon size in dp, from IconSizing at a default grid. */
  dp: number;
  /** Logical screen width in dp, which is what decides [dp]. */
  widthDp: number;
}

export const DEVICES: DeviceProfile[] = [
  // ── the floor: 720p, dpr 2.0, 360dp wide ──────────────────────────────────
  { id: 'tecno-spark-10', name: 'Tecno Spark 10', short: 'Tecno', dpr: 2.0, dp: 48, widthDp: 360 },
  { id: 'infinix-hot-30', name: 'Infinix Hot 30', short: 'Infinix', dpr: 2.0, dp: 48, widthDp: 360 },
  { id: 'samsung-a05s', name: 'Galaxy A05s', short: 'A05s', dpr: 2.0, dp: 48, widthDp: 360 },
  { id: 'oppo-a18', name: 'Oppo A18', short: 'A18', dpr: 2.0, dp: 48, widthDp: 360 },

  // ── the middle: 1080p, dpr 2.6 to 2.75 ────────────────────────────────────
  { id: 'samsung-a15', name: 'Galaxy A15', short: 'A15', dpr: 2.625, dp: 52, widthDp: 411 },
  { id: 'samsung-a55', name: 'Galaxy A55', short: 'A55', dpr: 2.625, dp: 52, widthDp: 411 },
  { id: 'redmi-note-12', name: 'Redmi Note 12', short: 'Redmi', dpr: 2.75, dp: 50, widthDp: 393 },
  { id: 'oppo-reno-11', name: 'Oppo Reno 11', short: 'Reno', dpr: 2.75, dp: 50, widthDp: 393 },

  // ── the ceiling, and the one this is developed on ─────────────────────────
  { id: 'samsung-s22', name: 'Galaxy S22', short: 'S22', dpr: 3.0, dp: 48, widthDp: 360 },
  { id: 'samsung-s24u', name: 'Galaxy S24 Ultra', short: 'S24U', dpr: 3.5, dp: 52, widthDp: 411 },
];

/** Icon size in device pixels. The only number that matters downstream. */
export function iconPx(d: DeviceProfile): number {
  return Math.round(d.dp * d.dpr);
}

export interface DensityBucket {
  /** Icon size in device pixels for every device in this bucket. */
  px: number;
  devices: DeviceProfile[];
  /** Names joined for display, e.g. "Tecno Spark 10, Galaxy A05s". */
  label: string;
}

/**
 * Group the list by the pixel count they actually produce.
 *
 * ─── TEN DEVICES ARE FOUR ANSWERS ───────────────────────────────────────────
 *
 * A Tecno Spark 10, an Infinix Hot 30, a Galaxy A05s and an Oppo A18 are four
 * different phones that all render an icon into exactly 96 pixels. Showing four
 * cards reading 2.0 px is four times the noise for none of the information, and
 * it hides the thing the panel exists to show, which is the SPREAD.
 *
 * So the cards are density buckets and the phone names are the caption. Adding
 * a handset that matches an existing bucket then costs a name in a list rather
 * than a card on screen, which is the right price.
 *
 * [tolerance] merges buckets within a few pixels of each other, because 137 and
 * 138 are the same answer and two cards claiming otherwise is a distinction the
 * eye cannot act on.
 */
export function densityBuckets(
  devices: DeviceProfile[] = DEVICES,
  tolerance = 6,
): DensityBucket[] {
  const sorted = [...devices].sort((a, b) => iconPx(a) - iconPx(b));
  const buckets: DensityBucket[] = [];

  for (const d of sorted) {
    const px = iconPx(d);
    const last = buckets[buckets.length - 1];
    if (last && px - last.px <= tolerance) {
      last.devices.push(d);
      // The bucket keeps the SMALLEST pixel count it contains, so a merge can
      // only ever report a thinner stroke than a member would. Rounding toward
      // the optimistic end is how a gauge like this stops being trusted.
      continue;
    }
    buckets.push({ px, devices: [d], label: '' });
  }

  for (const b of buckets) b.label = b.devices.map((d) => d.name).join(', ');
  return buckets;
}

/** The harshest bucket, which is the one a set has to survive. */
export function worstBucket(buckets: DensityBucket[]): DensityBucket | null {
  return buckets.length ? buckets[0] : null;
}
