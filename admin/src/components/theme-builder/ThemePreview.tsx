'use client';

import * as React from 'react';
import { C, cssColor } from './console';
import type { PanelJson, ThemeSpecJson } from '@/lib/g-launcher/theme-spec';

type PanelModule = PanelJson['modules'][number];

/**
 * A phone-sized read of the theme.
 *
 * The CHROME around it (caption, the light/dark segmented control, the bezel)
 * follows the panel; everything INSIDE the screen is the theme's own colours,
 * resolved through `cssColor`, and must never be touched by a panel restyle.
 * That separation is why this component needed no work when the register moved.
 *
 * Not pixel-accurate to the app, deliberately:
 * it answers "is this the distro I meant" at a glance, so it renders the parts
 * that carry a distro's identity, the desktop gradient, the bar, the dock shape,
 * and the terminal, from the palette and layout as you type.
 */
export function ThemePreview({ spec }: { spec: ThemeSpecJson }) {
  // Which variant is on show. Defaults to dark, because `palette` is the dark
  // one and every distro has it; the toggle only appears once a light block
  // exists, so it cannot offer a mode that would render as a copy of dark.
  const [light, setLight] = React.useState(false);
  const showLight = light && !!spec.paletteLight;
  const p = showLight ? spec.paletteLight! : spec.palette;
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
          // A LITERAL, and correct: this is phone hardware, not panel chrome.
          // It was '#05070522', a near-transparent black that reads as a grey
          // haze once the card behind it is light.
          background: '#17121f',
          border: `1px solid ${C.line}`,
          boxShadow: '0 16px 36px -16px rgba(23,16,31,0.45)',
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
            <Desktop spec={spec} palette={p} onDark={onDark} accent={accent} />
          )}
        </div>
      </div>
      <div style={{ fontFamily: C.mono, fontSize: 11.5, color: C.faint }}>
        {spec.shell} · {spec.name || 'untitled'} {spec.version ? `· ${spec.version}` : ''}
      </div>

      {spec.paletteLight ? (
        <div style={{ display: 'inline-flex', border: `1px solid ${C.line}`, borderRadius: 7, overflow: 'hidden' }}>
          {([false, true] as const).map((v, i) => (
            <button
              key={String(v)}
              type="button"
              className="tb-seg"
              onClick={() => setLight(v)}
              style={{
                padding: '5px 12px',
                fontFamily: C.mono,
                fontSize: 11.5,
                border: 'none',
                borderLeft: i === 0 ? 'none' : `1px solid ${C.line}`,
                background: light === v ? C.amber : 'transparent',
                color: light === v ? C.onAccent : C.dim,
              }}
            >
              {v ? 'light' : 'dark'}
            </button>
          ))}
        </div>
      ) : null}
    </div>
  );
}

/** dp to preview pixels: a 360dp-wide phone drawn 218px wide. */
const K = 218 / 360;

type Starter = { col?: number; row?: number; spanX?: number; spanY?: number };

function starters(spec: ThemeSpecJson): Starter[] {
  const d = spec.desklets as { starter?: unknown } | undefined;
  return Array.isArray(d?.starter)
    ? (d!.starter as Starter[]).filter((s) => s && typeof s === 'object')
    : [];
}

/**
 * The desktop, drawn from the layout rather than guessed at.
 *
 * Panels from `layout.panels` on their own edges at their own thickness, the
 * dock on its side in its style, the Search pill, the starter widgets at their
 * fine-grid positions, and the icon grid in the space they leave. Every one of
 * these is what makes two distros look different at thumbnail size, which the
 * old two-letter watermark could not say about any of them.
 */
function Desktop({
  spec,
  palette,
  onDark,
  accent,
}: {
  spec: ThemeSpecJson;
  // Passed in rather than read off the spec, so the light toggle above reaches
  // the bar and dock instead of only the background gradient.
  palette: ThemeSpecJson['palette'];
  onDark: string;
  accent: string;
}) {
  const p = palette;
  const L = spec.layout;
  const dockColor = cssColor(p.dock, '#0008');
  const barColor = cssColor(p.bar, '#0006');
  const glass = (L as { material?: string }).material === 'glass';
  const tileR = Math.round((spec.icons?.cornerRadius ?? 0.22) * 22);

  const statusH = L.statusBar === false ? 0 : 14;
  const panels =
    L.panels && L.panels.length
      ? L.panels
      : L.topBar
        ? [{ side: 'top' as const, modules: ['activities', 'spacer', 'clock', 'spacer', 'tray'] as PanelModule[] }]
        : [];
  const thick = (h?: number) => Math.max(14, Math.round((h ?? 32) * K));
  const edge = (side: string) => panels.find((x) => x.side === side);
  const top = edge('top');
  const bottom = edge('bottom');
  const left = edge('left');
  const right = edge('right');

  const dock = L.dock;
  const floating = L.dockStyle !== 'flat';
  const dockH = 40;
  const searchPill = (L as { homeSearch?: string }).homeSearch === 'pill';
  const launcherSlot = (L as { dockLauncher?: boolean }).dockLauncher !== false;

  const area = {
    top: statusH + (top ? thick(top.height) : 0),
    bottom:
      (bottom ? thick(bottom.height) : 0) +
      (dock === 'bottom' ? dockH + (floating ? 10 : 0) : 0) +
      (searchPill ? 22 : 0) +
      6,
    left: (left ? thick(left.height) : 0) + (dock === 'left' ? 46 : 0) + 6,
    right: (right ? thick(right.height) : 0) + 6,
  };

  const rows = L.grid?.rows ?? 5;
  const cols = L.grid?.cols ?? 4;
  const fineCols = cols * 2;
  const fineRows = rows * 3;
  const sts = starters(spec);

  const Bar = ({ panel, vertical }: { panel: PanelJson; vertical: boolean }) => (
    <div
      style={{
        display: 'flex',
        flexDirection: vertical ? 'column' : 'row',
        alignItems: 'center',
        gap: 5,
        padding: vertical ? '6px 0' : '0 6px',
        width: '100%',
        height: '100%',
        color: onDark,
        fontSize: 8.5,
      }}
    >
      {panel.modules.map((m, i) => {
        const key = `${m}-${i}`;
        if (m === 'spacer') return <span key={key} style={{ flex: 1 }} />;
        if (m === 'kickoff' || m === 'activities' || m === 'appsButton') {
          return <span key={key} style={{ width: 9, height: 9, borderRadius: 3, background: accent }} />;
        }
        if (m === 'tasks') {
          return (
            <span key={key} style={{ display: 'flex', flexDirection: vertical ? 'column' : 'row', gap: 3 }}>
              {[0, 1, 2].map((t) => (
                <span key={t} style={{ width: 8, height: 8, borderRadius: 2, background: onDark, opacity: 0.45 }} />
              ))}
            </span>
          );
        }
        if (m === 'clock') return <span key={key} style={{ opacity: 0.85 }}>9:41</span>;
        if (m === 'pager' || m === 'workspacesButton') {
          return <span key={key} style={{ width: 9, height: 9, borderRadius: 2, border: `1px solid ${onDark}`, opacity: 0.7 }} />;
        }
        if (m === 'tray') return <span key={key} style={{ fontSize: 9, opacity: 0.85 }}>⚙</span>;
        return <span key={key} style={{ width: 4, height: 4, borderRadius: 2, background: onDark, opacity: 0.5 }} />;
      })}
    </div>
  );

  const panelStyle = (side: string, h?: number): React.CSSProperties => {
    const t = thick(h);
    const tilingFloat = spec.shell === 'tiling' && (L as { barStyle?: string }).barStyle !== 'edge';
    const inset = tilingFloat ? 4 : 0;
    const base: React.CSSProperties = {
      position: 'absolute',
      background: (L as { barStyle?: string }).barStyle === 'clear' ? 'transparent' : barColor,
      borderRadius: tilingFloat ? 6 : 0,
    };
    if (side === 'top') return { ...base, top: statusH + inset, left: inset, right: inset, height: t };
    if (side === 'bottom') return { ...base, bottom: inset, left: inset, right: inset, height: t };
    if (side === 'left') return { ...base, left: inset, top: statusH, bottom: 0, width: t };
    return { ...base, right: inset, top: statusH, bottom: 0, width: t };
  };

  const glassBg = 'linear-gradient(180deg, rgba(255,255,255,0.28), rgba(255,255,255,0.08))';

  return (
    <>
      {statusH > 0 && (
        <div style={{ position: 'absolute', top: 0, left: 0, right: 0, height: statusH, display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '0 10px', color: onDark, fontSize: 8, opacity: 0.8 }}>
          <span>09:41</span>
          <span>▮▮ 80%</span>
        </div>
      )}

      {panels.map((panel, i) => (
        <div key={i} style={panelStyle(panel.side, panel.height)}>
          <Bar panel={panel} vertical={panel.side === 'left' || panel.side === 'right'} />
        </div>
      ))}

      {/* The work area: starter widgets on the fine grid, icons where the
          desktop shows them. */}
      <div style={{ position: 'absolute', top: area.top + 6, bottom: area.bottom, left: area.left, right: area.right }}>
        {sts.map((d, i) => {
          const c = Math.max(0, Math.min(fineCols - 1, d.col ?? 0));
          const r = Math.max(0, Math.min(fineRows - 1, d.row ?? 0));
          const w = Math.max(1, Math.min(fineCols - c, d.spanX ?? 4));
          const h = Math.max(1, Math.min(fineRows - r, d.spanY ?? 3));
          return (
            <div
              key={i}
              style={{
                position: 'absolute',
                left: `${(c / fineCols) * 100}%`,
                top: `${(r / fineRows) * 100}%`,
                width: `calc(${(w / fineCols) * 100}% - 4px)`,
                height: `calc(${(h / fineRows) * 100}% - 4px)`,
                borderRadius: glass ? 10 : 6,
                background: glass ? glassBg : barColor,
                border: `1px solid rgba(255,255,255,${glass ? 0.3 : 0.08})`,
              }}
            />
          );
        })}
        {L.desktopIcons !== false && (
          <div style={{ position: 'absolute', inset: 0, display: 'grid', gridTemplateColumns: `repeat(${cols}, 1fr)`, gridTemplateRows: `repeat(${rows}, 1fr)`, placeItems: 'center' }}>
            {Array.from({ length: rows * cols }).map((_, i) => {
              const cc = i % cols;
              const rr = Math.floor(i / cols);
              const covered = sts.some((d) => {
                const c0 = (d.col ?? 0) / 2;
                const r0 = (d.row ?? 0) / 3;
                const c1 = c0 + (d.spanX ?? 4) / 2;
                const r1 = r0 + (d.spanY ?? 3) / 3;
                return cc + 0.5 > c0 && cc + 0.5 < c1 && rr + 0.5 > r0 && rr + 0.5 < r1;
              });
              return (
                <span
                  key={i}
                  style={{ width: 20, height: 20, borderRadius: tileR * 0.9, background: onDark, opacity: covered ? 0 : 0.22 }}
                />
              );
            })}
          </div>
        )}
      </div>

      {searchPill && dock === 'bottom' && (
        <div style={{ position: 'absolute', left: '50%', transform: 'translateX(-50%)', bottom: (bottom ? thick(bottom.height) : 0) + dockH + 14, height: 14, padding: '0 8px', borderRadius: 7, background: glassBg, color: onDark, fontSize: 7.5, display: 'flex', alignItems: 'center' }}>
          ⌕ Search
        </div>
      )}

      {dock === 'left' && (
        <div style={{ position: 'absolute', left: (left ? thick(left.height) : 0) + 6, top: area.top + 6, bottom: 12, width: 36, borderRadius: 12, background: glass ? glassBg : dockColor, display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 8, paddingTop: 8 }}>
          {[accent, onDark, accent, onDark].map((c, i) => (
            <span key={i} style={{ width: 22, height: 22, borderRadius: tileR, background: c, opacity: c === onDark ? 0.28 : 1 }} />
          ))}
        </div>
      )}

      {dock === 'bottom' && (
        <div
          style={{
            position: 'absolute',
            left: floating ? 14 : 0,
            right: floating ? 14 : 0,
            bottom: (bottom ? thick(bottom.height) : 0) + (floating ? 8 : 0),
            height: dockH,
            borderRadius: floating ? 14 : '10px 10px 0 0',
            background: glass ? glassBg : dockColor,
            border: glass ? '1px solid rgba(255,255,255,0.3)' : 'none',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            gap: 12,
          }}
        >
          {[accent, onDark, accent, onDark].map((c, i) => (
            <span key={i} style={{ width: 24, height: 24, borderRadius: tileR, background: c, opacity: c === onDark ? 0.28 : 1 }} />
          ))}
          {launcherSlot && <span style={{ color: onDark, fontSize: 12, opacity: 0.8 }}>⠿</span>}
        </div>
      )}
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
