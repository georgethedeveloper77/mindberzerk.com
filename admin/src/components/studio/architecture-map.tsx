'use client';

import Link from 'next/link';
import { useState } from 'react';

import type { GraphStatus, GraphView, IconKey, NodeState } from '@/lib/core/architecture-graph';

/**
 * The live map: nodes you can click, arrows that show data moving.
 *
 * ## The animation is a claim, so it is gated
 *
 * A dashed line travelling toward a step is saying "this works". An edge whose
 * destination cannot be reached does NOT animate, it renders as a still, dimmed
 * dash. Otherwise the map would show traffic flowing into a bucket that is
 * refusing every write, which is exactly the sort of confident wrongness the
 * rest of this panel refuses to do.
 *
 * `prefers-reduced-motion` stops the movement everywhere, and the colours still
 * carry the whole state, so nothing is lost by turning it off.
 *
 * ## Selection is client state
 *
 * The map is a reading surface rather than a place work happens, so there is
 * nothing to lose on a re-render and no reason to put a node in the URL.
 */

/**
 * One shape per kind of thing, at a single stroke weight.
 *
 * DRAWN RATHER THAN IMPORTED. A 21-icon set from a package would pull a
 * dependency into a route that already carries mermaid, and these are simple
 * enough that the paths are shorter than the import. They inherit
 * `currentColor`, so the node tints them by state without a second set.
 */
const ICONS: Record<IconKey, React.ReactNode> = {
  edit: <path d="M11.3 2.9l1.8 1.8L5.8 12H4v-1.8l7.3-7.3z" />,
  key: (
    <>
      <circle cx="5.5" cy="10.5" r="2.5" />
      <path d="M7.3 8.7L13 3M11 5l1.5 1.5M9.4 6.6L11 8.2" />
    </>
  ),
  box: (
    <>
      <path d="M8 1.8l5.5 3v6.4L8 14.2l-5.5-3V4.8l5.5-3z" />
      <path d="M2.5 4.8L8 7.8l5.5-3M8 7.8v6.4" />
    </>
  ),
  list: (
    <>
      <path d="M6 4h7M6 8h7M6 12h7" />
      <path d="M3 4h.01M3 8h.01M3 12h.01" />
    </>
  ),
  cloud: <path d="M4.6 12.5h6.6a2.9 2.9 0 00.4-5.8 4 4 0 00-7.7.9 2.5 2.5 0 00.7 4.9z" />,
  refresh: (
    <>
      <path d="M13.2 7.2A5.3 5.3 0 003.4 5.6" />
      <path d="M2.8 8.8a5.3 5.3 0 009.8 1.6" />
      <path d="M13.2 3.4v3.8h-3.8M2.8 12.6V8.8h3.8" />
    </>
  ),
  shield: (
    <>
      <path d="M8 1.8l5.2 2.2v4.6c0 3-2.1 5.4-5.2 6.2-3.1-.8-5.2-3.2-5.2-6.2V4L8 1.8z" />
      <path d="M5.8 7.9L7.4 9.5l3-3.2" />
    </>
  ),
  folder: <path d="M2.2 4.6A1.4 1.4 0 013.6 3.2h2.9l1.4 1.8h4.5a1.4 1.4 0 011.4 1.4v5.2a1.4 1.4 0 01-1.4 1.4H3.6a1.4 1.4 0 01-1.4-1.4V4.6z" />,
  layers: (
    <>
      <path d="M8 1.8l6 3-6 3-6-3 6-3z" />
      <path d="M2 8.2l6 3 6-3M2 11.4l6 3 6-3" />
    </>
  ),
  files: (
    <>
      <path d="M5.5 2.2h4l2.8 2.8v7.4a.9.9 0 01-.9.9H5.5a.9.9 0 01-.9-.9V3.1a.9.9 0 01.9-.9z" />
      <path d="M9.4 2.2V5h2.9" />
    </>
  ),
  doc: (
    <>
      <path d="M4.5 2.2h5l3 3v8a.9.9 0 01-.9.9H4.5a.9.9 0 01-.9-.9V3.1a.9.9 0 01.9-.9z" />
      <path d="M6 8.4h4M6 11h3" />
    </>
  ),
  download: (
    <>
      <path d="M8 2.4v7.2M5.2 7l2.8 2.8L10.8 7" />
      <path d="M2.8 11.4v1.2a1 1 0 001 1h8.4a1 1 0 001-1v-1.2" />
    </>
  ),
  merge: (
    <>
      <circle cx="4" cy="4" r="1.6" />
      <circle cx="4" cy="12" r="1.6" />
      <circle cx="12" cy="8" r="1.6" />
      <path d="M4 5.6v4.8M5.6 4h2.6A2.2 2.2 0 0110.4 6.6v.2" />
    </>
  ),
  sliders: (
    <>
      <path d="M2.6 5h10.8M2.6 11h10.8" />
      <circle cx="6" cy="5" r="1.6" />
      <circle cx="10.4" cy="11" r="1.6" />
    </>
  ),
  grid: (
    <>
      <rect x="2.4" y="2.4" width="4.8" height="4.8" rx="1.2" />
      <rect x="8.8" y="2.4" width="4.8" height="4.8" rx="1.2" />
      <rect x="2.4" y="8.8" width="4.8" height="4.8" rx="1.2" />
      <rect x="8.8" y="8.8" width="4.8" height="4.8" rx="1.2" />
    </>
  ),
  phone: (
    <>
      <rect x="4.4" y="1.6" width="7.2" height="12.8" rx="1.8" />
      <path d="M7.2 12.4h1.6" />
    </>
  ),
  tag: (
    <>
      <path d="M7.6 2.2H13v5.4l-6 6-5.4-5.4 6-6z" />
      <path d="M10.4 5h.01" />
    </>
  ),
  database: (
    <>
      <ellipse cx="8" cy="4" rx="5.4" ry="2.2" />
      <path d="M2.6 4v8c0 1.2 2.4 2.2 5.4 2.2s5.4-1 5.4-2.2V4" />
      <path d="M2.6 8c0 1.2 2.4 2.2 5.4 2.2s5.4-1 5.4-2.2" />
    </>
  ),
  lock: (
    <>
      <rect x="3" y="7" width="10" height="6.6" rx="1.6" />
      <path d="M5.6 7V5a2.4 2.4 0 014.8 0v2" />
    </>
  ),
  globe: (
    <>
      <circle cx="8" cy="8" r="6" />
      <path d="M2 8h12M8 2a9 9 0 010 12M8 2a9 9 0 000 12" />
    </>
  ),
  trash: (
    <>
      <path d="M2.8 4.4h10.4M6.2 4.4V3a.8.8 0 01.8-.8h2a.8.8 0 01.8.8v1.4" />
      <path d="M4.2 4.4l.6 8.2a1 1 0 001 .9h4.4a1 1 0 001-.9l.6-8.2" />
    </>
  ),
};

function Glyph({ name }: { name: IconKey }) {
  return (
    <svg
      width="15"
      height="15"
      viewBox="0 0 16 16"
      fill="none"
      stroke="currentColor"
      strokeWidth="1.5"
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden
    >
      {ICONS[name]}
    </svg>
  );
}

/** The icon tile's tint, so a broken step is coloured rather than only dotted. */
const TILE: Record<NodeState, string> = {
  ok: 'bg-site-ok-soft text-site-ok',
  bad: 'bg-site-plan-soft text-site-plan',
  unknown: 'bg-site-sunk text-site-ink-3',
};

const DOT: Record<NodeState, string> = {
  ok: 'bg-site-ok',
  bad: 'bg-site-plan',
  unknown: 'bg-site-ink-3',
};

const PILL: Record<NodeState, string> = {
  ok: 'bg-site-ok-soft text-site-ok',
  bad: 'bg-site-plan-soft text-site-plan',
  unknown: 'bg-site-sunk text-site-ink-3',
};

export function ArchitectureMap({
  views,
  status,
}: {
  views: GraphView[];
  status: GraphStatus;
}) {
  const [view, setView] = useState(views[0]?.key ?? 'delivery');
  const current = views.find((v) => v.key === view) ?? views[0];
  const graph = current.graph;

  /**
   * SELECTION IS PER VIEW, not global. Switching tabs and landing on whatever
   * node happened to be selected in the previous graph would be nonsense, so
   * the key resets to the first node of the view being entered.
   */
  const [sel, setSel] = useState(views[0]?.graph.nodes[0]?.key ?? '');
  const node = graph.nodes.find((n) => n.key === sel) ?? graph.nodes[0];
  const st = status[node?.key ?? ''] ?? { state: 'unknown' as NodeState, note: '', live: [] };

  return (
    <div className="flex flex-col gap-4">
      <div className="flex flex-wrap gap-2">
        {views.map((v) => (
          <button
            key={v.key}
            onClick={() => {
              setView(v.key);
              setSel(v.graph.nodes[0]?.key ?? '');
            }}
            className={`rounded-full border px-3.5 py-1.5 text-[12.5px] font-semibold transition ${
              v.key === view
                ? 'border-site-accent/30 bg-site-accent-soft text-site-accent-deep'
                : 'border-site-line bg-site-card text-site-ink-3 hover:text-site-ink'
            }`}
          >
            {v.label}
          </button>
        ))}
      </div>

      <div className="grid items-start gap-4 lg:grid-cols-[1fr_320px]">
      <section className="overflow-hidden rounded-[18px] border border-site-line bg-site-card shadow-site-soft">
        <header className="flex items-center gap-2.5 border-b border-site-line px-[18px] py-3.5">
          <h2 className="font-site-display text-[15px] font-bold text-site-ink">{current.label}</h2>
          <span className="text-[11.5px] text-site-ink-3">{current.blurb}</span>
        </header>

        <div className="relative h-[560px] overflow-x-auto bg-site-card">
          {/* The canvas is a fixed 780x560 space so hand-placed coordinates stay
              where they were put. It scrolls rather than scaling: a map that
              shrinks to fit is a map you cannot read on a laptop. */}
          <div className="relative h-[560px] w-[780px]">
            <span
              aria-hidden
              className="absolute inset-0 opacity-50"
              style={{
                backgroundImage:
                  'linear-gradient(var(--color-site-line) 1px, transparent 1px), linear-gradient(90deg, var(--color-site-line) 1px, transparent 1px)',
                backgroundSize: '34px 34px',
                maskImage: 'radial-gradient(600px 320px at 30% 20%, #000, transparent 80%)',
                WebkitMaskImage: 'radial-gradient(600px 320px at 30% 20%, #000, transparent 80%)',
              }}
            />

            {[
              { label: 'Panel', left: 24, top: 44, w: 212, h: 250 },
              { label: 'R2 and CDN', left: 272, top: 44, w: 212, h: 390 },
              { label: 'Device', left: 520, top: 44, w: 212, h: 470 },
            ].map((l) => (
              <div
                key={l.label}
                className="absolute rounded-2xl border border-dashed border-site-line"
                style={{ left: l.left, top: l.top, width: l.w, height: l.h }}
              >
                <span className="absolute -top-[9px] left-3.5 bg-site-card px-2 text-[9.5px] font-bold uppercase tracking-[0.09em] text-site-ink-3">
                  {l.label}
                </span>
              </div>
            ))}

            <svg className="pointer-events-none absolute inset-0 h-full w-full" viewBox="0 0 780 560">
              {graph.edges.map((e) => {
                const gate = e.gate ? (status[e.gate]?.state ?? 'unknown') : 'ok';
                const flowing = gate === 'ok';
                return (
                  <g key={`${e.from}-${e.to}`}>
                    <path d={e.d} fill="none" stroke="var(--color-site-line)" strokeWidth="1.6" />
                    <path
                      d={e.d}
                      fill="none"
                      strokeWidth="2"
                      strokeLinecap="round"
                      className={flowing ? 'arch-flow' : undefined}
                      stroke={
                        gate === 'bad'
                          ? 'var(--color-site-plan)'
                          : gate === 'unknown'
                            ? 'var(--color-site-ink-3)'
                            : 'var(--color-site-ok)'
                      }
                      strokeDasharray={flowing ? '6 10' : '3 8'}
                      opacity={flowing ? 1 : 0.55}
                    />
                  </g>
                );
              })}
            </svg>

            {graph.nodes.map((n) => {
              const s = status[n.key]?.state ?? 'unknown';
              const on = n.key === sel;
              return (
                <button
                  key={n.key}
                  onClick={() => setSel(n.key)}
                  style={{ left: n.x, top: n.y }}
                  className={`absolute w-[168px] rounded-[13px] border bg-site-card px-3 py-2.5 text-left shadow-site-soft transition hover:-translate-y-0.5 ${
                    on
                      ? 'border-site-accent shadow-[0_0_0_3px_color-mix(in_srgb,var(--color-site-accent)_22%,transparent)]'
                      : 'border-site-line hover:border-site-accent/45'
                  }`}
                >
                  <span className="flex items-center gap-2.5">
                    {/* The icon says WHAT this is, the dot says HOW IT IS. Two
                        different questions, so two marks rather than one doing
                        both badly: a coloured icon alone cannot distinguish
                        "storage, refused" from "storage, fine". */}
                    <span
                      className={`relative grid size-[26px] shrink-0 place-items-center rounded-lg ${TILE[s]}`}
                    >
                      <Glyph name={n.icon} />
                      <span
                        className={`absolute -bottom-0.5 -right-0.5 size-[7px] rounded-full ring-2 ring-site-card ${DOT[s]}`}
                      >
                        {s === 'ok' && (
                          <span className="arch-ping absolute -inset-1 rounded-full border border-site-ok opacity-55" />
                        )}
                      </span>
                    </span>
                    <span className="min-w-0">
                      <b className="block truncate text-[12.5px] font-bold tracking-tight text-site-ink">
                        {n.title}
                      </b>
                      <span className="mt-0.5 block truncate font-mono text-[10px] text-site-ink-3">
                        {n.sub}
                      </span>
                    </span>
                  </span>
                </button>
              );
            })}
          </div>
        </div>

        <div className="flex flex-wrap items-center gap-x-4 gap-y-2 border-t border-site-line px-[18px] py-3 text-[11px] text-site-ink-3">
          <span className="inline-flex items-center gap-1.5">
            <i className="size-[7px] rounded-full bg-site-ok" />
            reachable, checked on load
          </span>
          <span className="inline-flex items-center gap-1.5">
            <i className="size-[7px] rounded-full bg-site-plan" />
            refused or unsigned
          </span>
          <span className="inline-flex items-center gap-1.5">
            <i className="size-[7px] rounded-full bg-site-ink-3" />
            not measurable from here
          </span>
          <span className="ml-auto">click a node</span>
        </div>
      </section>

      {node && (
        <aside className="overflow-hidden rounded-[18px] border border-site-line bg-site-card shadow-site-soft lg:sticky lg:top-4">
          <header className="flex flex-wrap items-center gap-2.5 border-b border-site-line px-[18px] py-3.5">
            <span className={`grid size-7 shrink-0 place-items-center rounded-lg ${TILE[st.state]}`}>
              <Glyph name={node.icon} />
            </span>
            <h2 className="font-site-display text-[15px] font-bold text-site-ink">{node.title}</h2>
            <span
              className={`ml-auto rounded-full px-2.5 py-1 text-[11px] font-bold ${PILL[st.state]}`}
            >
              {st.note}
            </span>
          </header>

          <div className="px-[18px] pb-[18px] pt-3.5">
            <p className="text-[12.5px] leading-relaxed">{node.what}</p>

            <Kicker>Reads and writes</Kicker>
            {node.io.map(([k, v]) => (
              <KV key={k} k={k} v={v} />
            ))}

            {st.live.length > 0 && (
              <>
                <Kicker>Live now</Kicker>
                {st.live.map(([k, v]) => (
                  <KV key={k} k={k} v={v} />
                ))}
              </>
            )}

            {/* THE FILES. The whole reason to click a node is to get from "this
                step is wrong" to the code that implements it without a search,
                so the paths are the most useful thing in this panel. */}
            <Kicker>Source</Kicker>
            <div className="flex flex-col gap-1">
              {node.files.map((f) => (
                <code
                  key={f}
                  className="block truncate rounded-lg bg-site-sunk px-2.5 py-1.5 font-mono text-[10.5px] text-site-ink-2"
                  title={f}
                >
                  {f}
                </code>
              ))}
            </div>
            {node.inLauncher && (
              <p className="mt-1.5 text-[11px] leading-relaxed text-site-ink-3">
                These live in the launcher app, not the panel, so they are Flutter and Kotlin rather
                than TypeScript.
              </p>
            )}

            <p className="mt-3.5 rounded-r-xl border-l-2 border-site-accent bg-site-accent-soft px-3 py-2.5 text-[11.5px] leading-relaxed text-site-ink-2">
              {node.invariant}
            </p>

            {node.goto && (
              <Link
                href={node.goto.href}
                className="mt-3 inline-flex items-center gap-1.5 text-[12.5px] font-bold text-site-accent transition hover:text-site-accent-deep"
              >
                {node.goto.label}
                <svg width="13" height="13" viewBox="0 0 14 14" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" aria-hidden>
                  <path d="M3 7h8M8 3.5L11.5 7 8 10.5" />
                </svg>
              </Link>
            )}
          </div>
        </aside>
        )}
      </div>
    </div>
  );
}

function Kicker({ children }: { children: React.ReactNode }) {
  return (
    <div className="mb-2 mt-4 text-[10.5px] font-bold uppercase tracking-[0.08em] text-site-ink-3">
      {children}
    </div>
  );
}

function KV({ k, v }: { k: string; v: string }) {
  return (
    <div className="flex justify-between gap-3 border-b border-site-line py-2 text-[12px] last:border-b-0">
      <span className="shrink-0 font-medium text-site-ink-3">{k}</span>
      <span className="truncate text-right font-mono text-[11.5px] text-site-ink">{v}</span>
    </div>
  );
}
