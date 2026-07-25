'use client';

import * as React from 'react';

/**
 * The builder tokens, now bound to globals.css.
 *
 * These used to be hardcoded terminal-green hex. They are now thin references to
 * the panel's real design tokens (--color-surface-*, --color-ink*, --color-accent,
 * --color-ok/bad, --font-mono), so the builders inherit exactly one palette and
 * retune whenever globals.css does. Inline styles resolve CSS variables fine, so
 * `background: C.bg` becomes `background: var(--color-surface-0)` with no change
 * at the call sites.
 */
export const C = {
  bg: 'var(--color-surface-0)',
  surface: 'var(--color-surface-1)',
  surface2: 'var(--color-surface-2)',
  raised: 'var(--color-surface-3)',
  ink: 'var(--color-ink)',
  inkStrong: 'var(--color-ink)',
  dim: 'var(--color-ink-2)',
  faint: 'var(--color-ink-3)',
  amber: 'var(--color-accent)',
  onAccent: 'var(--color-accent-ink)',
  green: 'var(--color-ok)',
  red: 'var(--color-bad)',
  warn: 'var(--color-warn)',
  orange: 'var(--color-accent)',
  line: 'var(--color-line)',
  lineSoft: 'var(--color-line-soft)',
  chip: 'var(--color-surface-2)',
  mono: 'var(--font-mono)',
  sans: 'var(--font-sans)',
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
 * Form-control styling for the builder subtree, keyed to `tb-`. Inputs sit on
 * surface-0 with a line border and focus to the accent, matching the panel. No
 * font import here anymore: layout.tsx loads Geist and Geist Mono.
 */
export function ConsoleStyle() {
  return (
    <style
      dangerouslySetInnerHTML={{
        __html: `
.tb-input, .tb-select, .tb-textarea {
  width: 100%; background: ${C.bg}; color: ${C.ink};
  border: 1px solid ${C.line}; border-radius: 8px; padding: 8px 10px;
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
.tb-swatch::-webkit-color-swatch { border: 1px solid ${C.line}; border-radius: 5px; }
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
