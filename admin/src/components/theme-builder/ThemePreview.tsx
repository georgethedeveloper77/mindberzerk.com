'use client';

import * as React from 'react';
import { C, cssColor } from './console';
import type { ThemeSpecJson } from '@/lib/theme-spec';

/**
 * A phone-sized read of the theme. Not pixel-accurate to the app, deliberately:
 * it answers "is this the distro I meant" at a glance, so it renders the parts
 * that carry a distro's identity, the desktop gradient, the bar, the dock shape,
 * and the terminal, from the palette and layout as you type.
 */
export function ThemePreview({ spec }: { spec: ThemeSpecJson }) {
  const p = spec.palette;
  const bg = `linear-gradient(180deg, ${cssColor(p.bgTop, '#222')}, ${cssColor(p.bgBottom, '#111')})`;
  const onDark = cssColor(p.onDark, '#fff');
  const accent = cssColor(p.accent, C.amber);
  const isTui = spec.shell === 'tui';

  return (
    <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 10 }}>
      <div
        style={{
          width: 232,
          height: 480,
          borderRadius: 26,
          padding: 7,
          background: '#05070522',
          border: `1px solid ${C.line}`,
          boxShadow: '0 20px 50px -20px rgba(0,0,0,0.7)',
          flexShrink: 0,
        }}
      >
        <div
          style={{
            width: '100%',
            height: '100%',
            borderRadius: 20,
            overflow: 'hidden',
            position: 'relative',
            background: isTui ? cssColor(p.bgTop, '#080D08') : bg,
            fontFamily: spec.typography?.mono || C.mono,
          }}
        >
          {isTui ? (
            <Terminal spec={spec} onDark={onDark} accent={accent} />
          ) : (
            <Desktop spec={spec} onDark={onDark} accent={accent} />
          )}
        </div>
      </div>
      <div style={{ fontFamily: C.mono, fontSize: 11.5, color: C.faint }}>
        {spec.shell} · {spec.name || 'untitled'} {spec.version ? `· ${spec.version}` : ''}
      </div>
    </div>
  );
}

function Desktop({
  spec,
  onDark,
  accent,
}: {
  spec: ThemeSpecJson;
  onDark: string;
  accent: string;
}) {
  const p = spec.palette;
  const dockColor = cssColor(p.dock, '#0008');
  const barColor = cssColor(p.bar, '#0006');
  const dockSide = spec.layout.dock;

  const apps = [accent, onDark, accent, onDark];
  const tileR = Math.round((spec.icons?.cornerRadius ?? 0.22) * 22);

  const Tile = ({ c }: { c: string }) => (
    <div
      style={{
        width: 22,
        height: 22,
        borderRadius: tileR,
        background: c,
        opacity: c === onDark ? 0.28 : 1,
        flexShrink: 0,
      }}
    />
  );

  return (
    <>
      {spec.layout.topBar ? (
        <div
          style={{
            height: 22,
            background: barColor,
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'space-between',
            padding: '0 10px',
            color: onDark,
            fontSize: 10,
            letterSpacing: 0.3,
          }}
        >
          <span style={{ opacity: 0.85 }}>Activities</span>
          <span style={{ opacity: 0.7 }}>09:41</span>
        </div>
      ) : null}

      {/* the authentic desktop has no icon grid: just a name watermark */}
      <div
        style={{
          position: 'absolute',
          inset: 0,
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          pointerEvents: 'none',
        }}
      >
        <span style={{ color: onDark, opacity: 0.14, fontSize: 30, fontWeight: 600, fontFamily: spec.typography?.display || C.sans }}>
          {(spec.name || 'G').slice(0, 2)}
        </span>
      </div>

      {dockSide === 'left' ? (
        <div
          style={{
            position: 'absolute',
            left: 8,
            top: spec.layout.topBar ? 34 : 12,
            bottom: 12,
            width: 34,
            borderRadius: 12,
            background: dockColor,
            display: 'flex',
            flexDirection: 'column',
            alignItems: 'center',
            gap: 9,
            paddingTop: 9,
          }}
        >
          {apps.map((c, i) => (
            <Tile key={i} c={c} />
          ))}
        </div>
      ) : null}

      {dockSide === 'bottom' ? (
        <div
          style={{
            position: 'absolute',
            left: 10,
            right: 10,
            bottom: 8,
            height: 34,
            borderRadius: 12,
            background: dockColor,
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            gap: 12,
          }}
        >
          {apps.map((c, i) => (
            <Tile key={i} c={c} />
          ))}
        </div>
      ) : null}
    </>
  );
}

function Terminal({
  spec,
  onDark,
  accent,
}: {
  spec: ThemeSpecJson;
  onDark: string;
  accent: string;
}) {
  const lines = [
    { c: onDark, t: `${(spec.name || 'g-launcher').toLowerCase()} tty` },
    { c: 'rgba(200,216,200,0.5)', t: '────────────────────' },
    { c: onDark, t: 'os   G Launcher' },
    { c: onDark, t: `de   ${spec.shell}` },
    { c: onDark, t: `ver  ${spec.version || '-'}` },
  ];
  return (
    <div style={{ padding: '14px 12px', fontSize: 11, lineHeight: 1.7 }}>
      {lines.map((l, i) => (
        <div key={i} style={{ color: l.c, opacity: 0.9 }}>
          {l.t}
        </div>
      ))}
      <div style={{ marginTop: 10, color: accent }}>
        user@g-tty:~$ <span style={{ color: onDark, opacity: 0.6 }}>▏</span>
      </div>
    </div>
  );
}
