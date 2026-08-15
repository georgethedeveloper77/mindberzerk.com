'use client';

import * as React from 'react';

import { ICON_TREATMENTS } from '@/lib/g-launcher/theme-spec';
import type { ComposeSpec, PlateKind } from '@/lib/g-launcher/icon-compose';
import {
  fetchGlyphs,
  glyphToDataUrl,
  type GlyphLite,
} from '@/lib/g-launcher/glyph-blob';

/**
 * THE STYLE BAR AND THE GLYPH PICKER.
 *
 * Presentational only: every change is a callback, no state that matters lives
 * here, and the builder owns the entries. Split out of `icon-builder.tsx`
 * because that file is already twelve hundred lines and this is two self
 * contained controls, not a change to the pipeline they feed.
 *
 * ─── WHY STYLE IS NULLABLE ──────────────────────────────────────────────────
 *
 * `null` means composing is OFF and the builder does exactly what it did
 * yesterday: `renderHeroIcon` fits the art to a 192 square and ships it as
 * authored. That is the right default because it is the behaviour every
 * existing pack was built with, and turning composing on is a deliberate act
 * with a visible consequence, not a mode the screen quietly starts in.
 */

const row: React.CSSProperties = {
  display: 'flex',
  flexWrap: 'wrap',
  alignItems: 'center',
  gap: 8,
};

export function IconStyleBar({
  style,
  onChange,
  count,
  busy,
}: {
  style: ComposeSpec | null;
  onChange: (next: ComposeSpec | null) => void;
  /** How many entries a change would restyle. */
  count: number;
  busy: boolean;
}) {
  if (!style) {
    return (
      <div style={{ ...row, justifyContent: 'space-between' }}>
        <span style={{ fontSize: 12.5, color: 'var(--text-secondary)' }}>
          Art ships as authored.
        </span>
        <button
          onClick={() =>
            onChange({
              plate: { kind: 'colour', colour: '#16191D' },
              treatment: 'roundedSquare',
              cornerRadius: 0.22,
              inset: 0.34,
              tint: null,
            })
          }
        >
          Style every icon
        </button>
      </div>
    );
  }

  const set = (p: Partial<ComposeSpec>) => onChange({ ...style, ...p });
  const setPlate = (p: Partial<ComposeSpec['plate']>) =>
    onChange({ ...style, plate: { ...style.plate, ...p } });

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
      <div style={row}>
        <select
          value={style.plate.kind}
          onChange={(e) => setPlate({ kind: e.target.value as PlateKind })}
          style={{ width: 120 }}
        >
          <option value="colour">solid</option>
          <option value="gradient">gradient</option>
          <option value="none">no plate</option>
        </select>

        {style.plate.kind !== 'none' ? (
          <input
            type="color"
            value={style.plate.colour}
            onChange={(e) => setPlate({ colour: e.target.value })}
            style={{ width: 44, height: 34, padding: 2 }}
            aria-label="plate colour"
          />
        ) : null}

        {style.plate.kind === 'gradient' ? (
          <>
            <input
              type="color"
              value={style.plate.colour2 ?? '#1E3A63'}
              onChange={(e) => setPlate({ colour2: e.target.value })}
              style={{ width: 44, height: 34, padding: 2 }}
              aria-label="gradient end"
            />
            <input
              type="number"
              min={0}
              max={360}
              step={5}
              value={style.plate.angle ?? 135}
              onChange={(e) => setPlate({ angle: Number(e.target.value) })}
              style={{ width: 76 }}
              aria-label="gradient angle"
            />
          </>
        ) : null}

        <select
          value={style.treatment}
          onChange={(e) => set({ treatment: e.target.value })}
          style={{ width: 140 }}
        >
          {ICON_TREATMENTS.map((t) => (
            <option key={t} value={t}>
              {t}
            </option>
          ))}
        </select>

        <label style={{ fontSize: 12, color: 'var(--text-secondary)' }}>
          radius
          <input
            type="number"
            min={0}
            max={0.5}
            step={0.01}
            value={style.cornerRadius}
            onChange={(e) => set({ cornerRadius: Number(e.target.value) })}
            style={{ width: 74, marginLeft: 6 }}
          />
        </label>

        <label style={{ fontSize: 12, color: 'var(--text-secondary)' }}>
          inset
          <input
            type="number"
            min={0}
            max={0.8}
            step={0.02}
            value={style.inset}
            onChange={(e) => set({ inset: Number(e.target.value) })}
            style={{ width: 74, marginLeft: 6 }}
          />
        </label>

        {/* TINT IS OPT IN, because it is the one setting that DESTROYS
            information: a full colour logo tinted is a flat shape and the
            original colours cannot be recovered from the result. The source
            file survives, so it is reversible in the builder, but the checkbox
            makes it a decision rather than a default. */}
        <label style={{ fontSize: 12, display: 'inline-flex', alignItems: 'center', gap: 6 }}>
          <input
            type="checkbox"
            checked={style.tint != null}
            onChange={(e) => set({ tint: e.target.checked ? '#FFFFFF' : null })}
          />
          tint
        </label>
        {style.tint != null ? (
          <input
            type="color"
            value={style.tint}
            onChange={(e) => set({ tint: e.target.value })}
            style={{ width: 44, height: 34, padding: 2 }}
            aria-label="foreground tint"
          />
        ) : null}

        <button onClick={() => onChange(null)} disabled={busy}>
          Stop styling
        </button>
      </div>

      <p style={{ fontSize: 11.5, color: 'var(--text-muted)', lineHeight: 1.6, margin: 0 }}>
        {busy
          ? 'Restyling'
          : `Applies to all ${count} ${count === 1 ? 'icon' : 'icons'}. Every change recomposes from the original art, so nothing is baked on top of a previous pass.`}
      </p>
    </div>
  );
}

/**
 * Pick a brand glyph from the CC0 set.
 *
 * ─── SEARCH IS A ROUND TRIP, AND THAT IS THE POINT ──────────────────────────
 *
 * The dataset is 3,453 icons and several megabytes of path data. It stays on
 * the server and the wire carries at most sixty matches, so this component
 * holds a query and a result list and nothing else. See `glyph-search.ts`.
 *
 * ─── AND THE PACKAGE IS GUESSED FROM THE SLUG ───────────────────────────────
 *
 * A picked glyph enters the pipeline as a file named `<slug>.svg`, which means
 * `guessPackage` resolves it exactly as a dropped file would: `whatsapp.svg`
 * has always mapped to `com.whatsapp`. So picking WhatsApp gives a mapped row
 * with no extra machinery, and a slug no hint recognises arrives unmapped and
 * visible, which is the same failure mode a dropped file already has.
 */
export function GlyphPicker({
  open,
  onClose,
  onPick,
}: {
  open: boolean;
  onClose: () => void;
  onPick: (glyph: GlyphLite) => void;
}) {
  const [q, setQ] = React.useState('');
  const [glyphs, setGlyphs] = React.useState<GlyphLite[]>([]);
  const [loading, setLoading] = React.useState(false);

  React.useEffect(() => {
    if (!open) return;
    let live = true;
    setLoading(true);
    // Debounced, because this fires per keystroke and the route scans a list of
    // three and a half thousand on every call. 180ms is below the threshold
    // where a picker feels laggy and above the rate at which anyone types.
    const t = setTimeout(async () => {
      const found = await fetchGlyphs(q);
      if (!live) return;
      setGlyphs(found);
      setLoading(false);
    }, 180);
    return () => {
      live = false;
      clearTimeout(t);
    };
  }, [q, open]);

  if (!open) return null;

  return (
    <div
      style={{
        border: '0.5px solid var(--border)',
        borderRadius: 12,
        padding: 12,
        background: 'var(--surface-1)',
        display: 'flex',
        flexDirection: 'column',
        gap: 10,
      }}
    >
      <div style={{ ...row, justifyContent: 'space-between' }}>
        <input
          value={q}
          onChange={(e) => setQ(e.target.value)}
          placeholder="whatsapp"
          autoFocus
          style={{ flex: 1, minWidth: 160 }}
          aria-label="search brand glyphs"
        />
        <button onClick={onClose}>Close</button>
      </div>

      <div
        style={{
          display: 'grid',
          gridTemplateColumns: 'repeat(auto-fill, minmax(84px, 1fr))',
          gap: 8,
        }}
      >
        {glyphs.map((g) => (
          <button
            key={g.slug}
            onClick={() => onPick(g)}
            title={g.slug}
            style={{
              display: 'flex',
              flexDirection: 'column',
              alignItems: 'center',
              gap: 6,
              padding: '10px 6px',
            }}
          >
            {/* The BRAND colour here and nowhere else. This is a picker, so an
                icon has to be recognisable in it; what lands in the pack is
                drawn by the composer, which applies the tint or leaves the art
                as authored. */}
            <img
              src={glyphToDataUrl(g, `#${g.hex}`)}
              alt=""
              width={26}
              height={26}
              style={{ display: 'block' }}
            />
            <span
              style={{
                fontSize: 10.5,
                lineHeight: 1.2,
                textAlign: 'center',
                overflow: 'hidden',
                textOverflow: 'ellipsis',
                whiteSpace: 'nowrap',
                maxWidth: '100%',
              }}
            >
              {g.title}
            </span>
          </button>
        ))}
      </div>

      <p style={{ fontSize: 11.5, color: 'var(--text-muted)', lineHeight: 1.6, margin: 0 }}>
        {loading
          ? 'Searching'
          : glyphs.length === 0
            ? 'Nothing matches. The set covers brands, not generic shapes: there is a WhatsApp but no Phone.'
            : 'CC0 artwork. The composed PNG is yours; the brands depicted are not, which is the ordinary position of every icon pack.'}
      </p>
    </div>
  );
}
