'use client';

import { useEffect, useState } from 'react';

import {
  histogram,
  measureBlobSet,
  measureSetLuminance,
  type InkReport,
} from '@/lib/g-launcher/icon-ink';
import {
  strokeDevicePx,
  strokeVerdict,
  IMPLICIT_STROKE_WIDTH,
  type StrokeVerdict,
} from '@/lib/g-launcher/svg-stroke';
import { densityBuckets } from '@/lib/g-launcher/devices';

/**
 * SET HEALTH: the two questions a finished pack has to answer.
 *
 *   1. Will the strokes survive the cheapest phone this ships to?
 *   2. Do these icons look like one set?
 *
 * Both were unanswerable in this builder. The first is arithmetic nobody had
 * written down, spread across `IconSizing`, `app_icon.dart` and the composer's
 * inset. The second is a judgement the eye is measurably bad at across forty
 * tiles, let alone a hundred and ninety.
 *
 * ─── WHY IT IS A PANEL AND NOT A BLOCKING CHECK ─────────────────────────────
 *
 * Neither number is a rule. A pack of deliberately heavy art is a legitimate
 * pack, and a distro that only ever ships to a flagship can carry a thinner
 * line than one aimed at Tecno. So this reports and never refuses. The only
 * thing it hard-gates is nothing at all; the publish button is the builder's
 * to disable, and it already has enough reasons.
 */

const VERDICT_COLOUR: Record<StrokeVerdict, string> = {
  subpixel: 'var(--color-site-plan)',
  thin: 'var(--color-site-plan)',
  crisp: 'var(--color-site-ok)',
};

const VERDICT_WORD: Record<StrokeVerdict, string> = {
  subpixel: 'below one pixel',
  thin: 'thin',
  crisp: 'crisp',
};

export interface HealthRow {
  /** Stable per piece of art. The builder passes file name plus byte length. */
  key: string;
  /** What the row is called on screen. */
  label: string;
  /** SOURCE art, never the composed output: a plate saturates alpha to 100%. */
  art: Blob;
}

export function IconSetHealth({
  rows,
  inset,
  strokeWidth,
  plateNone = true,
  onSelect,
}: {
  rows: HealthRow[];
  /** The composer's current inset, so the reading matches what would ship. */
  inset: number;
  /** Current stroke weight, or null when art ships at its authored weight. */
  strokeWidth: number | null;
  /**
   * True when nothing will be drawn behind the art, so the wallpaper is the
   * background. Defaults true because the builder's own default is to ship art
   * as authored, which is exactly the plateless case.
   */
  plateNone?: boolean;
  /** Called with a row key when an outlier is tapped. */
  onSelect?: (key: string) => void;
}) {
  const [report, setReport] = useState<InkReport | null>(null);
  const [measuring, setMeasuring] = useState(false);
  const [luminance, setLuminance] = useState<number | null>(null);

  /**
   * ─── DEBOUNCED, AND THE DEBOUNCE IS LOAD BEARING ──────────────────────────
   *
   * Every measurement is an SVG rasterisation plus a `getImageData`, and
   * `getImageData` forces a readback that stalls the compositor. At a hundred
   * and ninety rows behind a weight slider, an undebounced pass locks the tab.
   *
   * `cancelled` matters as much as the delay. A second change arriving mid-pass
   * would otherwise race the first to `setReport`, and because the passes run
   * at different speeds the LAST write is not reliably the LATEST settings, so
   * the histogram would occasionally settle on a reading for a weight the
   * author had already moved off.
   */
  useEffect(() => {
    if (rows.length === 0) {
      setReport(null);
      return;
    }
    let cancelled = false;
    const timer = setTimeout(() => {
      setMeasuring(true);
      void measureBlobSet(
        rows.map((r) => ({ key: r.key, art: r.art })),
        { weight: strokeWidth ?? IMPLICIT_STROKE_WIDTH, inset },
      ).then((next) => {
        if (cancelled) return;
        setReport(next);
        setMeasuring(false);
      });
      // Luminance does not depend on weight or inset, so it is measured once
      // per art set rather than on every slider move.
      void measureSetLuminance(rows.map((r) => r.art)).then((l) => {
        if (!cancelled) setLuminance(l);
      });
    }, 250);
    return () => {
      cancelled = true;
      clearTimeout(timer);
    };
  }, [rows, inset, strokeWidth]);

  const width = strokeWidth ?? IMPLICIT_STROKE_WIDTH;
  const buckets = densityBuckets();
  // No plate means the wallpaper is the background, and the wallpaper is
  // not knowable here. That is exactly when raw luminance is the only
  // signal available.
  const plateless = inset >= 0 && plateNone;
  const label = new Map(rows.map((r) => [r.key, r.label]));

  return (
    <div className="rounded-[14px] border border-site-line bg-site-sunk p-3">
      <div className="flex flex-wrap items-baseline gap-x-3 gap-y-1">
        <h4 className="text-[13px] font-semibold text-site-ink">Set health</h4>
        <span className="text-[11.5px] text-site-ink-3">
          {measuring ? 'Measuring' : `${rows.length} ${rows.length === 1 ? 'icon' : 'icons'}`}
        </span>
      </div>

      {/* ── WILL THIS BE VISIBLE AT ALL ──────────────────────────────────
          Ink coverage cannot answer this: a black drawing and a white drawing
          of the same shape measure identically. A pack of dark line art with
          no plate publishes cleanly, signs cleanly, applies cleanly and is
          simply not there on a dark wallpaper, which reads as the launcher
          failing to load it rather than as an authoring choice.

          Only shown when there is no plate to sit on. With a plate, the
          question is contrast against that plate, and `IconContrast.kt`
          answers it on the device where the wallpaper is actually known. */}
      {luminance !== null && plateless && (luminance < 0.22 || luminance > 0.8) ? (
        <div
          className="mt-3 rounded-[10px] px-3 py-2 text-[11.5px] leading-relaxed"
          style={{
            background: 'var(--color-site-plan-soft)',
            color: 'var(--color-site-plan)',
          }}
        >
          <b>
            This art is {luminance < 0.22 ? 'very dark' : 'very light'} and the pack
            has no plate.
          </b>{' '}
          Median ink luminance is {(luminance * 100).toFixed(0)}%, so on a{' '}
          {luminance < 0.22 ? 'dark' : 'light'} wallpaper these icons will be close to
          invisible. Either add a plate, or use Style every icon with a tint to
          recolour the whole set in one pass.
        </div>
      ) : null}

      {/* ── stroke, per device ───────────────────────────────────────────── */}
      <div className="mt-3">
        <p className="text-[11px] uppercase tracking-[0.12em] text-site-ink-3">
          Stroke on screen
        </p>
        {/* ── ONE CARD PER DENSITY, NOT PER PHONE ─────────────────────────
            Ten handsets produce four distinct icon sizes. Four cards reading
            2.0 px would be noise, and would bury the only thing this section
            exists to show: how far apart the cheapest and the best actually
            are. The phones are the caption. */}
        <div className="mt-2 flex flex-wrap gap-2">
          {buckets.map((b) => {
            const px = strokeDevicePx({ width, devicePx: b.px, inset });
            const verdict = strokeVerdict(px);
            return (
              <div
                key={b.px}
                className="flex-1 min-w-[150px] rounded-[10px] border border-site-line bg-site-card px-3 py-2"
              >
                <div className="flex items-baseline gap-1.5">
                  <span
                    className="font-mono text-[17px] font-semibold leading-none"
                    style={{ color: VERDICT_COLOUR[verdict] }}
                  >
                    {px.toFixed(1)}
                  </span>
                  <span className="font-mono text-[10px] text-site-ink-3">px</span>
                  <span className="ml-auto font-mono text-[10px] text-site-ink-3">
                    {b.px} px icon
                  </span>
                </div>
                <div className="mt-1 text-[11px] text-site-ink-2">
                  {VERDICT_WORD[verdict]}
                </div>
                <div className="text-[10.5px] leading-snug text-site-ink-3">{b.label}</div>
              </div>
            );
          })}
        </div>
        <p className="mt-2 text-[11.5px] leading-relaxed text-site-ink-3">
          {strokeWidth == null
            ? 'Art ships at the weight it was authored with. Line sets that declare no stroke-width inherit the SVG default of 1, which is what this assumes.'
            : `Weight ${width.toFixed(2)} against a 48 unit box, after a ${Math.round(inset * 100)}% inset.`}
        </p>
      </div>

      {/* ── optical weight ───────────────────────────────────────────────── */}
      {report && report.rows.length > 1 ? (
        <div className="mt-4 border-t border-site-line pt-3">
          <div className="flex flex-wrap items-baseline gap-x-3">
            <p className="text-[11px] uppercase tracking-[0.12em] text-site-ink-3">
              Optical weight
            </p>
            <span className="font-mono text-[10.5px] text-site-ink-3">
              median {report.median.toFixed(1)}% ink · {report.outliers.length}{' '}
              {report.outliers.length === 1 ? 'outlier' : 'outliers'}
            </span>
          </div>

          <div className="mt-2 flex h-11 items-end gap-[2px]">
            {histogram(report).map((b, i) => (
              <span
                key={i}
                className="flex-1 rounded-t-[2px]"
                style={{
                  height: `${Math.max(4, (b.count / Math.max(...histogram(report).map((x) => x.count), 1)) * 100)}%`,
                  background: b.count
                    ? b.outlier
                      ? 'var(--color-site-plan)'
                      : 'var(--color-site-accent)'
                    : 'var(--color-site-line)',
                }}
              />
            ))}
          </div>
          <div className="mt-1 flex justify-between font-mono text-[10px] text-site-ink-3">
            <span>{report.min.toFixed(1)}%</span>
            <span>{report.max.toFixed(1)}%</span>
          </div>

          {report.outliers.length > 0 ? (
            <div className="mt-2 flex flex-wrap gap-1.5">
              {report.outliers.slice(0, 8).map((o) => (
                <button
                  key={o.key}
                  type="button"
                  onClick={() => onSelect?.(o.key)}
                  className="rounded-lg border border-site-plan bg-site-plan-soft px-2 py-1 text-[11px] text-site-plan"
                >
                  {label.get(o.key) ?? o.key}
                  <span className="ml-1.5 font-mono text-[10px]">
                    {o.drift > 0 ? '+' : ''}
                    {o.drift.toFixed(0)}%
                  </span>
                </button>
              ))}
            </div>
          ) : null}

          <p className="mt-2 text-[11.5px] leading-relaxed text-site-ink-3">
            {report.outliers.length === 0
              ? 'Every icon carries about the same amount of ink, which is what makes a pack read as one set.'
              : 'Ink coverage, measured from the alpha channel with the plate off. An icon this far from the median does not read as emphasis, it reads as a mistake. Redraw it, or nudge its scale before it is composed.'}
          </p>
        </div>
      ) : null}
    </div>
  );
}
