'use client';

import { useEffect, useMemo, useRef, useState } from 'react';

import { measureBlobSet, type InkReport } from '@/lib/g-launcher/icon-ink';
import { IMPLICIT_STROKE_WIDTH } from '@/lib/g-launcher/svg-stroke';
import { DEVICES, iconPx } from '@/lib/g-launcher/devices';

/**
 * THE SET, AT THE PIXELS IT WILL ACTUALLY OCCUPY.
 *
 * ─── WHAT THE REVIEW LIST CANNOT TELL YOU ───────────────────────────────────
 *
 * The list below this shows one row per icon at a fixed preview size, on the
 * panel's own background, in the order they were added. That is the right shape
 * for checking package mappings and the wrong shape for every other question a
 * finished pack raises, because all three of those choices are lies about how
 * the art will be seen.
 *
 * A pack is seen as a GRID, at a size the phone chooses, on the distro's own
 * plate colour. An icon that is 40% too heavy is invisible in a vertical list
 * of 31 rows and obvious in a grid of 31 tiles. An icon whose strokes vanish at
 * 96 device pixels looks fine at the 40px the list renders it at.
 *
 * ─── THE RESAMPLE IS REAL, NOT SIMULATED ────────────────────────────────────
 *
 * Each tile is drawn to an offscreen canvas at the selected device's true pixel
 * size, then scaled to its display box. That is two resamples, and it is
 * exactly what the phone does: compose at `ICON_SIZE`, then let Android scale
 * to the grid. Rendering the blob straight into a CSS-sized <img> would look
 * sharper than the device and would be worth nothing.
 */

export interface SheetTile {
  id: string;
  /** Composed output. What ships, so what is shown. */
  blob: Blob | null;
  /** Source art. Measured, because the composed blob carries an opaque plate. */
  source: Blob;
  label: string;
  /** Role or package. Empty means unmapped, which the tile marks. */
  slot: string;
}

export function IconContactSheet({
  tiles,
  inset,
  strokeWidth,
  onSelect,
}: {
  tiles: SheetTile[];
  inset: number;
  strokeWidth: number | null;
  onSelect?: (id: string) => void;
}) {
  const [device, setDevice] = useState(0);
  const [backdrop, setBackdrop] = useState('#0B0E13');
  const [report, setReport] = useState<InkReport | null>(null);

  const dev = DEVICES[device];
  const devicePx = iconPx(dev);

  /**
   * Keyed on the SOURCE, not the tile id, so the measurement cache survives a
   * row being removed and re-added and two rows holding the same drawing are
   * measured once. `Blob.size` distinguishes two files that share a name.
   */
  const measureRows = useMemo(
    () => tiles.map((t) => ({ key: `${t.label}:${t.source.size}`, art: t.source })),
    [tiles],
  );

  useEffect(() => {
    if (measureRows.length < 2) {
      setReport(null);
      return;
    }
    let cancelled = false;
    const timer = setTimeout(() => {
      void measureBlobSet(measureRows, {
        weight: strokeWidth ?? IMPLICIT_STROKE_WIDTH,
        inset,
      }).then((next) => {
        if (!cancelled) setReport(next);
      });
    }, 250);
    return () => {
      cancelled = true;
      clearTimeout(timer);
    };
  }, [measureRows, inset, strokeWidth]);

  const outliers = useMemo(() => {
    if (!report) return new Set<string>();
    return new Set(report.outliers.map((o) => o.key));
  }, [report]);

  return (
    <div className="rounded-[14px] border border-site-line bg-site-sunk p-3">
      <div className="flex flex-wrap items-center gap-2">
        <h4 className="text-[13px] font-semibold text-site-ink">Contact sheet</h4>

        <div className="ml-auto flex items-center gap-2">
          {/* ── BACKDROP ────────────────────────────────────────────────────
              A pack is judged against the wallpaper it ships beside, and the
              panel's own background is not that. Three swatches rather than a
              colour input, because the question is "does this hold on a dark
              distro, a light one, and a mid grey", not "what exact hex". */}
          <div className="flex items-center gap-1">
            {['#0B0E13', '#6B7280', '#EEF1F5'].map((c) => (
              <button
                key={c}
                type="button"
                onClick={() => setBackdrop(c)}
                aria-label={`backdrop ${c}`}
                aria-pressed={backdrop === c}
                className="h-5 w-5 rounded-[5px] border"
                style={{
                  background: c,
                  borderColor:
                    backdrop === c ? 'var(--color-site-accent)' : 'var(--color-site-line)',
                }}
              />
            ))}
          </div>

          {/* ── A SELECT, NOT A SEGMENTED CONTROL ───────────────────────────
              Three handsets fitted in a row. Ten do not, and cramming them
              would push the backdrop swatches off the line at the width this
              panel actually gets. A select also names the phone in full, which
              a four-character abbreviation cannot. */}
          <select
            value={device}
            onChange={(e) => setDevice(Number(e.target.value))}
            aria-label="device"
            className="rounded-lg border border-site-line bg-site-card px-2 py-1 text-[11.5px] text-site-ink-2"
          >
            {DEVICES.map((d, i) => (
              <option key={d.id} value={i}>
                {d.name} · {iconPx(d)} px
              </option>
            ))}
          </select>
        </div>
      </div>

      <p className="mt-1 font-mono text-[10.5px] text-site-ink-3">
        {dev.name} · {dev.dp}dp at dpr {dev.dpr} · {devicePx} px per icon
        {report ? ` · ${report.outliers.length} off the set` : ''}
      </p>

      <div
        className="mt-2 rounded-[10px] p-3"
        style={{ background: backdrop }}
      >
        <div className="grid grid-cols-[repeat(auto-fill,minmax(56px,1fr))] gap-x-1 gap-y-3">
          {tiles.map((t) => (
            <Tile
              key={t.id}
              tile={t}
              devicePx={devicePx}
              backdrop={backdrop}
              outlier={outliers.has(`${t.label}:${t.source.size}`)}
              onSelect={onSelect}
            />
          ))}
        </div>
      </div>

      <p className="mt-2 text-[11.5px] leading-relaxed text-site-ink-3">
        Each tile is composed, scaled to {devicePx} px, then drawn. That is the
        same pair of resamples the phone performs, so what is soft here is soft
        on the device. Amber marks an icon whose ink is far from the set median.
      </p>
    </div>
  );
}

function Tile({
  tile,
  devicePx,
  backdrop,
  outlier,
  onSelect,
}: {
  tile: SheetTile;
  devicePx: number;
  backdrop: string;
  outlier: boolean;
  onSelect?: (id: string) => void;
}) {
  const ref = useRef<HTMLCanvasElement | null>(null);
  const CSS_PX = 48;

  useEffect(() => {
    const canvas = ref.current;
    if (!canvas || !tile.blob) return;
    let cancelled = false;

    void (async () => {
      let bmp: ImageBitmap;
      try {
        bmp = await createImageBitmap(tile.blob as Blob);
      } catch {
        return;
      }
      if (cancelled) {
        bmp.close();
        return;
      }

      // Composed size to device size. The honest first resample.
      const stage = document.createElement('canvas');
      stage.width = devicePx;
      stage.height = devicePx;
      const sg = stage.getContext('2d');
      if (!sg) {
        bmp.close();
        return;
      }
      sg.imageSmoothingQuality = 'high';
      sg.drawImage(bmp, 0, 0, devicePx, devicePx);
      bmp.close();

      // Device size to the display box. The second.
      const dpr = Math.min(window.devicePixelRatio || 1, 3);
      canvas.width = Math.round(CSS_PX * dpr);
      canvas.height = canvas.width;
      const g = canvas.getContext('2d');
      if (!g) return;
      g.imageSmoothingQuality = 'high';
      g.clearRect(0, 0, canvas.width, canvas.height);
      g.drawImage(stage, 0, 0, canvas.width, canvas.height);
    })();

    return () => {
      cancelled = true;
    };
  }, [tile.blob, devicePx]);

  const light = isLight(backdrop);

  return (
    <button
      type="button"
      onClick={() => onSelect?.(tile.id)}
      className="relative flex flex-col items-center gap-1 rounded-[8px] p-1"
      title={tile.slot || 'unmapped'}
    >
      <canvas
        ref={ref}
        style={{ width: CSS_PX, height: CSS_PX, display: 'block' }}
      />
      <span
        className="max-w-[62px] truncate text-[9px]"
        style={{ color: light ? '#3A4150' : '#C4CBD6' }}
      >
        {tile.label}
      </span>
      {outlier ? (
        <span
          className="absolute right-0 top-0 h-2 w-2 rounded-full"
          style={{
            background: 'var(--color-site-plan)',
            boxShadow: `0 0 0 2px ${backdrop}`,
          }}
        />
      ) : null}
      {!tile.slot ? (
        <span
          className="absolute left-0 top-0 h-2 w-2 rounded-full"
          style={{ background: 'var(--color-site-ink-3)', boxShadow: `0 0 0 2px ${backdrop}` }}
        />
      ) : null}
    </button>
  );
}

/**
 * Relative luminance, so the label stays readable on a light backdrop.
 *
 * The threshold is the WCAG midpoint rather than a naive average of the
 * channels: the mid grey swatch above sits either side of that line depending
 * on which formula is used, and a label that is unreadable on exactly one of
 * three backdrops is the kind of thing that looks like a rendering bug.
 */
function isLight(hex: string): boolean {
  const v = [1, 3, 5]
    .map((i) => parseInt(hex.slice(i, i + 2), 16) / 255)
    .map((c) => (c <= 0.03928 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4)));
  return 0.2126 * v[0] + 0.7152 * v[1] + 0.0722 * v[2] > 0.32;
}
