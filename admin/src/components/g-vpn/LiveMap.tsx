'use client';

import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { useCallback, useEffect, useMemo, useRef, useState } from 'react';

import type { Realtime } from '@/lib/g-vpn/realtime';
import world from '@/lib/g-vpn/world-map.json';

export interface LiveData {
  minutes: number;
  realtime: Realtime;
  free: { code: string; count: number; fast: number; good: number; slow: number }[];
  freeDown: number;
  freeNote: string | null;
  gservers: { name: string; country: string | null; online: boolean; peers: number; load: number | null }[];
  tests: { code: string; tests: number; providers: { isp: string; down: number }[] }[];
  testsNote: string | null;
  providers: { code: string; name: string; org: string; color: string | null; users: number; ratings: number; average: number | null }[];
  providersNote: string | null;
}

type Layer = 'people' | 'routes' | 'gservers' | 'free' | 'tests' | 'ratings';

// The map is always dark: a live board reads best that way in either theme.
const C = {
  bg: '#0B0912',
  panel: 'rgba(18,15,28,.88)',
  line: '#2A2438',
  land: '#1A1626',
  landLine: '#2E2840',
  text: '#EEEAF6',
  muted: '#A49DB8',
  cyan: '#2DD4BF',
  violet: '#8B7CF6',
  blue: '#6EA8FF',
  green: '#34D399',
  amber: '#FBBF24',
  pink: '#F472B6',
  red: '#F87171',
};

const W = world.width;
const H = world.height;
const paths: Record<string, string> = world.paths;
// Each centre is [x, y] on the map's own 1200 by 560 grid.
const centres: Record<string, number[]> = world.centres;
const REFRESH_MS = 30_000;

const regionName = (() => {
  try {
    const names = new Intl.DisplayNames(['en'], { type: 'region' });
    return (code: string) => names.of(code) ?? code;
  } catch {
    return (code: string) => code;
  }
})();

/**
 * The live map: countries tinted by people in the app now, arcs to the
 * server countries they connect to, the servers, speed tests and ratings,
 * and a minute-by-minute strip of the last half hour. Click a country to
 * focus it. Refreshes itself every 30 seconds.
 */
export function LiveMap({ data }: { data: LiveData }) {
  const router = useRouter();
  const [layers, setLayers] = useState<Record<Layer, boolean>>({
    people: true,
    routes: true,
    gservers: true,
    free: true,
    tests: false,
    ratings: false,
  });
  const [focus, setFocus] = useState<string | null>(null);
  const [age, setAge] = useState(0);

  useEffect(() => {
    setAge(0);
    const tick = setInterval(() => setAge((a) => a + 1), 1000);
    const refresh = setInterval(() => router.refresh(), REFRESH_MS);
    return () => {
      clearInterval(tick);
      clearInterval(refresh);
    };
  }, [router, data]);

  const rt = data.realtime.ok ? data.realtime.data : null;
  const people = useMemo(() => new Map((rt?.byCountry ?? []).map((c) => [c.code, c.users])), [rt]);
  const busiest = Math.max(1, ...people.values());
  const testsBy = useMemo(() => new Map(data.tests.map((t) => [t.code, t.tests])), [data.tests]);
  const ratingsBy = useMemo(() => {
    const m = new Map<string, number>();
    for (const p of data.providers) m.set(p.code, (m.get(p.code) ?? 0) + p.ratings);
    return m;
  }, [data.providers]);

  const counts: Record<Layer, string> = {
    people: rt ? rt.people.toLocaleString() : '--',
    routes: rt ? rt.routes.reduce((n, r) => n + r.count, 0).toLocaleString() : '--',
    gservers: String(data.gservers.filter((g) => g.online).length),
    free: data.free.reduce((n, f) => n + f.count, 0).toLocaleString(),
    tests: data.tests.reduce((n, t) => n + t.tests, 0).toLocaleString(),
    ratings: data.providers.reduce((n, p) => n + p.ratings, 0).toLocaleString(),
  };
  const layerInfo: { key: Layer; label: string; color: string }[] = [
    { key: 'people', label: 'People now', color: C.blue },
    { key: 'routes', label: 'Connections', color: C.amber },
    { key: 'gservers', label: 'G Servers', color: C.green },
    { key: 'free', label: 'Free servers', color: C.cyan },
    { key: 'tests', label: 'Speed tests', color: C.pink },
    { key: 'ratings', label: 'Ratings', color: C.violet },
  ];

  // ── the view: wheel or buttons to zoom, drag to pan, click a country ──
  const [view, setView] = useState({ k: 1, x: 0, y: 0 });
  const [animate, setAnimate] = useState(false);
  const [hover, setHover] = useState<{ code: string; x: number; y: number } | null>(null);
  const svgRef = useRef<SVGSVGElement>(null);
  const boxRef = useRef<HTMLDivElement>(null);
  const drag = useRef<{ x: number; y: number; vx: number; vy: number; moved: boolean } | null>(null);
  const dragged = useRef(false);

  const clamp = useCallback((v: { k: number; x: number; y: number }) => {
    const k = Math.min(12, Math.max(1, v.k));
    return { k, x: Math.min(0, Math.max(W - W * k, v.x)), y: Math.min(0, Math.max(H - H * k, v.y)) };
  }, []);

  /** Screen point to map units. */
  const toMap = useCallback((clientX: number, clientY: number) => {
    const r = svgRef.current?.getBoundingClientRect();
    if (!r) return { px: W / 2, py: H / 2, f: 1 };
    const f = W / r.width;
    return { px: (clientX - r.left) * f, py: (clientY - r.top) * f, f };
  }, []);

  const zoomAt = useCallback(
    (px: number, py: number, factor: number, smooth = false) => {
      setAnimate(smooth);
      setView((v) => {
        const k = Math.min(12, Math.max(1, v.k * factor));
        return clamp({ k, x: px - ((px - v.x) * k) / v.k, y: py - ((py - v.y) * k) / v.k });
      });
    },
    [clamp],
  );

  const focusOn = (code: string | null) => {
    setAnimate(true);
    setFocus(code);
    if (!code) {
      setView({ k: 1, x: 0, y: 0 });
      return;
    }
    const [cx, cy] = centres[code] ?? [W / 2, H / 2];
    setView(clamp({ k: 4, x: W / 2 - cx * 4, y: H / 2 - cy * 4 }));
  };

  // Wheel zoom needs a non-passive listener to stop the page scrolling.
  useEffect(() => {
    const el = svgRef.current;
    if (!el) return;
    const onWheel = (e: WheelEvent) => {
      e.preventDefault();
      const { px, py } = toMap(e.clientX, e.clientY);
      zoomAt(px, py, e.deltaY < 0 ? 1.2 : 1 / 1.2);
    };
    el.addEventListener('wheel', onWheel, { passive: false });
    return () => el.removeEventListener('wheel', onWheel);
  }, [toMap, zoomAt]);

  const hoverAt = (code: string, e: React.PointerEvent) => {
    const r = boxRef.current?.getBoundingClientRect();
    if (r) setHover({ code, x: e.clientX - r.left, y: e.clientY - r.top });
  };

  const transform = `translate(${view.x} ${view.y}) scale(${view.k})`;
  const sw = (n: number) => n / view.k;

  return (
    <section
      className="relative overflow-hidden rounded-[20px] border"
      style={{ background: `radial-gradient(900px 500px at 45% 40%, #16122A, ${C.bg} 70%)`, borderColor: C.line, color: C.text }}
    >
      <style>{`
        @keyframes lm-ping { 0% { transform: scale(.4); opacity: .7 } 100% { transform: scale(1.5); opacity: 0 } }
        @keyframes lm-flow { to { stroke-dashoffset: -29 } }
        @keyframes lm-blink { 0%, 100% { opacity: 1 } 50% { opacity: .3 } }
        .lm-ping { animation: lm-ping 2.4s ease-out infinite; transform-box: fill-box; transform-origin: center }
        .lm-flow { animation: lm-flow 1.6s linear infinite }
        .lm-blink { animation: lm-blink 1.4s ease-in-out infinite }
        .lm-zoom { transition: transform .7s cubic-bezier(.2,.8,.2,1) }
        @media (prefers-reduced-motion: reduce) { .lm-ping, .lm-flow, .lm-blink { animation: none } .lm-zoom { transition: none } }
      `}</style>

      <div className="grid lg:grid-cols-[1fr_340px]">
        {/* ── the map ── */}
        <div className="relative min-h-[560px]">
          <div className="flex flex-wrap items-center gap-3 px-5 pt-4">
            <span
              className="inline-flex h-7 items-center gap-1.5 rounded-full px-3 text-[12px] font-extrabold"
              style={{ background: 'rgba(52,211,153,.14)', color: C.green }}
            >
              <span className="lm-blink size-[7px] rounded-full" style={{ background: C.green }} />
              LIVE · {age < 2 ? 'just now' : `${age} s ago`}
            </span>
            {(focus || view.k > 1) && (
              <button
                type="button"
                onClick={() => focusOn(null)}
                className="h-8 rounded-[10px] border px-3 text-[12.5px] font-bold"
                style={{ borderColor: C.line, background: C.panel }}
              >
                Back to world
              </button>
            )}
            <div className="ml-auto flex rounded-[11px] border p-0.5" style={{ borderColor: C.line, background: C.panel }}>
              {[5, 30].map((m) => (
                <Link
                  key={m}
                  href={`?m=${m}`}
                  scroll={false}
                  className="rounded-[8px] px-3 py-1.5 text-[12px] font-bold"
                  style={{ background: data.minutes === m ? '#2A2440' : 'transparent', color: data.minutes === m ? C.text : C.muted }}
                >
                  {m} min
                </Link>
              ))}
            </div>
          </div>

          <div ref={boxRef} className="relative mt-2">
          <svg
            ref={svgRef}
            viewBox={`0 0 ${W} ${H}`}
            className="block h-auto w-full cursor-grab touch-none select-none active:cursor-grabbing"
            role="img"
            aria-label={focus ? `Map focused on ${regionName(focus)}` : 'World map of G VPN now'}
            onPointerDown={(e) => {
              drag.current = { x: e.clientX, y: e.clientY, vx: view.x, vy: view.y, moved: false };
              dragged.current = false;
            }}
            onPointerMove={(e) => {
              const d = drag.current;
              if (!d) return;
              const { f } = toMap(e.clientX, e.clientY);
              const dx = (e.clientX - d.x) * f;
              const dy = (e.clientY - d.y) * f;
              if (!d.moved && Math.abs(dx) + Math.abs(dy) < 6) return;
              if (!d.moved) e.currentTarget.setPointerCapture(e.pointerId);
              d.moved = true;
              setHover(null);
              setAnimate(false);
              setView((v) => clamp({ k: v.k, x: d.vx + dx, y: d.vy + dy }));
            }}
            onPointerUp={() => {
              dragged.current = drag.current?.moved ?? false;
              drag.current = null;
            }}
            onPointerLeave={() => setHover(null)}
            onDoubleClick={(e) => {
              const { px, py } = toMap(e.clientX, e.clientY);
              zoomAt(px, py, 2, true);
            }}
          >
            <g className={animate ? 'lm-zoom' : ''} transform={transform}>
              {Object.entries(paths).map(([code, d]) => {
                const u = layers.people ? (people.get(code) ?? 0) / busiest : 0;
                const on = code === focus;
                const over = hover?.code === code;
                return (
                  <path
                    key={code}
                    d={d}
                    onClick={() => {
                      // A drag that ends on a country is a pan, not a pick.
                      if (dragged.current) return;
                      focusOn(code === focus ? null : code);
                    }}
                    onPointerMove={(e) => !drag.current?.moved && hoverAt(code, e)}
                    onPointerLeave={() => setHover((h) => (h?.code === code ? null : h))}
                    fill={
                      on
                        ? 'rgba(45,212,191,.32)'
                        : u > 0
                          ? `rgba(139,124,246,${(0.14 + 0.5 * u + (over ? 0.15 : 0)).toFixed(2)})`
                          : over
                            ? '#251F36'
                            : C.land
                    }
                    stroke={on || over ? C.cyan : u > 0 ? 'rgba(139,124,246,.55)' : C.landLine}
                    strokeWidth={sw(on ? 1.6 : over ? 1.2 : 0.6)}
                  />
                );
              })}

              {layers.routes &&
                rt?.routes.map((r) => {
                  const a = centres[r.from];
                  const b = centres[r.to];
                  if (!a || !b || r.from === r.to) return null;
                  const mx = (a[0] + b[0]) / 2;
                  const my = (a[1] + b[1]) / 2 - Math.abs(b[0] - a[0]) * 0.28 - 10;
                  const d = `M${a[0]},${a[1]} Q${mx},${my} ${b[0]},${b[1]}`;
                  const w = Math.min(3.2, 0.8 + Math.log2(1 + r.count) * 0.5);
                  return (
                    <g key={`${r.from}-${r.to}`}>
                      <path d={d} fill="none" stroke={C.amber} strokeOpacity={0.5} strokeWidth={sw(w)} />
                      <path
                        d={d}
                        className="lm-flow"
                        fill="none"
                        stroke={C.amber}
                        strokeWidth={sw(w + 1)}
                        strokeDasharray={`${sw(3)} ${sw(26)}`}
                        strokeLinecap="round"
                      />
                    </g>
                  );
                })}

              {layers.free &&
                data.free.map((f) => {
                  const at = centres[f.code];
                  if (!at) return null;
                  const s = sw(2.5 + Math.sqrt(f.count) * 0.9);
                  return (
                    <rect
                      key={`f-${f.code}`}
                      x={at[0] - s + sw(9)}
                      y={at[1] - s}
                      width={s * 2}
                      height={s * 2}
                      transform={`rotate(45 ${at[0] + sw(9)} ${at[1]})`}
                      fill={C.bg}
                      stroke={C.cyan}
                      strokeWidth={sw(1.4)}
                    >
                      <title>{`${regionName(f.code)} · ${f.count} free servers (${f.fast} fast)`}</title>
                    </rect>
                  );
                })}

              {layers.gservers &&
                data.gservers.map((g) => {
                  const at = g.country ? centres[g.country] : null;
                  if (!at) return null;
                  const s = sw(6);
                  const c = g.online ? C.green : C.red;
                  return (
                    <g key={`g-${g.name}`}>
                      <rect
                        x={at[0] - s - sw(9)}
                        y={at[1] - s}
                        width={s * 2}
                        height={s * 2}
                        transform={`rotate(45 ${at[0] - sw(9)} ${at[1]})`}
                        fill={C.bg}
                        stroke={c}
                        strokeWidth={sw(2)}
                      />
                      <circle cx={at[0] - sw(9)} cy={at[1]} r={sw(2.2)} fill={c}>
                        <title>{`${g.name} · ${g.online ? `${g.peers} connected` : 'offline'}`}</title>
                      </circle>
                    </g>
                  );
                })}

              {layers.tests &&
                [...testsBy].map(([code, n]) => {
                  const at = centres[code];
                  if (!at) return null;
                  return (
                    <circle key={`t-${code}`} cx={at[0]} cy={at[1] + sw(10)} r={sw(2 + Math.sqrt(n) * 0.6)} fill={C.pink} fillOpacity={0.8}>
                      <title>{`${regionName(code)} · ${n} speed tests`}</title>
                    </circle>
                  );
                })}

              {layers.ratings &&
                [...ratingsBy].map(([code, n]) => {
                  const at = centres[code];
                  if (!at || !n) return null;
                  return (
                    <circle key={`r-${code}`} cx={at[0] + sw(10)} cy={at[1] + sw(10)} r={sw(2 + Math.sqrt(n) * 0.6)} fill={C.violet} fillOpacity={0.85}>
                      <title>{`${regionName(code)} · ${n} ratings`}</title>
                    </circle>
                  );
                })}

              {layers.people &&
                [...people].map(([code, n]) => {
                  const at = centres[code];
                  if (!at) return null;
                  const r = sw(2.2 + Math.sqrt(n) * 0.45);
                  return (
                    <g key={`p-${code}`}>
                      <circle className="lm-ping" cx={at[0]} cy={at[1]} r={r * 2.2} fill={C.blue} />
                      <circle cx={at[0]} cy={at[1]} r={r} fill={C.blue} stroke={C.bg} strokeWidth={sw(1)} />
                    </g>
                  );
                })}
            </g>
          </svg>

          {/* What is under the pointer */}
          {hover && (
            <HoverCard code={hover.code} x={hover.x} y={hover.y} data={data} people={people.get(hover.code) ?? 0} />
          )}

          {/* Zoom controls */}
          <div className="absolute bottom-3 right-3 flex flex-col overflow-hidden rounded-[10px] border" style={{ borderColor: C.line, background: C.panel }}>
            {(
              [
                { label: '+', title: 'Zoom in', act: () => zoomAt(W / 2, H / 2, 1.6, true) },
                { label: '−', title: 'Zoom out', act: () => zoomAt(W / 2, H / 2, 1 / 1.6, true) },
                { label: '⤢', title: 'Whole world', act: () => focusOn(null) },
              ] satisfies ReadonlyArray<{ label: string; title: string; act: () => void }>
            ).map(({ label, title, act }, i) => (
              <button
                key={title}
                type="button"
                aria-label={title}
                title={title}
                onClick={act}
                className="grid size-9 place-items-center text-[16px] font-bold hover:bg-white/5"
                style={{ color: C.text, borderTop: i === 0 ? undefined : `1px solid ${C.line}` }}
              >
                {label}
              </button>
            ))}
          </div>
          </div>

          {/* Layers */}
          <div
            className="absolute left-5 top-16 hidden w-[230px] rounded-[16px] border p-4 md:block"
            style={{ background: C.panel, borderColor: C.line }}
          >
            <Heading>LAYERS</Heading>
            {layerInfo.map((l) => (
              <label key={l.key} className="flex h-8 cursor-pointer items-center gap-2.5 text-[13px] font-semibold">
                <input
                  type="checkbox"
                  checked={layers[l.key]}
                  onChange={(e) => setLayers((s) => ({ ...s, [l.key]: e.target.checked }))}
                  className="size-4"
                  style={{ accentColor: l.color }}
                />
                <span className="flex-1">{l.label}</span>
                <span className="font-mono text-[11.5px]" style={{ color: l.color }}>
                  {counts[l.key]}
                </span>
              </label>
            ))}
          </div>

          {/* The last minutes */}
          <Timeline data={data} />
        </div>

        {/* ── side panel ── */}
        <aside className="flex flex-col gap-5 border-t p-5 lg:border-l lg:border-t-0" style={{ borderColor: C.line, background: 'rgba(14,11,22,.92)' }}>
          {focus ? <CountryPanel code={focus} data={data} /> : <WorldPanel data={data} onPick={focusOn} />}
          <Notes data={data} />
        </aside>
      </div>
    </section>
  );
}

function Heading({ children, color = C.cyan }: { children: React.ReactNode; color?: string }) {
  return (
    <div className="mb-2.5 text-[11.5px] font-extrabold tracking-[0.2em]" style={{ color }}>
      {children}
    </div>
  );
}

function Bars({ rows, color }: { rows: { label: string; value: number; note?: string; code?: string; onClick?: () => void }[]; color: string }) {
  const max = Math.max(1, ...rows.map((r) => r.value));
  if (rows.length === 0) return <p className="text-[12.5px]" style={{ color: C.muted }}>Nothing yet.</p>;
  return (
    <div className="flex flex-col gap-1">
      {rows.map((r) => {
        const inner = (
          <>
            <span className="absolute inset-y-0 left-0 rounded-[6px]" style={{ width: `${(r.value / max) * 100}%`, background: color, opacity: 0.16 }} />
            <span className="relative flex items-center gap-2 text-[13px] font-semibold">
              {r.code && (
                <span className="w-5 font-mono text-[10px]" style={{ color: C.muted }}>
                  {r.code}
                </span>
              )}
              {r.label}
            </span>
            <span className="relative font-mono text-[12px]" style={{ color }}>
              {r.note ?? r.value.toLocaleString()}
            </span>
          </>
        );
        const cls = 'relative flex h-[26px] items-center justify-between px-2 text-left';
        return r.onClick ? (
          <button key={r.label} type="button" onClick={r.onClick} className={`${cls} rounded-[6px] hover:bg-white/5`}>
            {inner}
          </button>
        ) : (
          <div key={r.label} className={cls}>
            {inner}
          </div>
        );
      })}
    </div>
  );
}

function WorldPanel({ data, onPick }: { data: LiveData; onPick: (code: string) => void }) {
  const rt = data.realtime.ok ? data.realtime.data : null;
  const connectsNow = rt ? rt.timeline.connects.reduce((a, b) => a + b, 0) : 0;
  const topProviders = [...data.providers].sort((a, b) => b.users - a.users).slice(0, 5);
  const grades = data.free.reduce((g, f) => ({ fast: g.fast + f.fast, good: g.good + f.good, slow: g.slow + f.slow }), { fast: 0, good: 0, slow: 0 });

  return (
    <>
      <div>
        <Heading>PEOPLE NOW</Heading>
        <div className="font-mono text-[46px] leading-none tracking-[-0.02em]">{rt ? rt.people.toLocaleString() : '--'}</div>
        <div className="mt-1.5 text-[12px]" style={{ color: C.muted }}>
          {rt ? `${rt.byCountry.length} countries · ${connectsNow.toLocaleString()} connects in ${rt.minutes} min` : 'Realtime not connected'}
        </div>
      </div>
      <div>
        <Heading>TOP COUNTRIES</Heading>
        <Bars
          color={C.blue}
          rows={(rt?.byCountry ?? []).slice(0, 6).map((c) => ({
            label: regionName(c.code),
            value: c.users,
            code: c.code,
            onClick: () => onPick(c.code),
          }))}
        />
      </div>
      <div>
        <Heading>TOP CITIES</Heading>
        <Bars color={C.blue} rows={(rt?.byCity ?? []).slice(0, 5).map((c) => ({ label: c.city, value: c.users, code: c.code }))} />
      </div>
      <div>
        <Heading>TOP PROVIDERS · USERS</Heading>
        <Bars color={C.violet} rows={topProviders.map((p) => ({ label: p.name, value: p.users, code: p.code }))} />
      </div>
      <div>
        <Heading>G SERVERS · LOAD</Heading>
        {data.gservers.length === 0 && (
          <p className="text-[12.5px]" style={{ color: C.muted }}>
            None configured.
          </p>
        )}
        {data.gservers.map((g) => {
          const load = g.load ?? 0;
          const c = !g.online ? C.red : load > 65 ? C.amber : C.green;
          return (
            <div key={g.name} className="mb-2 flex items-center gap-2.5">
              <span className="w-24 truncate text-[13px] font-semibold">{g.name}</span>
              <span className="h-2 flex-1 overflow-hidden rounded-full" style={{ background: '#241F33' }}>
                <span className="block h-2 rounded-full" style={{ width: `${g.online ? Math.min(100, load) : 100}%`, background: c }} />
              </span>
              <span className="w-16 text-right font-mono text-[11.5px]" style={{ color: c }}>
                {g.online ? `${g.peers} · ${g.load ?? '--'}%` : 'offline'}
              </span>
            </div>
          );
        })}
      </div>
      <div>
        <Heading>FREE SERVERS</Heading>
        <div className="flex gap-1.5">
          {[
            ['FAST', grades.fast, C.green],
            ['GOOD', grades.good, C.cyan],
            ['SLOW', grades.slow, C.amber],
            ['DOWN', data.freeDown, C.red],
          ].map(([label, value, color]) => (
            <div key={label as string} className="flex-1 rounded-[10px] p-2 text-center" style={{ background: '#1C1829' }}>
              <div className="font-mono text-[18px]" style={{ color: color as string }}>
                {value as number}
              </div>
              <div className="text-[10px] font-extrabold tracking-[0.08em]" style={{ color: C.muted }}>
                {label}
              </div>
            </div>
          ))}
        </div>
      </div>
    </>
  );
}

function CountryPanel({ code, data }: { code: string; data: LiveData }) {
  const rt = data.realtime.ok ? data.realtime.data : null;
  const now = rt?.byCountry.find((c) => c.code === code)?.users ?? 0;
  const cities = (rt?.byCity ?? []).filter((c) => c.code === code).slice(0, 6);
  const routes = (rt?.routes ?? []).filter((r) => r.from === code).sort((a, b) => b.count - a.count);
  const connects = routes.reduce((n, r) => n + r.count, 0);
  const tests = data.tests.find((t) => t.code === code);
  const speedOf = new Map((tests?.providers ?? []).map((p) => [p.isp, p.down]));
  const providers = data.providers.filter((p) => p.code === code).sort((a, b) => b.users - a.users).slice(0, 8);
  const free = data.free.find((f) => f.code === code);

  return (
    <>
      <div className="flex items-center gap-3">
        <span className="rounded-[6px] px-2 py-1 font-mono text-[12px]" style={{ background: 'rgba(45,212,191,.16)', color: C.cyan }}>
          {code}
        </span>
        <span className="text-[22px] font-extrabold">{regionName(code)}</span>
      </div>
      <div className="flex gap-1.5">
        {[
          ['NOW', now, C.blue],
          ['CONNECTS', connects, C.amber],
          ['TESTS', tests?.tests ?? 0, C.pink],
        ].map(([label, value, color]) => (
          <div key={label as string} className="flex-1 rounded-[12px] p-2.5" style={{ background: '#1C1829' }}>
            <div className="text-[10px] font-extrabold tracking-[0.08em]" style={{ color: C.muted }}>
              {label}
            </div>
            <div className="font-mono text-[20px]" style={{ color: color as string }}>
              {(value as number).toLocaleString()}
            </div>
          </div>
        ))}
      </div>
      <div>
        <Heading>PROVIDERS</Heading>
        {providers.length === 0 && (
          <p className="text-[12.5px]" style={{ color: C.muted }}>
            No providers seen here yet.
          </p>
        )}
        {providers.map((p, i) => (
          <div key={p.org} className="flex items-center gap-2.5 py-2" style={{ borderTop: i ? `1px solid ${C.line}` : undefined }}>
            <span
              className="grid size-[30px] place-items-center rounded-[9px] text-[11px] font-extrabold text-white"
              style={{ background: p.color ?? '#3A3350' }}
            >
              {initials(p.name)}
            </span>
            <div className="min-w-0 flex-1">
              <div className="truncate text-[13px] font-bold">{p.name}</div>
              <div className="text-[11px]" style={{ color: C.amber }}>
                {p.average != null ? `★ ${p.average} · ${p.ratings}` : `${p.ratings} ratings`}
              </div>
            </div>
            <div className="text-right font-mono">
              <div className="text-[12px]">{p.users} users</div>
              <div className="text-[11px]" style={{ color: C.muted }}>
                {speedOf.has(p.org) ? `${speedOf.get(p.org)} Mbps` : '--'}
              </div>
            </div>
          </div>
        ))}
      </div>
      <div>
        <Heading>SERVERS THEY PICK</Heading>
        <Bars
          color={C.amber}
          rows={routes.slice(0, 6).map((r) => ({
            label: regionName(r.to),
            value: r.count,
            code: r.to,
            note: connects ? `${Math.round((r.count / connects) * 100)}%` : undefined,
          }))}
        />
      </div>
      <div>
        <Heading>CITIES NOW</Heading>
        <Bars color={C.blue} rows={cities.map((c) => ({ label: c.city, value: c.users }))} />
      </div>
      {free && (
        <div className="text-[12.5px]" style={{ color: C.muted }}>
          {free.count} free servers here · {free.fast} fast
        </div>
      )}
    </>
  );
}

function Timeline({ data }: { data: LiveData }) {
  const rt = data.realtime.ok ? data.realtime.data : null;
  if (!rt) return null;
  const bands = [
    { name: 'PEOPLE', color: C.blue, values: rt.timeline.people },
    { name: 'CONNECTS', color: C.amber, values: rt.timeline.connects },
    { name: 'FAILED', color: C.red, values: rt.timeline.failed },
  ];
  const n = rt.minutes;
  return (
    <div className="mx-5 mb-5 mt-2 rounded-[16px] border px-4 pb-3 pt-3" style={{ background: C.panel, borderColor: C.line }}>
      <div className="mb-2 flex justify-between font-mono text-[11px]" style={{ color: C.cyan }}>
        <span>{n} min ago</span>
        <span>NOW</span>
      </div>
      {bands.map((b) => {
        const max = Math.max(1, ...b.values);
        return (
          <div key={b.name} className="mb-1 flex items-center gap-3">
            <div className="flex h-5 flex-1 items-end gap-px rounded-[4px]" style={{ background: `${b.color}10` }}>
              {b.values.map((v, i) => (
                <span
                  key={i}
                  className="flex-1 rounded-t-[2px]"
                  style={{ height: `${Math.max(v ? 12 : 0, (v / max) * 100)}%`, background: b.color, opacity: 0.85 }}
                  title={`${n - i} min ago: ${v}`}
                />
              ))}
            </div>
            <span className="w-20 text-[10.5px] font-extrabold tracking-[0.1em]" style={{ color: b.color }}>
              {b.name}
            </span>
            <span className="w-12 text-right font-mono text-[11px]">{b.values.reduce((a, c) => a + c, 0).toLocaleString()}</span>
          </div>
        );
      })}
    </div>
  );
}

/** Layers that could not be read, and why. Never a silent zero. */
function Notes({ data }: { data: LiveData }) {
  const notes = [
    !data.realtime.ok ? `Realtime: ${data.realtime.reason}` : data.realtime.data.routesNote,
    data.freeNote ? `Free servers: ${data.freeNote}` : null,
    data.testsNote ? `Speed tests: ${data.testsNote}` : null,
    data.providersNote ? `Providers: ${data.providersNote}` : null,
    data.gservers.some((g) => !g.country) ? 'Add "country" to each GVPN_GSERVERS entry to place G Servers on the map.' : null,
  ].filter(Boolean) as string[];
  if (notes.length === 0) return null;
  return (
    <div className="mt-auto flex flex-col gap-1.5">
      {notes.map((n) => (
        <p key={n} className="text-[11.5px] leading-relaxed" style={{ color: C.amber }}>
          {n}
        </p>
      ))}
    </div>
  );
}

function initials(name: string) {
  const words = name.replace(/[^A-Za-z0-9 ]/g, ' ').split(' ').filter(Boolean);
  if (words.length === 0) return '?';
  if (words.length === 1) return words[0].slice(0, 2).toUpperCase();
  return (words[0][0] + words[1][0]).toUpperCase();
}

/** The card that follows the pointer: the country and what is in it. */
function HoverCard({ code, x, y, data, people }: { code: string; x: number; y: number; data: LiveData; people: number }) {
  const free = data.free.find((f) => f.code === code);
  const gs = data.gservers.filter((g) => g.country === code);
  const tests = data.tests.find((t) => t.code === code)?.tests ?? 0;
  const providers = data.providers.filter((p) => p.code === code);
  const lines = [
    people ? [`${people.toLocaleString()} people now`, C.blue] : null,
    gs.length ? [`${gs.map((g) => g.name).join(', ')}`, C.green] : null,
    free ? [`${free.count} free servers · ${free.fast} fast`, C.cyan] : null,
    tests ? [`${tests} speed tests`, C.pink] : null,
    providers.length ? [`${providers.length} providers · ${providers.reduce((n, p) => n + p.users, 0)} users`, C.violet] : null,
  ].filter(Boolean) as [string, string][];
  return (
    <div
      className="pointer-events-none absolute z-10 min-w-[180px] rounded-[12px] border px-3 py-2.5 text-[12px] shadow-[0_10px_30px_rgba(0,0,0,.45)]"
      style={{ left: x + 14, top: y + 14, background: C.panel, borderColor: C.cyan, color: C.text }}
    >
      <div className="text-[14px] font-extrabold">{regionName(code)}</div>
      {lines.length === 0 && <div style={{ color: C.muted }}>Nothing here yet</div>}
      {lines.map(([t, c]) => (
        <div key={t} style={{ color: c }}>
          {t}
        </div>
      ))}
      <div className="mt-1 font-semibold" style={{ color: C.cyan }}>
        Click to open
      </div>
    </div>
  );
}
