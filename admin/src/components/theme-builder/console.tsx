'use client';

import * as React from 'react';

/**
 * The builder tokens, now bound to the SOFT register.
 *
 * ## Why this one file moves the whole builder
 *
 * These were already thin references to CSS variables rather than hex, which is
 * what makes the migration a retarget rather than a rewrite. Every call site in
 * `primitives.tsx`, `editors.tsx`, `GeneratedJson.tsx`, `ThemePreview.tsx`,
 * `DistroWorkspace.tsx` and `AppGrid.tsx` writes `background: C.surface` and
 * gets whatever this map says. Repointing the map at `--color-site-*` moves all
 * six files at once, with no diff in any of them.
 *
 * ## Why they had to move at all
 *
 * The builder sat inside the dark console shell, so a dark tool inside a dark
 * frame was at least coherent. Every screen around it is now on the soft
 * register, and a dark tool on a light page is not a deliberate flavour, it is
 * two products meeting at a panel edge.
 *
 * ## The two names that no longer describe themselves
 *
 * `amber` is the accent, which is violet now, and `orange` is the same thing.
 * They are kept because renaming them would touch every call site, which is
 * precisely the diff this approach exists to avoid. The values are what matter.
 *
 * ## `onAccent` IS A LITERAL, AND DELIBERATELY
 *
 * It is the text colour sitting ON the accent fill, and the accent is violet in
 * both light and dark. `--color-site-solid-ink` inverts with the theme, so
 * using it here would put dark text on violet in dark mode. White is correct in
 * both, so white it is.
 */
export const C = {
  /** The recessed surface: input fills, tracks, wells. */
  bg: 'var(--color-site-sunk)',
  /** A card. Panels inside a panel read as nested cards, which is intended. */
  surface: 'var(--color-site-card)',
  surface2: 'var(--color-site-sunk)',
  raised: 'var(--color-site-sunk)',
  ink: 'var(--color-site-ink)',
  inkStrong: 'var(--color-site-ink)',
  dim: 'var(--color-site-ink-2)',
  faint: 'var(--color-site-ink-3)',
  /** The accent. Named amber from the terminal era; it is violet now. */
  amber: 'var(--color-site-accent)',
  onAccent: '#ffffff',
  green: 'var(--color-site-ok)',
  red: 'var(--color-site-bad)',
  warn: 'var(--color-site-plan)',
  orange: 'var(--color-site-accent)',
  line: 'var(--color-site-line)',
  /** One hairline in this register. The console had two; the soft one does not
   *  need a second, and mapping both here keeps every call site working. */
  lineSoft: 'var(--color-site-line)',
  chip: 'var(--color-site-sunk)',
  mono: 'var(--font-mono)',
  sans: 'var(--font-site-sans)',
} as const;

/** #RRGGBB or #AARRGGBB -> a CSS color string, honouring the alpha byte. Used
 *  only for the THEME being previewed, never for panel chrome. */
export function cssColor(hex: string | null | undefined, fallback = 'transparent'): string {
  if (!hex) return fallback;
  const s = hex.trim().replace(/^#/, '');
  if (s.length === 6) return `#${s}`;
  if (s.length === 8) {
    const a = parseInt(s.slice(0, 2), 16) / 255;
    const r = parseInt(s.slice(2, 4), 16);
    const g = parseInt(s.slice(4, 6), 16);
    const b = parseInt(s.slice(6, 8), 16);
    if ([a, r, g, b].some(Number.isNaN)) return fallback;
    return `rgba(${r},${g},${b},${a.toFixed(3)})`;
  }
  return fallback;
}

/**
 * Form-control styling for the builder subtree, keyed to `tb-`.
 *
 * Radii and paddings moved up slightly to match the soft register's controls,
 * where an 8px radius beside an 11px one is the kind of half-millimetre
 * mismatch that makes a screen feel assembled rather than designed. The focus
 * treatment stays a border plus a ring, which is the one thing the console got
 * exactly right for a form this dense.
 */
export function ConsoleStyle() {
  return (
    <style
      dangerouslySetInnerHTML={{
        __html: `
.tb-input, .tb-select, .tb-textarea {
  width: 100%; background: ${C.bg}; color: ${C.ink};
  border: 1px solid ${C.line}; border-radius: 11px; padding: 9px 12px;
  font-family: ${C.mono}; font-size: 13px; outline: none; transition: border-color .12s, box-shadow .12s;
}
.tb-input::placeholder, .tb-textarea::placeholder { color: ${C.faint}; }
.tb-input:focus, .tb-select:focus, .tb-textarea:focus {
  border-color: ${C.amber}; box-shadow: 0 0 0 1px ${C.amber};
}
.tb-select { appearance: none; -webkit-appearance: none; cursor: pointer;
  background-image: linear-gradient(45deg, transparent 50%, ${C.faint} 50%), linear-gradient(135deg, ${C.faint} 50%, transparent 50%);
  background-position: right 12px center, right 7px center; background-size: 5px 5px, 5px 5px; background-repeat: no-repeat;
}
.tb-swatch { -webkit-appearance: none; appearance: none; border: none; padding: 0; background: none; cursor: pointer; }
.tb-swatch::-webkit-color-swatch-wrapper { padding: 0; }
.tb-swatch::-webkit-color-swatch { border: 1px solid ${C.line}; border-radius: 8px; }
.tb-seg { cursor: pointer; transition: color .12s, background .12s; }
.tb-btn { cursor: pointer; transition: background .12s, border-color .12s, opacity .12s, filter .12s; }
.tb-btn:hover:not(:disabled) { filter: brightness(1.08); }
.tb-btn:disabled { opacity: .5; cursor: not-allowed; }
.tb-scroll { scrollbar-width: thin; scrollbar-color: ${C.line} transparent; }
.tb-scroll::-webkit-scrollbar { width: 9px; height: 9px; }
.tb-scroll::-webkit-scrollbar-thumb { background: ${C.line}; border-radius: 6px; }
.tb-scroll::-webkit-scrollbar-track { background: transparent; }
@media (prefers-reduced-motion: reduce) { .tb-root * { transition: none !important; animation: none !important; } }
`,
      }}
    />
  );
}
