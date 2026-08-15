'use client';

import * as React from 'react';
import { C, cssColor } from './console';
import type { ThemeSpecJson } from '@/lib/g-launcher/theme-spec';

/**
 * WHAT THE GENERATED ICONS WILL LOOK LIKE, as you type.
 *
 * ## Why this exists
 *
 * `IconStyle` carries ten fields and the builder now offers all ten, but until
 * this there was nothing to look at: `ThemePreview` reads exactly one of them,
 * `cornerRadius`, and paints four flat squares in the palette's own colours.
 * So a distro's entire icon identity was authored blind and only became visible
 * on a phone, after a publish and a sync.
 *
 * That is the actual blocker on eleven drafted distros. None of them has a hero
 * pack, none of them needs one, and the reason none of them shipped is that
 * nobody could see what "Kali with a dark plate and a blue tint" would look
 * like without building it.
 *
 * ## What is honest here and what is not
 *
 * The SHAPES, the plate, the gradient and the tint are exact: they are the same
 * four numbers the device renders from, and CSS can express all of them.
 *
 * The FOREGROUNDS are stand-ins. On device, `BrandIconResolver` supplies a real
 * Simple Icons path for anything in its CC0 set and `IconRenderer` generates
 * from the app's own artwork for the rest, so a real screen is more varied than
 * this. Six neutral glyphs answer the question this panel is for, which is
 * whether the PLATE reads as the distro.
 *
 * `monochromeTint` is the one that flatters itself most. It only applies to
 * apps that ship a monochrome layer, so a real grid keeps more of its original
 * colour than the tinted row below suggests. The panel says so rather than
 * letting the picture imply otherwise.
 *
 * ## No wallpaper behind it, deliberately
 *
 * A draft's wallpapers are uploads that have not been published, so there is no
 * public URL to draw them from, and resolving one would mean this component
 * knowing about the draft asset store. The palette gradient is what the device
 * paints before a wallpaper resolves anyway, so it is the honest floor rather
 * than a placeholder.
 */
export function IconStylePreview({ spec }: { spec: ThemeSpecJson }) {
  const icons = spec.icons ?? {};
  const p = spec.palette;

  const plate = icons.backgroundColor
    ? cssColor(icons.backgroundColor, '#333')
    : null;
  const gradientEnd = icons.backgroundGradientEnd
    ? cssColor(icons.backgroundGradientEnd, '#555')
    : null;
  const angle = icons.gradientAngle ?? 135;
  const tint = icons.monochromeTint
    ? cssColor(icons.monochromeTint, '#fff')
    : cssColor(p.accent, C.amber);
  const scale = icons.foregroundScale ?? 1;

  // The plate, as one CSS background. A gradient END with no start is not a
  // gradient, so it falls back to the accent rather than rendering a band that
  // fades out of nothing: the device does the same, and a preview that
  // disagreed would be worse than one that refused.
  const start = plate ?? cssColor(p.accent, C.amber);
  const fill = gradientEnd
    ? `linear-gradient(${angle}deg, ${start}, ${gradientEnd})`
    : start;

  // ── SHAPE ────────────────────────────────────────────────────────────────
  //
  // Five of the six treatments are a border-radius. `teardrop` is three round
  // corners and one square one, which is exactly what the name describes and
  // what the device draws. `original` means no plate at all: the art keeps its
  // own silhouette, so it renders as art on nothing rather than as a square
  // with a radius of zero, which would be `square`.
  const size = 46;
  const r = (icons.cornerRadius ?? 0.22) * size;
  const treatment = icons.treatment ?? 'roundedSquare';
  const radius =
    treatment === 'circle'
      ? '50%'
      : treatment === 'square'
        ? '0'
        : treatment === 'squircle'
          ? `${Math.min(size * 0.36, r * 1.5)}px`
          : treatment === 'teardrop'
            ? `${r}px ${r}px ${r}px 2px`
            : `${r}px`;
  const bare = treatment === 'original';

  const glyphs = ['browser', 'camera', 'message', 'settings', 'music', 'mail'];

  const Icon = ({ i }: { i: number }) => (
    <div
      style={{
        width: size,
        height: size,
        borderRadius: bare ? 0 : radius,
        background: bare ? 'transparent' : fill,
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        flexShrink: 0,
      }}
    >
      <div
        style={{
          width: size * 0.46 * scale,
          height: size * 0.46 * scale,
          borderRadius: i % 3 === 0 ? '50%' : 4,
          background: tint,
          opacity: 0.92,
        }}
      />
    </div>
  );

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
      <div
        style={{
          borderRadius: 14,
          padding: '18px 16px',
          background: `linear-gradient(180deg, ${cssColor(p.bgTop, '#222')}, ${cssColor(p.bgBottom, '#111')})`,
          border: `1px solid ${C.line}`,
        }}
      >
        <div
          style={{
            display: 'grid',
            gridTemplateColumns: 'repeat(3, 1fr)',
            gap: 16,
            justifyItems: 'center',
          }}
        >
          {glyphs.map((g, i) => (
            <Icon key={g} i={i} />
          ))}
        </div>
      </div>

      <div
        style={{
          fontFamily: C.mono,
          fontSize: 10.5,
          color: C.faint,
          lineHeight: 1.7,
        }}
      >
        <div>
          {treatment}
          {bare ? ' · no plate' : ` · r ${(icons.cornerRadius ?? 0.22).toFixed(2)}`}
          {gradientEnd ? ` · gradient ${angle}deg` : ''}
        </div>
        <div>
          Plates and shapes are exact. Foregrounds are stand-ins: real ones come
          from the CC0 brand set and the generator, so a real grid keeps more of
          its own colour than this does.
        </div>
        {icons.heroPack ? (
          <div style={{ color: C.amber }}>
            heroPack {icons.heroPack} overrides all of this for the apps it
            covers.
          </div>
        ) : null}
      </div>
    </div>
  );
}
