'use client';

import { useEffect, useState } from 'react';
import { createPortal } from 'react-dom';
import { Flag } from '@/components/flag';
import { COPY, MAP_PROJECTION } from './copy';
import type { LiveSnapshot } from './live-types';
import { countryName, useLive } from './use-live';
import { useWhoami } from './use-whoami';
import styles from './landing.module.css';

/** Routes are drawn to this many of the most-served countries. */
const MAX_ROUTES = 8;

const { width: W, height: H } = MAP_PROJECTION;

/** Equirectangular, matching lib/g-vpn/world-map.json. */
function project(lat: number, lon: number): [number, number] {
  const { north, south } = MAP_PROJECTION;
  return [((lon + 180) / 360) * W, ((north - lat) / (north - south)) * H];
}

/** Marker size follows how many free servers a country has. */
function radius(count: number): number {
  return Math.min(6, 3 + Math.log2(count + 1) * 0.7);
}

/** One marker the visitor can point at: what its card says and where. */
interface Marker {
  key: string;
  x: number;
  y: number;
  code: string;
  title: string;
  detail: string;
  ours: boolean;
  online: boolean;
  count: number;
}

/**
 * Everything on the map that changes, refreshed with the shared live store:
 * a marker per country with free servers, our own servers by city, and the
 * visitor's spot with routes out. Hovering, focusing or tapping a marker opens
 * a small card with the country's flag.
 */
export function LiveLayer({ initial }: { initial: LiveSnapshot }) {
  const live = useLive(initial);
  const me = useWhoami();
  // The open marker and where it sits on screen. The card is portalled to
  // <body> with fixed positioning: inside the map it would sit under the
  // hero copy, which is stacked above the map.
  const [active, setActive] = useState<{ key: string; x: number; y: number } | null>(null);

  // A fixed card would drift from its marker on scroll or resize; close it.
  useEffect(() => {
    if (!active) return;
    const close = () => setActive(null);
    window.addEventListener('scroll', close, { passive: true });
    window.addEventListener('resize', close);
    return () => {
      window.removeEventListener('scroll', close);
      window.removeEventListener('resize', close);
    };
  }, [active]);
  const m = COPY.map;

  const markers: Marker[] = [
    ...live.gservers.flatMap((g): Marker[] =>
      g.x === null || g.y === null
        ? []
        : [
            {
              key: `g:${g.city}:${g.country}`,
              x: g.x,
              y: g.y,
              code: g.country,
              title: g.city,
              detail: `${m.ours} · ${g.online ? m.online : m.offline}`,
              ours: true,
              online: g.online,
              count: 0,
            },
          ],
    ),
    ...(live.free?.countries ?? []).map(
      (c): Marker => ({
        key: `f:${c.code}`,
        x: c.x,
        y: c.y,
        code: c.code,
        title: countryName(c.code),
        detail: (c.count === 1 ? m.free : m.freePlural).replace('{count}', String(c.count)),
        ours: false,
        online: true,
        count: c.count,
      }),
    ),
  ];

  const home = me && me.latitude !== null && me.longitude !== null ? project(me.latitude, me.longitude) : null;
  const open = active ? (markers.find((mk) => mk.key === active.key) ?? null) : null;

  /** Opens a marker's card above the marker's on-screen centre. */
  const show = (key: string, el: Element) => {
    const r = el.getBoundingClientRect();
    setActive({ key, x: r.left + r.width / 2, y: r.top + r.height / 2 });
  };
  const hide = (key: string) => setActive((a) => (a?.key === key ? null : a));

  return (
    <div className={styles.mapLayer}>
      <svg viewBox={`0 0 ${W} ${H}`}>
        {home &&
          markers.slice(0, MAX_ROUTES).map((mk) => (
            <path
              key={`r:${mk.key}`}
              className={styles.route}
              d={`M${home[0].toFixed(1)} ${home[1].toFixed(1)} Q${((mk.x + home[0]) / 2).toFixed(1)} ${(Math.min(mk.y, home[1]) - 80).toFixed(1)} ${mk.x} ${mk.y}`}
              aria-hidden
            />
          ))}

        {markers.map((mk) => {
          const r = mk.ours ? 5.5 : radius(mk.count);
          return (
            <g
              key={mk.key}
              role="button"
              tabIndex={0}
              aria-label={`${mk.title}, ${mk.detail}`}
              aria-expanded={active?.key === mk.key}
              className={styles.hit}
              onPointerEnter={(e) => e.pointerType === 'mouse' && show(mk.key, e.currentTarget)}
              onPointerLeave={(e) => e.pointerType === 'mouse' && hide(mk.key)}
              onFocus={(e) => show(mk.key, e.currentTarget)}
              onBlur={() => hide(mk.key)}
              onClick={(e) => (active?.key === mk.key ? hide(mk.key) : show(mk.key, e.currentTarget))}
              onKeyDown={(e) => {
                if (e.key === 'Escape') setActive(null);
              }}
            >
              {/* A generous invisible target so small dots are easy to tap. */}
              <circle className={styles.hitArea} cx={mk.x} cy={mk.y} r={16} />
              {mk.ours ? (
                <>
                  {mk.online && <circle className={styles.ourRing} cx={mk.x} cy={mk.y} r={9} />}
                  <circle className={mk.online ? styles.ours : styles.oursOff} cx={mk.x} cy={mk.y} r={r} />
                  <text className={styles.ourLabel} x={mk.x + 11} y={mk.y + 4} aria-hidden>
                    {mk.title}
                  </text>
                </>
              ) : (
                <>
                  <circle className={styles.ring} cx={mk.x} cy={mk.y} r={r + 2} />
                  <circle className={styles.node} cx={mk.x} cy={mk.y} r={r} />
                </>
              )}
            </g>
          );
        })}

        {home && (
          <g aria-hidden>
            <circle className={styles.youRing} cx={home[0]} cy={home[1]} r={7} />
            <circle className={styles.you} cx={home[0]} cy={home[1]} r={4.2} />
          </g>
        )}
      </svg>

      {open &&
        active &&
        createPortal(
          <div
            role="status"
            className="pointer-events-none fixed z-50 flex -translate-x-1/2 -translate-y-[calc(100%+16px)] items-center gap-2.5 whitespace-nowrap rounded-xl border border-gv-line bg-gv-surface px-3 py-2 text-left font-site-sans shadow-gv-card"
            style={{ left: active.x, top: active.y }}
          >
            <Flag code={open.code} width={28} />
            <span className="flex flex-col leading-tight">
              <b className="text-[13.5px] font-bold text-gv-text">{open.title}</b>
              <span className={`text-xs ${open.ours ? (open.online ? 'text-gv-good' : 'text-gv-muted') : 'text-gv-muted'}`}>
                {open.detail}
              </span>
            </span>
          </div>,
          document.body,
        )}
    </div>
  );
}
