'use client';

import { useEffect, useRef, useState } from 'react';

import { isComing, playUrl, stateLabel } from '@/lib/site-apps';
import type { AppMeta } from '@/lib/registry';

/**
 * The featured module: the piece of the hero the panel actually configures.
 *
 * The server resolves site/content.json's featured ids against the registry and
 * hands the rows in here; this component only rotates and renders. Scenes are
 * keyed by registry id with a tint-driven fallback, so an app added in the
 * panel appears with a branded generic screen the same day and earns a bespoke
 * scene later, in this file, without touching data.
 */

const ROTATE_MS = 5200;

function GLauncherScene() {
  return (
    <div
      className="absolute inset-0"
      style={{ background: 'linear-gradient(160deg, #61234c 0%, #772953 34%, #c04d33 72%, #e95420 100%)' }}
    >
      <div className="absolute inset-x-0 top-0 flex h-[18px] items-center justify-between bg-[rgba(10,8,15,0.42)] px-2.5 text-[6.5px] font-semibold text-white/90">
        <span>Activities</span>
        <span>12:04</span>
        <span>&#9679;&#9679;</span>
      </div>
      <div className="absolute left-3 top-9 text-white">
        <div className="font-site-display text-2xl font-semibold leading-none">12:04</div>
        <div className="mt-1 text-[7px] font-semibold opacity-80">Sat, Aug 1</div>
      </div>
      <div className="absolute right-1.5 top-1/2 flex -translate-y-1/2 flex-col gap-1" aria-hidden>
        <i className="h-[9px] w-[2.5px] rounded-full bg-white/95" />
        <i className="size-[2.5px] rounded-full bg-white/45" />
        <i className="size-[2.5px] rounded-full bg-white/45" />
      </div>
      <div className="absolute bottom-2 left-1/2 flex -translate-x-1/2 gap-1.5 rounded-xl border border-white/15 bg-[rgba(14,10,22,0.5)] p-1.5">
        <i className="size-5 rounded-md" style={{ background: 'linear-gradient(140deg, #ff8a5c, #e2493b)' }} />
        <i className="size-5 rounded-md" style={{ background: 'linear-gradient(140deg, #5eb0ff, #2668d8)' }} />
        <i className="size-5 rounded-md" style={{ background: 'linear-gradient(140deg, #3b3f4a, #14161c)' }} />
        <i className="size-5 rounded-md" style={{ background: 'linear-gradient(140deg, #9a6bff, #6d4ae8)' }} />
      </div>
    </div>
  );
}

function FructaScene() {
  return (
    <div className="absolute inset-0 bg-[#f6f8f6]">
      <div className="bg-[#123a2b] px-3 pb-0 pt-5 text-[#eaf5ee]">
        <span className="block text-[8px] font-semibold uppercase tracking-wider opacity-70">Portfolio</span>
        <span className="block text-[17px] font-bold tracking-tight">KSh 248,310</span>
        <svg viewBox="0 0 160 44" className="mt-1 w-full" aria-hidden>
          <path d="M0 36 C 20 34, 30 26, 48 27 S 80 18, 100 16 S 138 10, 160 6" fill="none" stroke="#57d98a" strokeWidth="2" strokeLinecap="round" />
          <path d="M0 36 C 20 34, 30 26, 48 27 S 80 18, 100 16 S 138 10, 160 6 L160 44 L0 44 Z" fill="rgba(87,217,138,0.14)" />
        </svg>
      </div>
      <div className="flex flex-col gap-1.5 p-2.5">
        {[
          ['Money Market Fund', 'Yield to date', '+13.2%'],
          ['T-Bill, 182 day', 'Matures Oct 12', '+15.9%'],
          ['T-Bill, 91 day', 'Matures Sep 3', '+15.1%'],
        ].map(([name, sub, pct]) => (
          <div key={name} className="flex items-center justify-between rounded-lg bg-white px-2 py-1.5 shadow-[0_2px_6px_rgba(18,58,43,0.06)]">
            <span>
              <b className="block text-[8.5px] font-bold text-[#1b2b23]">{name}</b>
              <small className="text-[7px] font-medium text-[#7d8a83]">{sub}</small>
            </span>
            <span className="rounded-full bg-[#e2f4ec] px-1.5 py-0.5 text-[8.5px] font-bold text-[#1c8a5a]">{pct}</span>
          </div>
        ))}
      </div>
    </div>
  );
}

function GMusicScene() {
  return (
    <div
      className="absolute inset-0 flex flex-col justify-end p-3.5 text-white"
      style={{
        background:
          'radial-gradient(140px 160px at 70% 25%, rgba(180, 64, 127, 0.55), transparent 70%), linear-gradient(170deg, #241224, #0d0a14)',
      }}
    >
      <div className="mx-auto mb-auto mt-8 grid size-24 place-items-center rounded-2xl bg-white/10">
        <svg width="34" height="34" viewBox="0 0 24 24" fill="none" stroke="#e88ab8" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round" aria-hidden>
          <path d="M9 18V6l10-2v12" />
          <circle cx="6.5" cy="18" r="2.5" />
          <circle cx="16.5" cy="16" r="2.5" />
        </svg>
      </div>
      <b className="text-[11px] font-bold">Late Night Drive</b>
      <small className="text-[8px] font-medium opacity-70">Local files, 214 tracks</small>
      <div className="mt-2 h-1 w-full overflow-hidden rounded-full bg-white/15" aria-hidden>
        <div className="h-full w-2/3 rounded-full bg-[#e88ab8]" />
      </div>
    </div>
  );
}

/** The fallback: the app's own mark and tint, so nothing renders unbranded. */
function TintScene({ app }: { app: AppMeta }) {
  return (
    <div
      className="absolute inset-0 flex flex-col items-center justify-center gap-3 p-4 text-center text-white"
      style={{ background: `linear-gradient(165deg, ${app.tint}, color-mix(in srgb, ${app.tint} 35%, #1c1526))` }}
    >
      <span className="grid size-16 place-items-center rounded-[18px] bg-white/15 font-site-display text-2xl font-bold">
        {app.mark}
      </span>
      <b className="text-[11px] font-bold leading-tight">{app.name}</b>
    </div>
  );
}

function Scene({ app }: { app: AppMeta }) {
  switch (app.id) {
    case 'g-launcher':
      return <GLauncherScene />;
    case 'fructa':
      return <FructaScene />;
    case 'g-music':
      return <GMusicScene />;
    default:
      return <TintScene app={app} />;
  }
}

export function Featured({ apps }: { apps: AppMeta[] }) {
  const [idx, setIdx] = useState(0);
  const timer = useRef<ReturnType<typeof setInterval> | null>(null);

  useEffect(() => {
    if (apps.length < 2) return;
    if (window.matchMedia('(prefers-reduced-motion: reduce)').matches) return;
    timer.current = setInterval(() => setIdx((i) => (i + 1) % apps.length), ROTATE_MS);
    return () => {
      if (timer.current) clearInterval(timer.current);
    };
    // Restarting on idx keeps a manual pick from being cut short by the old tick.
  }, [apps.length, idx]);

  if (apps.length === 0) return null;
  const app = apps[idx] ?? apps[0];
  const store = playUrl(app);

  return (
    <div>
      <div className="rounded-[30px] border border-site-line bg-site-card p-7 pb-6 shadow-site-lift">
        <div className="grid min-h-[356px] items-center gap-6 max-[620px]:justify-items-center max-[620px]:text-center min-[621px]:grid-cols-[1fr_176px]">
          <div className="flex flex-col gap-3.5 max-[620px]:items-center">
            <span className="self-start rounded-full bg-site-accent-soft px-3 py-1 text-[11.5px] font-bold uppercase tracking-wider text-site-accent-deep max-[620px]:self-center">
              {stateLabel(app.state)}
            </span>
            <h2 className="text-[27px] font-bold leading-tight tracking-tight">{app.name}</h2>
            <p className="text-[15px] leading-relaxed">{app.blurb}</p>
            <div className="mt-1 flex flex-wrap gap-2">
              {store ? (
                <a
                  href={store}
                  className="rounded-full border-[1.5px] border-site-line bg-site-card px-3.5 py-[7px] text-[12.5px] font-semibold text-site-ink transition hover:border-[#cfc7de]"
                >
                  Google Play
                </a>
              ) : isComing(app.state) ? (
                <span className="rounded-full border-[1.5px] border-dashed border-site-line px-3.5 py-[7px] text-[12.5px] font-semibold text-site-ink-3">
                  Coming soon
                </span>
              ) : null}
            </div>
          </div>
          <div className="w-[176px] rounded-[28px] bg-[#17121f] p-[7px] shadow-site-deep">
            <div className="relative h-[342px] w-full overflow-hidden rounded-[22px] bg-[#0d0a14]">
              <Scene app={app} />
            </div>
          </div>
        </div>
        <div className="mt-5 flex flex-wrap justify-center gap-2" role="tablist" aria-label="Featured apps">
          {apps.map((a, i) => (
            <button
              key={a.id}
              role="tab"
              aria-selected={i === idx}
              onClick={() => setIdx(i)}
              className={`rounded-full border-[1.5px] px-[15px] py-[7px] text-[12.5px] font-semibold transition ${
                i === idx
                  ? 'border-site-solid bg-site-solid text-site-solid-ink'
                  : 'border-site-line bg-site-page text-site-ink-3 hover:text-site-ink'
              }`}
            >
              {a.name.split(':')[0]}
            </button>
          ))}
        </div>
      </div>
      <p className="mt-3 text-center text-xs font-medium text-site-ink-3">
        Featured apps rotate here, curated from the studio panel.
      </p>
    </div>
  );
}
