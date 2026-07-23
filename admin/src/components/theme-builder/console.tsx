'use client';

import * as React from 'react';

/**
 * The console's palette, which IS G Launcher's terminal theme. One place so the
 * builder, the preview frame and every field agree on ink and accent.
 */
export const C = {
  bg: '#080D08',
  surface: '#0C120C',
  surface2: '#0F160F',
  raised: '#121A12',
  ink: '#C8D8C8',
  inkStrong: '#EAF0EA',
  dim: '#7C8C7E',
  faint: '#54634F',
  amber: '#FFB000',
  green: '#5FCE7B',
  red: '#FF6B63',
  orange: '#E9531F',
  line: 'rgba(200,216,200,0.11)',
  lineSoft: 'rgba(200,216,200,0.06)',
  chip: 'rgba(200,216,200,0.06)',
  mono: "'Ubuntu Mono', ui-monospace, 'SF Mono', Menlo, monospace",
  sans: "'Ubuntu', system-ui, -apple-system, sans-serif",
} as const;

/** #RRGGBB or #AARRGGBB -> a CSS color string, honouring the alpha byte. */
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
 * One-shot global styling for the builder subtree: font import, focus ring,
 * placeholder ink, a thin console scrollbar, and native color-swatch reset. Keyed
 * to the `tb-` prefix so it cannot leak into the rest of the panel.
 */
export function ConsoleStyle() {
  return (
    <style
      dangerouslySetInnerHTML={{
        __html: `
@import url('https://fonts.googleapis.com/css2?family=Ubuntu+Mono:wght@400;700&family=Ubuntu:wght@400;500&display=swap');
.tb-root ::selection { background: ${C.amber}; color: #1A1200; }
.tb-input, .tb-select, .tb-textarea {
  width: 100%; background: ${C.bg}; color: ${C.inkStrong};
  border: 1px solid ${C.line}; border-radius: 7px; padding: 8px 10px;
  font-family: ${C.mono}; font-size: 13px; outline: none; transition: border-color .12s, box-shadow .12s;
}
.tb-input::placeholder, .tb-textarea::placeholder { color: ${C.faint}; }
.tb-input:focus, .tb-select:focus, .tb-textarea:focus {
  border-color: ${C.amber}; box-shadow: 0 0 0 2px rgba(255,176,0,0.18);
}
.tb-select { appearance: none; -webkit-appearance: none; cursor: pointer;
  background-image: linear-gradient(45deg, transparent 50%, ${C.dim} 50%), linear-gradient(135deg, ${C.dim} 50%, transparent 50%);
  background-position: right 12px center, right 7px center; background-size: 5px 5px, 5px 5px; background-repeat: no-repeat;
}
.tb-swatch { -webkit-appearance: none; appearance: none; border: none; padding: 0; background: none; cursor: pointer; }
.tb-swatch::-webkit-color-swatch-wrapper { padding: 0; }
.tb-swatch::-webkit-color-swatch { border: 1px solid ${C.line}; border-radius: 5px; }
.tb-seg { cursor: pointer; transition: color .12s, background .12s; }
.tb-btn { cursor: pointer; transition: background .12s, border-color .12s, opacity .12s; }
.tb-btn:disabled { opacity: .5; cursor: not-allowed; }
.tb-scroll { scrollbar-width: thin; scrollbar-color: ${C.line} transparent; }
.tb-scroll::-webkit-scrollbar { width: 9px; height: 9px; }
.tb-scroll::-webkit-scrollbar-thumb { background: ${C.line}; border-radius: 6px; }
.tb-scroll::-webkit-scrollbar-track { background: transparent; }
.tb-link { color: ${C.amber}; cursor: pointer; }
@media (prefers-reduced-motion: reduce) { .tb-root * { transition: none !important; animation: none !important; } }
`,
      }}
    />
  );
}
