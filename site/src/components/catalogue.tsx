'use client';

import { useState } from 'react';

import { isComing, playUrl, stateLabel } from '@/lib/apps';
import type { AppMeta } from '@/lib/registry';

/**
 * The catalogue: every registry app, filterable. The registry is the source of
 * truth by design, so this list grows in admin/src/lib/registry.ts (mirrored to
 * the vendored copy), never here.
 */

type Filter = 'all' | 'live' | 'coming';

function matches(app: AppMeta, f: Filter): boolean {
  if (f === 'all') return true;
  if (f === 'live') return app.state === 'live' || app.state === 'external';
  return isComing(app.state);
}

const FILTERS: { id: Filter; label: string }[] = [
  { id: 'all', label: 'All' },
  { id: 'live', label: 'Live' },
  { id: 'coming', label: 'Coming' },
];

export function Catalogue({ apps }: { apps: AppMeta[] }) {
  const [filter, setFilter] = useState<Filter>('all');

  return (
    <div>
      <div className="mb-7 flex flex-wrap gap-2.5">
        {FILTERS.map((f) => (
          <button
            key={f.id}
            onClick={() => setFilter(f.id)}
            className={`rounded-full border-[1.5px] px-4 py-2 text-[13px] font-semibold transition ${
              filter === f.id ? 'border-ink bg-ink text-white' : 'border-line bg-card text-ink-3 hover:text-ink'
            }`}
          >
            {f.label}
          </button>
        ))}
      </div>

      <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
        {apps.filter((a) => matches(a, filter)).map((a) => {
          const store = playUrl(a);
          const live = a.state === 'live' || a.state === 'external';
          return (
            <article
              key={a.id}
              className="flex items-start gap-4 rounded-[20px] border border-line bg-card p-5 shadow-soft transition hover:-translate-y-0.5 hover:shadow-lift"
            >
              <span
                aria-hidden
                className="grid size-[46px] shrink-0 place-items-center rounded-[14px] font-display text-base font-extrabold text-white [text-shadow:0_1px_4px_rgba(0,0,0,0.18)]"
                style={{ background: `linear-gradient(140deg, ${a.tint}, color-mix(in srgb, ${a.tint} 55%, #1c1526))` }}
              >
                {a.mark}
              </span>
              <div className="min-w-0">
                <div className="flex items-center gap-2">
                  <h3 className="truncate text-base font-semibold">{a.name}</h3>
                  <span
                    className={`shrink-0 rounded-full px-2 py-0.5 text-[10.5px] font-bold uppercase tracking-wide ${
                      live ? 'bg-ok-soft text-ok' : 'bg-plan-soft text-plan'
                    }`}
                  >
                    {stateLabel(a.state)}
                  </span>
                </div>
                <p className="mt-1 text-[13.5px] leading-relaxed">{a.blurb}</p>
                {store && (
                  <a href={store} className="mt-2 inline-flex items-center gap-1.5 text-[13px] font-bold text-accent transition hover:text-accent-deep">
                    Google Play
                    <svg width="13" height="13" viewBox="0 0 14 14" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" aria-hidden>
                      <path d="M3 7h8M8 3.5L11.5 7 8 10.5" />
                    </svg>
                  </a>
                )}
              </div>
            </article>
          );
        })}
      </div>
    </div>
  );
}
